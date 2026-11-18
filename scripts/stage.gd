extends Node2D
## Builds one stage in one environment, and runs everything in it except the
## math gates (main.gd handles those): hazards, enemies, trees, ore, bounce pads,
## platforms, gems, dagger pickups, slashing and thrown daggers.

signal goal_reached

const PlayerScript := preload("res://scripts/player.gd")

const FLOOR_Y := 600.0
const START_X := 150.0
const GATE_XS := [1500.0, 3500.0, 5500.0]
const GOAL_X := 6800.0
const BARRIER_OFFSET := 240.0   # wall distance from the middle door
const ZONE_REACH := 400.0       # how far before the doors the "thinking zone" starts
const DOOR_WIDTH := 96.0
const DOOR_HEIGHT := 120.0
const DOOR_SPACING := 120.0
const DOOR_COLOR := Color(0.35, 0.3, 0.6)
const BARRIER_COLOR := Color(0.55, 0.15, 0.2)

const MACH_SPEED := 480.0       # run at least this fast to plow through enemies
const MACH_BONUS := 25
const SLICE_BONUS := 10
const STOMP_BOUNCE := -520.0
const STOMP_BOUNCE_HELD := -720.0
const PAD_BOUNCE := -1050.0
const DAGGER_SPEED := 900.0
const DAGGER_RANGE := 800.0
const SLASH_REACH := 70.0
const ORE_SIZE := 64.0
const TREE_HP := 3

var game                       # main.gd
var biome: Dictionary
var player
var stations: Array = []
var ranges: Array = []         # running sections: [from_x, to_x]
var gaps: Array = []           # hazard gaps in the floor: [from_x, to_x]
var blockers: Array = []       # floor obstacles walkers turn around at: [from_x, to_x]
var solids: Array = []         # things daggers stop at: {"rect", "node"}
var gems: Array = []
var pickups: Array = []
var pads: Array = []
var trees: Array = []
var ores: Array = []
var enemies: Array = []
var flying_daggers: Array = []
var last_safe := Vector2(START_X, FLOOR_Y - 24)
var prev_feet_y := FLOOR_Y
var stomp_chain := 0
var t := 0.0
var msg_cooldown := 0.0
var goal_sent := false


func setup(game_ref, biome_data: Dictionary) -> void:
	game = game_ref
	biome = biome_data


func _ready() -> void:
	RenderingServer.set_default_clear_color(biome["sky"])
	_compute_ranges()
	_build_backdrop()
	_layout_features()
	_build_floor()
	_build_stations()
	_build_goal()
	_spawn_enemies()
	_spawn_player()
	_build_atmosphere()


# =============================================================== layout

func _compute_ranges() -> void:
	ranges = [[420.0, GATE_XS[0] - ZONE_REACH - 100.0]]
	for i in GATE_XS.size():
		var a: float = GATE_XS[i] + BARRIER_OFFSET + 200.0
		var b: float = GOAL_X - 250.0
		if i + 1 < GATE_XS.size():
			b = GATE_XS[i + 1] - ZONE_REACH - 100.0
		ranges.append([a, b])


func _pick_weighted(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var roll := randf() * total
	for k in weights:
		roll -= float(weights[k])
		if roll <= 0.0:
			return k
	return "hurdle"


func _layout_features() -> void:
	var weights: Dictionary = biome["features"]
	for r in ranges:
		var x: float = r[0] + 40.0
		var end_x: float = r[1]
		while x < end_x - 100.0:
			var f := _pick_weighted(weights)
			if f == "hazard" and biome["hazard"] != "":
				var gw := randf_range(biome["hazard_gap"][0], biome["hazard_gap"][1])
				if x + gw < end_x - 60.0:
					gaps.append([x, x + gw])
					blockers.append([x - 10.0, x + gw + 10.0])
					_add_gem(Vector2(x + gw / 2.0, FLOOR_Y - 120.0))
					x += gw
			elif f == "hurdle":
				x += _add_hurdle(x)
			elif f == "ore" and not biome["ores"].is_empty():
				_add_ore(x, biome["ores"].pick_random())
				x += ORE_SIZE
			elif f == "tree" and biome["tree"] != "":
				_add_tree(x + 30.0)
				x += 60.0
			elif f == "pad" and biome["pad"] != "":
				_add_pad(x + 40.0)
				x += 80.0
			elif f == "platform":
				_add_platform(x)
				x += 100.0
			elif f == "daggers":
				_add_pickup(Vector2(x + 20.0, FLOOR_Y - 40.0))
				x += 60.0
			x += randf_range(90.0, 170.0)


func _free_intervals(a: float, b: float) -> Array:
	var bl := blockers.filter(func(k): return k[1] > a and k[0] < b)
	bl.sort_custom(func(p, q): return p[0] < q[0])
	var out: Array = []
	var cur := a
	for k in bl:
		if k[0] > cur:
			out.append([cur, float(k[0])])
		cur = maxf(cur, float(k[1]))
	if cur < b:
		out.append([cur, b])
	return out


func _over_gap(x: float, margin: float) -> bool:
	for g in gaps:
		if x > g[0] - margin and x < g[1] + margin:
			return true
	return false


# =============================================================== building

## A solid block with a custom look. draw_fn(node, size) draws it from the top-left.
func _add_static(rect: Rect2, draw_fn: Callable, one_way := false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2.0
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.one_way_collision = one_way
	body.add_child(col)
	var vis := Node2D.new()
	vis.position = -rect.size / 2.0
	vis.draw.connect(func(): draw_fn.call(vis, rect.size))
	body.add_child(vis)
	add_child(body)
	return body


## A node that draws itself with draw_fn(node). Not solid.
func _add_drawing(pos: Vector2, draw_fn: Callable, z := 0) -> Node2D:
	var n := Node2D.new()
	n.position = pos
	n.z_index = z
	n.draw.connect(func(): draw_fn.call(n))
	add_child(n)
	return n


func _build_floor() -> void:
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(a, b): return a[0] < b[0])
	var segs: Array = []
	var cur := -200.0
	for g in sorted:
		segs.append([cur, float(g[0])])
		cur = float(g[1])
	segs.append([cur, GOAL_X + 800.0])
	var ground: Color = biome["ground"]
	var top: Color = biome["top"]
	for s in segs:
		var w: float = s[1] - s[0]
		if w <= 1.0:
			continue
		_add_static(Rect2(s[0], FLOOR_Y, w, 400.0), _draw_ground.bind(ground, top))
	for g in gaps:
		_build_hazard(float(g[0]), float(g[1]))
	var wall := Color(0.25, 0.25, 0.3)
	_add_static(Rect2(-100, FLOOR_Y - 900, 100, 900), func(n, sz): n.draw_rect(Rect2(Vector2.ZERO, sz), wall))
	_add_static(Rect2(GOAL_X + 300, FLOOR_Y - 900, 100, 900), func(n, sz): n.draw_rect(Rect2(Vector2.ZERO, sz), wall))


func _draw_ground(n: Node2D, sz: Vector2, ground: Color, top: Color) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, sz), ground)
	n.draw_rect(Rect2(0, 0, sz.x, 16), top)


func _build_hazard(a: float, b: float) -> void:
	_add_drawing(Vector2(a, FLOOR_Y), _draw_hazard.bind(b - a, biome["hazard_color"], biome["hazard"]))


func _draw_hazard(n: Node2D, w: float, c: Color, kind: String) -> void:
	if kind == "liquid":
		n.draw_rect(Rect2(0, 18, w, 400), c)
		n.draw_rect(Rect2(0, 18, w, 6), c.lightened(0.3))
	else:
		n.draw_rect(Rect2(0, 0, w, 400), c)
	if kind == "spikes":
		var sx := 0.0
		while sx < w - 4.0:
			n.draw_colored_polygon(PackedVector2Array([Vector2(sx, 60), Vector2(sx + 10, 22), Vector2(sx + 20, 60)]), Color(0.75, 0.75, 0.8))
			sx += 20.0


## Returns how much floor it used.
func _add_hurdle(x: float) -> float:
	var style: String = biome["block_style"]
	var c: Color = biome["block"]
	var w := 60.0
	var h := randf_range(40.0, 90.0)
	if style == "bus":
		w = 170.0
		h = 80.0
	var rect := Rect2(x, FLOOR_Y - h, w, h)
	var body := _add_static(rect, _draw_block.bind(style, c))
	blockers.append([x - 5.0, x + w + 5.0])
	solids.append({"rect": rect, "node": body})
	_add_gem(Vector2(x + w / 2.0, FLOOR_Y - h - 50.0))
	return w


func _draw_block(n: Node2D, sz: Vector2, style: String, c: Color) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, sz), c)
	if style == "crate":
		n.draw_rect(Rect2(Vector2.ZERO, sz), c.darkened(0.35), false, 3.0)
		n.draw_line(Vector2.ZERO, sz, c.darkened(0.35), 3.0)
		n.draw_line(Vector2(sz.x, 0), Vector2(0, sz.y), c.darkened(0.35), 3.0)
	elif style == "bus":
		for wx in range(10, int(sz.x) - 20, 30):
			n.draw_rect(Rect2(wx, 10, 22, 22), Color(0.7, 0.85, 0.95))
		n.draw_circle(Vector2(30, sz.y), 12, Color(0.1, 0.1, 0.1))
		n.draw_circle(Vector2(sz.x - 30, sz.y), 12, Color(0.1, 0.1, 0.1))
	elif style == "snow":
		n.draw_rect(Rect2(0, 0, sz.x, 10), Color.WHITE)
	else:
		n.draw_rect(Rect2(6, 6, sz.x * 0.4, sz.y * 0.3), c.lightened(0.15))


func _add_ore(x: float, type: String) -> void:
	var rect := Rect2(x, FLOOR_Y - ORE_SIZE, ORE_SIZE, ORE_SIZE)
	var speck := Color(0.3, 0.3, 0.32)
	if type == "iron":
		speck = Color(0.85, 0.65, 0.45)
	elif type == "diamond":
		speck = Color(0.3, 0.95, 1.0)
	var spots: Array = []
	for i in 6:
		spots.append(Vector2(randf_range(8, 48), randf_range(8, 48)))
	var body := _add_static(rect, _draw_ore.bind(spots, speck))
	blockers.append([x - 5.0, x + ORE_SIZE + 5.0])
	var ore := {"rect": rect, "node": body, "type": type, "alive": true}
	ores.append(ore)
	solids.append(ore)


func _draw_ore(n: Node2D, sz: Vector2, spots: Array, speck: Color) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.5, 0.5, 0.52))
	n.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.35, 0.35, 0.37), false, 3.0)
	for s in spots:
		n.draw_rect(Rect2(s, Vector2(9, 9)), speck)


func _add_tree(x: float) -> void:
	var style: String = biome["tree"]
	var snowy: bool = biome["tree_snow"]
	if biome["id"] == "forest" and randf() < 0.4:
		style = "pine"
	var h := randf_range(110.0, 170.0)
	var node := _add_drawing(Vector2(x, FLOOR_Y), _draw_tree.bind(style, h, snowy), -1)
	trees.append({"node": node, "x": x, "hp": TREE_HP, "alive": true})


func _draw_tree(n: Node2D, style: String, h: float, snowy: bool) -> void:
	var bark := Color(0.45, 0.3, 0.15)
	var leaf := Color(0.2, 0.6, 0.25)
	match style:
		"oak":
			n.draw_rect(Rect2(-9, -h, 18, h), bark)
			n.draw_circle(Vector2(0, -h), 46, leaf)
			n.draw_circle(Vector2(-30, -h + 18), 30, leaf.darkened(0.1))
			n.draw_circle(Vector2(30, -h + 18), 30, leaf.darkened(0.1))
		"pine":
			n.draw_rect(Rect2(-7, -40, 14, 40), bark)
			for i in 3:
				var y := -30.0 - i * 40.0
				var wdt := 60.0 - i * 14.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(-wdt, y), Vector2(0, y - 70), Vector2(wdt, y)]), Color(0.1, 0.45, 0.25))
				if snowy:
					n.draw_colored_polygon(PackedVector2Array([Vector2(-wdt * 0.35, y - 46), Vector2(0, y - 70), Vector2(wdt * 0.35, y - 46)]), Color.WHITE)
		"palm":
			n.draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(14, -h), Vector2(2, -h)]), Color(0.6, 0.45, 0.25))
			for a in [-2.6, -2.0, -1.2, -0.5]:
				var tip := Vector2(cos(a), sin(a) * 0.6) * 70.0 + Vector2(8, -h)
				n.draw_colored_polygon(PackedVector2Array([Vector2(8, -h - 6), tip, Vector2(8, -h + 6)]), Color(0.2, 0.65, 0.2))
				var tip2 := Vector2(-cos(a), sin(a) * 0.6) * 70.0 + Vector2(8, -h)
				n.draw_colored_polygon(PackedVector2Array([Vector2(8, -h - 6), tip2, Vector2(8, -h + 6)]), Color(0.2, 0.65, 0.2))
			n.draw_circle(Vector2(4, -h + 8), 7, Color(0.45, 0.3, 0.1))
		"cactus":
			var g := Color(0.25, 0.6, 0.3)
			n.draw_rect(Rect2(-12, -h * 0.8, 24, h * 0.8), g)
			n.draw_rect(Rect2(-34, -h * 0.55, 22, 12), g)
			n.draw_rect(Rect2(-34, -h * 0.75, 12, 30), g)
			n.draw_rect(Rect2(12, -h * 0.45, 22, 12), g)
			n.draw_rect(Rect2(22, -h * 0.62, 12, 28), g)
		"jungle":
			n.draw_rect(Rect2(-11, -h - 30, 22, h + 30), Color(0.35, 0.25, 0.12))
			n.draw_circle(Vector2(0, -h - 40), 55, Color(0.1, 0.4, 0.15))
			n.draw_circle(Vector2(-40, -h - 10), 35, Color(0.12, 0.5, 0.18))
			n.draw_circle(Vector2(40, -h - 10), 35, Color(0.12, 0.5, 0.18))
			n.draw_line(Vector2(-30, -h), Vector2(-34, -h + 90), Color(0.2, 0.5, 0.15), 3.0)
		"dead":
			var d := Color(0.12, 0.08, 0.08)
			n.draw_rect(Rect2(-7, -h, 14, h), d)
			n.draw_line(Vector2(0, -h * 0.6), Vector2(-35, -h * 0.85), d, 6.0)
			n.draw_line(Vector2(0, -h * 0.75), Vector2(30, -h), d, 6.0)
		"flower":
			n.draw_rect(Rect2(-6, -h - 40, 12, h + 40), Color(0.25, 0.6, 0.2))
			for i in 6:
				var a := i * TAU / 6.0
				n.draw_circle(Vector2(cos(a), sin(a)) * 26.0 + Vector2(0, -h - 40), 18, Color(0.95, 0.45, 0.7))
			n.draw_circle(Vector2(0, -h - 40), 16, Color(1.0, 0.85, 0.2))
		"mushroom":
			n.draw_rect(Rect2(-10, -h * 0.6, 20, h * 0.6), Color(0.85, 0.85, 0.75))
			_semi(n, Vector2(0, -h * 0.6), 40.0, Color(0.3, 0.8, 0.8))


func _add_pad(x: float) -> void:
	var style: String = biome["pad"]
	var top_h := 40.0
	if style == "flower":
		top_h = 60.0
	var rect := Rect2(x - 35.0, FLOOR_Y - top_h, 70.0, top_h)
	var node := _add_drawing(Vector2(x, FLOOR_Y), _draw_pad.bind(style))
	pads.append({"rect": rect, "node": node})
	_add_gem(Vector2(x, FLOOR_Y - 330.0))


func _draw_pad(n: Node2D, style: String) -> void:
	match style:
		"mushroom":
			n.draw_rect(Rect2(-10, -24, 20, 24), Color(0.95, 0.9, 0.8))
			_semi(n, Vector2(0, -24), 34.0, Color(0.9, 0.15, 0.15))
			n.draw_circle(Vector2(-12, -40), 5, Color.WHITE)
			n.draw_circle(Vector2(12, -36), 5, Color.WHITE)
		"hay":
			n.draw_rect(Rect2(-35, -40, 70, 40), Color(0.95, 0.8, 0.3))
			for yy in [-30, -18, -6]:
				n.draw_line(Vector2(-35, yy), Vector2(35, yy), Color(0.8, 0.6, 0.2), 2.0)
		"ball":
			n.draw_circle(Vector2(0, -20), 20, Color.WHITE)
			n.draw_rect(Rect2(-20, -26, 40, 12), Color(0.95, 0.3, 0.3))
			n.draw_rect(Rect2(-6, -40, 12, 40), Color(0.2, 0.5, 0.95))
		_:
			n.draw_rect(Rect2(-5, -60, 10, 60), Color(0.25, 0.6, 0.2))
			n.draw_colored_polygon(PackedVector2Array([Vector2(-40, -60), Vector2(0, -75), Vector2(40, -60), Vector2(0, -52)]), Color(0.95, 0.5, 0.8))
			n.draw_circle(Vector2(0, -62), 8, Color(1, 0.85, 0.2))


## Top half of a circle (mushroom caps).
func _semi(n: Node2D, center: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	n.draw_colored_polygon(pts, c)


func _add_platform(x: float) -> void:
	var w := randf_range(160.0, 220.0)
	var h := randf_range(150.0, 190.0)
	var c: Color = biome["platform"]
	_add_static(Rect2(x, FLOOR_Y - h, w, 20.0), _draw_platform.bind(c), true)
	for i in 3:
		_add_gem(Vector2(x + w * (i + 1) / 4.0, FLOOR_Y - h - 30.0))


func _draw_platform(n: Node2D, sz: Vector2, c: Color) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, sz), c)
	n.draw_rect(Rect2(0, sz.y - 5, sz.x, 5), c.darkened(0.3))


func _add_gem(pos: Vector2) -> void:
	var gem := ColorRect.new()
	gem.size = Vector2(18, 18)
	gem.pivot_offset = Vector2(9, 9)
	gem.position = pos - Vector2(9, 9)
	gem.rotation = PI / 4
	gem.color = Color(1, 0.9, 0.2)
	add_child(gem)
	gems.append({"node": gem, "pos": pos, "taken": false})


func _add_pickup(pos: Vector2) -> void:
	var node := _add_drawing(pos, _draw_pickup)
	pickups.append({"node": node, "pos": pos, "taken": false})


func _draw_pickup(n: Node2D) -> void:
	n.draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.35))
	_draw_dagger(n)


func _build_stations() -> void:
	for x in GATE_XS:
		var doors: Array = []
		var labels: Array = []
		for i in 3:
			var dx: float = x + (i - 1) * DOOR_SPACING
			var door := ColorRect.new()
			door.position = Vector2(dx - DOOR_WIDTH / 2.0, FLOOR_Y - DOOR_HEIGHT)
			door.size = Vector2(DOOR_WIDTH, DOOR_HEIGHT)
			door.color = DOOR_COLOR
			add_child(door)
			var lbl := Label.new()
			lbl.size = Vector2(DOOR_WIDTH, 56)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			game.style_label(lbl, 26)
			door.add_child(lbl)
			doors.append(door)
			labels.append(lbl)
		var sign := Label.new()
		sign.position = Vector2(x - 200.0, FLOOR_Y - DOOR_HEIGHT - 80.0)
		sign.size = Vector2(400, 50)
		sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game.style_label(sign, 36)
		add_child(sign)
		stations.append({"x": x, "problem": null, "resolved": false, "doors": doors, "labels": labels,
			"locked": [false, false, false], "misses": 0, "sign": sign, "arrived": -1.0,
			"barrier": make_barrier(x + BARRIER_OFFSET)})


func make_barrier(x: float) -> StaticBody2D:
	var rect := Rect2(x - 15.0, FLOOR_Y - 420.0, 30.0, 420.0)
	var body := _add_static(rect, _draw_barrier)
	solids.append({"rect": rect, "node": body})
	return body


func _draw_barrier(n: Node2D, sz: Vector2) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, sz), BARRIER_COLOR)
	for yy in range(0, int(sz.y), 40):
		n.draw_line(Vector2(0, yy), Vector2(sz.x, yy + 20), BARRIER_COLOR.lightened(0.2), 3.0)


func _build_goal() -> void:
	_add_drawing(Vector2(GOAL_X, FLOOR_Y), _draw_goal)
	var lbl := Label.new()
	lbl.text = "GOAL"
	lbl.position = Vector2(GOAL_X - 194.0, FLOOR_Y - 360.0)
	lbl.size = Vector2(400, 50)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.style_label(lbl, 40)
	add_child(lbl)
	var s := Label.new()
	s.text = "START"
	s.position = Vector2(START_X - 200.0, FLOOR_Y - 200.0)
	s.size = Vector2(400, 50)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.style_label(s, 32)
	add_child(s)


func _draw_goal(n: Node2D) -> void:
	n.draw_rect(Rect2(0, -300, 12, 300), Color.WHITE)
	n.draw_rect(Rect2(12, -300, 90, 60), Color(1, 0.85, 0.1))


# =============================================================== backdrop & mood

func _build_backdrop() -> void:
	var kind: String = biome["backdrop"]
	var c: Color = biome["backdrop_color"]
	var end_x := GOAL_X + 800.0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seeds: Array = []
	for i in 400:
		seeds.append(Vector2(rng.randf(), rng.randf()))
	_add_drawing(Vector2.ZERO, _draw_backdrop.bind(kind, c, end_x, seeds), -10)


func _draw_backdrop(n: Node2D, kind: String, c: Color, end_x: float, seeds: Array) -> void:
	var x := -400.0
	var i := 0
	match kind:
		"hills":
			while x < end_x:
				n.draw_circle(Vector2(x, FLOOR_Y + 40), 160 + seeds[i % 400].x * 120, c)
				x += 260.0 + seeds[i % 400].y * 120.0
				i += 1
		"dunes":
			while x < end_x:
				var w: float = 300.0 + seeds[i % 400].x * 300.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x + w / 2, FLOOR_Y - 90 - seeds[i % 400].y * 80), Vector2(x + w, FLOOR_Y)]), c)
				x += w * 0.7
				i += 1
		"spikes":
			while x < end_x:
				var hh: float = 150.0 + seeds[i % 400].x * 250.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x + 40, FLOOR_Y - hh), Vector2(x + 80, FLOOR_Y)]), c)
				x += 60.0 + seeds[i % 400].y * 80.0
				i += 1
		"stars":
			for s in seeds:
				n.draw_rect(Rect2(-400 + s.x * (end_x + 400), 20 + s.y * 480, 3, 3), Color(1, 1, 1, 0.8))
			for ex in range(400, int(end_x), 2400):
				n.draw_circle(Vector2(ex, 160), 60, c)
				n.draw_circle(Vector2(ex - 15, 145), 22, Color(0.3, 0.7, 0.3))
				n.draw_circle(Vector2(ex + 20, 175), 16, Color(0.3, 0.7, 0.3))
		"mountains":
			while x < end_x:
				var w: float = 400.0 + seeds[i % 400].x * 300.0
				var hh: float = 250.0 + seeds[i % 400].y * 200.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x + w / 2, FLOOR_Y - hh), Vector2(x + w, FLOOR_Y)]), c)
				n.draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.38, FLOOR_Y - hh * 0.76), Vector2(x + w / 2, FLOOR_Y - hh), Vector2(x + w * 0.62, FLOOR_Y - hh * 0.76)]), Color.WHITE)
				x += w * 0.6
				i += 1
		"houses":
			while x < end_x:
				var w: float = 140.0 + seeds[i % 400].x * 60.0
				var hh: float = 100.0 + seeds[i % 400].y * 50.0
				n.draw_rect(Rect2(x, FLOOR_Y - hh, w, hh), c)
				n.draw_colored_polygon(PackedVector2Array([Vector2(x - 10, FLOOR_Y - hh), Vector2(x + w / 2, FLOOR_Y - hh - 60), Vector2(x + w + 10, FLOOR_Y - hh)]), Color(0.55, 0.25, 0.2))
				n.draw_rect(Rect2(x + 20, FLOOR_Y - hh + 25, 26, 26), Color(1, 0.9, 0.6))
				n.draw_rect(Rect2(x + w - 50, FLOOR_Y - 50, 30, 50), Color(0.4, 0.25, 0.15))
				x += w + 120.0 + seeds[i % 400].x * 200.0
				i += 1
		"city":
			while x < end_x:
				var w: float = 100.0 + seeds[i % 400].x * 80.0
				var hh: float = 180.0 + seeds[i % 400].y * 220.0
				n.draw_rect(Rect2(x, FLOOR_Y - hh, w, hh), c)
				for wy in range(int(FLOOR_Y - hh + 15), int(FLOOR_Y - 20), 35):
					for wx in range(int(x + 12), int(x + w - 16), 28):
						n.draw_rect(Rect2(wx, wy, 14, 18), Color(0.9, 0.85, 0.5, 0.6))
				x += w + 20.0
				i += 1
			for tx in range(900, int(end_x), 2200):
				n.draw_rect(Rect2(tx, FLOOR_Y - 480, 70, 480), c.darkened(0.25))
				n.draw_circle(Vector2(tx + 35, FLOOR_Y - 420), 26, Color(0.95, 0.92, 0.8))
				n.draw_line(Vector2(tx + 35, FLOOR_Y - 420), Vector2(tx + 35, FLOOR_Y - 440), Color.BLACK, 3.0)
				n.draw_line(Vector2(tx + 35, FLOOR_Y - 420), Vector2(tx + 50, FLOOR_Y - 420), Color.BLACK, 3.0)
				n.draw_colored_polygon(PackedVector2Array([Vector2(tx, FLOOR_Y - 480), Vector2(tx + 35, FLOOR_Y - 560), Vector2(tx + 70, FLOOR_Y - 480)]), c.darkened(0.35))
		"grass":
			while x < end_x:
				var hh: float = 250.0 + seeds[i % 400].x * 300.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, FLOOR_Y), Vector2(x + 12 + seeds[i % 400].y * 30, FLOOR_Y - hh), Vector2(x + 24, FLOOR_Y)]), c)
				x += 30.0 + seeds[i % 400].y * 40.0
				i += 1
		"cave":
			n.draw_rect(Rect2(-400, -400, end_x + 400, 300), c)
			while x < end_x:
				var hh: float = 60.0 + seeds[i % 400].x * 140.0
				n.draw_colored_polygon(PackedVector2Array([Vector2(x, -100), Vector2(x + 25, -100 + hh), Vector2(x + 50, -100)]), c)
				x += 50.0 + seeds[i % 400].y * 90.0
				i += 1
		"bricks":
			for row in range(0, 16):
				var y := FLOOR_Y - 40.0 * (row + 1)
				n.draw_line(Vector2(-400, y), Vector2(end_x, y), c.darkened(0.3), 2.0)
				var bx := -400.0 + (40.0 if row % 2 == 0 else 0.0)
				while bx < end_x:
					n.draw_line(Vector2(bx, y), Vector2(bx, y + 40), c.darkened(0.3), 2.0)
					bx += 80.0
			for tx in range(300, int(end_x), 700):
				n.draw_rect(Rect2(tx, FLOOR_Y - 260, 8, 30), Color(0.4, 0.25, 0.1))
				n.draw_circle(Vector2(tx + 4, FLOOR_Y - 268), 9, Color(1, 0.6, 0.1))
		"jungle":
			while x < end_x:
				n.draw_circle(Vector2(x, FLOOR_Y - 200 - seeds[i % 400].y * 200), 90 + seeds[i % 400].x * 60, c)
				x += 140.0 + seeds[i % 400].y * 100.0
				i += 1
		"sea":
			n.draw_rect(Rect2(-400, FLOOR_Y - 130, end_x + 400, 130), c)
			while x < end_x:
				n.draw_line(Vector2(x, FLOOR_Y - 100 + seeds[i % 400].y * 70), Vector2(x + 40, FLOOR_Y - 100 + seeds[i % 400].y * 70), Color(1, 1, 1, 0.6), 2.0)
				x += 90.0
				i += 1
		"trunk":
			for tx in range(-200, int(end_x), 1600):
				n.draw_rect(Rect2(tx, -600, 380, FLOOR_Y + 600), c)
				for ly in range(-560, int(FLOOR_Y), 70):
					n.draw_line(Vector2(tx + 40 + (ly % 140) * 0.3, ly), Vector2(tx + 60 + (ly % 140) * 0.3, ly + 50), c.darkened(0.3), 4.0)


func _build_atmosphere() -> void:
	var kind: String = biome["particles"]
	if kind != "":
		var p := CPUParticles2D.new()
		p.local_coords = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(900, 10)
		p.position = Vector2(0, -450)
		p.gravity = Vector2.ZERO
		match kind:
			"rain":
				p.amount = 220
				p.lifetime = 1.0
				p.direction = Vector2(0.15, 1)
				p.spread = 2.0
				p.initial_velocity_min = 700.0
				p.initial_velocity_max = 800.0
				p.scale_amount_min = 2.0
				p.scale_amount_max = 2.5
				p.color = Color(0.75, 0.85, 1.0, 0.7)
			"snow":
				p.amount = 140
				p.lifetime = 6.0
				p.direction = Vector2(0.1, 1)
				p.spread = 20.0
				p.initial_velocity_min = 60.0
				p.initial_velocity_max = 120.0
				p.scale_amount_min = 3.0
				p.scale_amount_max = 5.0
				p.color = Color(1, 1, 1, 0.9)
			"leaves":
				p.amount = 40
				p.lifetime = 7.0
				p.direction = Vector2(-0.3, 1)
				p.spread = 30.0
				p.initial_velocity_min = 40.0
				p.initial_velocity_max = 90.0
				p.scale_amount_min = 5.0
				p.scale_amount_max = 7.0
				p.color = Color(0.4, 0.75, 0.3)
			"embers":
				p.position = Vector2(0, 250)
				p.amount = 60
				p.lifetime = 4.0
				p.direction = Vector2(0, -1)
				p.spread = 25.0
				p.initial_velocity_min = 50.0
				p.initial_velocity_max = 130.0
				p.scale_amount_min = 3.0
				p.scale_amount_max = 4.0
				p.color = Color(1.0, 0.55, 0.1)
		player.add_child(p)

	var dark: float = biome["dark"]
	if dark > 0.0:
		var cm := CanvasModulate.new()
		cm.color = Color(dark, dark, dark * 1.1)
		add_child(cm)
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 512
		tex.height = 512
		var light := PointLight2D.new()
		light.texture = tex
		light.texture_scale = 2.2
		light.energy = 1.1
		player.add_child(light)


# =============================================================== enemies

func _spawn_enemies() -> void:
	var defs: Array = biome["enemies"]
	for r in ranges:
		var spots := _free_intervals(float(r[0]), float(r[1])).filter(func(k): return k[1] - k[0] >= 170.0)
		spots.shuffle()
		for i in mini(2, spots.size()):
			_add_enemy(defs.pick_random(), float(spots[i][0]) + 20.0, float(spots[i][1]) - 20.0)


func _add_enemy(def: Dictionary, min_x: float, max_x: float) -> void:
	var e := {"def": def, "min_x": min_x, "max_x": max_x, "x": 0.0, "y": FLOOR_Y, "dir": 1.0,
		"speed": float(def["speed"]), "alive": true, "vy": 0.0, "hop_t": 1.0,
		"air": randf_range(70.0, 110.0), "phase": randf() * TAU, "node": null}
	var node := _add_drawing(Vector2.ZERO, _draw_enemy.bind(e))
	e["node"] = node
	_reset_enemy(e)
	enemies.append(e)


func _reset_enemy(e: Dictionary) -> void:
	e["x"] = randf_range(e["min_x"], e["max_x"])
	e["y"] = FLOOR_Y
	e["vy"] = 0.0
	e["dir"] = 1.0 if randf() < 0.5 else -1.0
	e["alive"] = true
	var node: Node2D = e["node"]
	node.scale = Vector2(e["dir"], 1.0)
	node.modulate = Color.WHITE
	node.visible = true
	_place_enemy(e)


func reset_enemies() -> void:
	for e in enemies:
		_reset_enemy(e)


func _place_enemy(e: Dictionary) -> void:
	var node: Node2D = e["node"]
	node.position = Vector2(e["x"], e["y"])
	node.scale.x = e["dir"]


## Drawn facing right. The node is flipped to face left.
func _draw_enemy(n: Node2D, e: Dictionary) -> void:
	var def: Dictionary = e["def"]
	var s: Vector2 = def["size"]
	var c: Color = def["color"]
	var kind: String = def["kind"]
	var flap := sin(t * 14.0 + float(e["phase"])) * 0.5 + 0.5
	var wy := -s.y * 0.7
	var wc := c.darkened(0.3)
	if kind == "flyer" or kind == "dragon":
		n.draw_colored_polygon(PackedVector2Array([Vector2(-6, wy), Vector2(-s.x * 0.2, wy - 10 - 16 * flap), Vector2(-s.x * 0.75, wy - 4 - 10 * flap), Vector2(-s.x * 0.3, wy + 6)]), wc)
	if kind == "dragon":
		n.draw_colored_polygon(PackedVector2Array([Vector2(-s.x / 2, -s.y * 0.5), Vector2(-s.x / 2 - 22, -s.y * 0.15 + sin(t * 6.0) * 4), Vector2(-s.x / 2, -s.y * 0.2)]), c.darkened(0.15))
	if kind == "crab":
		var lift := sin(t * 10.0 + float(e["phase"])) * 3.0
		n.draw_rect(Rect2(-s.x / 2 - 10, -s.y - 6 + lift, 12, 10), c.darkened(0.1))
		n.draw_rect(Rect2(s.x / 2 - 2, -s.y - 6 - lift, 12, 10), c.darkened(0.1))
	n.draw_rect(Rect2(-s.x / 2, -s.y, s.x, s.y), c)
	if kind == "dragon":
		n.draw_rect(Rect2(s.x / 2 - 4, -s.y - 8, 16, 16), c)
		n.draw_colored_polygon(PackedVector2Array([Vector2(s.x / 2, -s.y - 8), Vector2(s.x / 2 + 3, -s.y - 18), Vector2(s.x / 2 + 6, -s.y - 8)]), Color(1, 0.95, 0.8))
		n.draw_rect(Rect2(-s.x / 2 + 6, -s.y * 0.45, s.x - 12, s.y * 0.35), c.lightened(0.35))
		n.draw_rect(Rect2(s.x / 2 + 2, -s.y - 4, 6, 6), Color.WHITE)
		n.draw_rect(Rect2(s.x / 2 + 5, -s.y - 2, 3, 3), Color.BLACK)
		return
	if kind == "flyer":
		n.draw_colored_polygon(PackedVector2Array([Vector2(6, wy), Vector2(s.x * 0.2 + 6, wy - 10 - 16 * flap), Vector2(s.x * 0.6, wy + 2)]), wc)
	var ey := -s.y * 0.72
	for ex in [s.x * 0.02, s.x * 0.24]:
		n.draw_rect(Rect2(ex, ey, 7, 8), Color.WHITE)
		n.draw_rect(Rect2(ex + 3, ey + 3, 3, 4), Color.BLACK)
	if kind == "hopper":
		n.draw_rect(Rect2(-s.x / 2 + 2, -4, 8, 4), c.darkened(0.3))
		n.draw_rect(Rect2(s.x / 2 - 10, -4, 8, 4), c.darkened(0.3))


func _update_enemies(delta: float) -> void:
	var p: Vector2 = player.global_position
	var prect := Rect2(p.x - 16.0, p.y - 24.0, 32.0, 48.0)
	var vel: Vector2 = player.velocity
	var g: float = biome["gravity"]
	if player.is_on_floor():
		stomp_chain = 0

	for e in enemies:
		if not e["alive"]:
			continue
		var def: Dictionary = e["def"]
		var kind: String = def["kind"]
		var s: Vector2 = def["size"]
		# Move
		var spd: float = e["speed"]
		if kind == "hopper" and e["y"] >= FLOOR_Y:
			spd = 0.0  # hoppers only move while in the air
		e["x"] += e["dir"] * spd * delta
		if e["x"] < e["min_x"] or e["x"] > e["max_x"]:
			e["dir"] *= -1.0
			e["x"] = clampf(e["x"], e["min_x"], e["max_x"])
		if kind == "flyer" or kind == "dragon":
			e["y"] = FLOOR_Y - e["air"] + sin(t * 3.0 + e["phase"]) * 14.0
		elif kind == "hopper":
			e["vy"] += 1400.0 * g * delta
			e["y"] += e["vy"] * delta
			if e["y"] >= FLOOR_Y:
				e["y"] = FLOOR_Y
				e["vy"] = 0.0
				e["hop_t"] -= delta
				if e["hop_t"] <= 0.0:
					e["vy"] = -randf_range(420.0, 560.0)
					e["hop_t"] = randf_range(0.8, 1.8)
		_place_enemy(e)
		if kind == "flyer" or kind == "dragon":
			e["node"].queue_redraw()  # flapping wings

		# Touching the player?
		var ex: float = e["x"]
		var ey: float = e["y"]
		var erect := Rect2(ex - s.x / 2.0, ey - s.y, s.x, s.y)
		if not erect.intersects(prect):
			continue
		var pts := int(def["points"])
		if vel.y > 0.0 and prev_feet_y <= erect.position.y + 12.0:
			stomp_chain += 1
			pts *= stomp_chain
			player.velocity.y = STOMP_BOUNCE_HELD if Input.is_action_pressed("jump") else STOMP_BOUNCE
			_defeat_enemy(e, pts, ("+%d" % pts) if stomp_chain == 1 else ("+%d  x%d!" % [pts, stomp_chain]))
		elif absf(vel.x) >= MACH_SPEED:
			_defeat_enemy(e, pts + MACH_BONUS, "MACH! +%d" % (pts + MACH_BONUS))
		else:
			e["dir"] = signf(ex - p.x) if ex != p.x else -e["dir"]  # harmless bump


func _defeat_enemy(e: Dictionary, points: int, text: String) -> void:
	e["alive"] = false
	game.on_enemy_defeated(points)
	var node: Node2D = e["node"]
	var tw := create_tween()
	tw.tween_property(node, "scale", Vector2(1.3 * signf(node.scale.x), 0.25), 0.08)
	tw.tween_property(node, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): node.visible = false)
	popup(text, Vector2(e["x"], e["y"] - 70.0))


# =============================================================== player & combat

func _spawn_player() -> void:
	player = PlayerScript.new()
	player.position = Vector2(START_X, FLOOR_Y - 24)
	player.gravity_scale = biome["gravity"]
	player.friction_scale = biome["friction"]
	player.accel_scale = biome["accel"]
	add_child(player)
	player.slashed.connect(_on_slash)
	player.threw.connect(_on_throw)
	var cam := Camera2D.new()
	cam.offset = Vector2(200, -120)
	cam.position_smoothing_enabled = true
	cam.limit_bottom = int(FLOOR_Y + 150)
	cam.limit_left = -100
	cam.limit_right = int(GOAL_X + 400)
	player.add_child(cam)
	cam.make_current()


func _on_slash(facing: int) -> void:
	var p: Vector2 = player.global_position
	var x0 := p.x + 8.0 if facing > 0 else p.x - 8.0 - SLASH_REACH
	var r := Rect2(x0, p.y - 36.0, SLASH_REACH, 66.0)
	for e in enemies:
		if not e["alive"]:
			continue
		var s: Vector2 = e["def"]["size"]
		var erect := Rect2(float(e["x"]) - s.x / 2.0, float(e["y"]) - s.y, s.x, s.y)
		if erect.intersects(r):
			var pts := int(e["def"]["points"]) + SLICE_BONUS
			_defeat_enemy(e, pts, "SLICE! +%d" % pts)
	var cx := r.get_center().x
	for tr in trees:
		if tr["alive"] and absf(float(tr["x"]) - cx) < 50.0:
			_chop(tr)
			break
	for o in ores:
		if o["alive"] and Rect2(o["rect"]).grow(6.0).intersects(r):
			_mine(o)
			break


func _chop(tr: Dictionary) -> void:
	var axe: bool = game.inventory.has_axe
	tr["hp"] -= TREE_HP if axe else 1
	var node: Node2D = tr["node"]
	var tw := create_tween()
	tw.tween_property(node, "rotation", 0.08, 0.05)
	tw.tween_property(node, "rotation", 0.0, 0.05)
	if tr["hp"] > 0:
		if not axe:
			_say("Chop! (An axe chops in one hit)", Vector2(tr["x"], FLOOR_Y - 200.0))
		return
	tr["alive"] = false
	var wood := 3 if axe else 2
	game.add_material("wood", wood)
	popup("+%d wood" % wood, Vector2(tr["x"], FLOOR_Y - 160.0))
	var fall := create_tween()
	fall.tween_property(node, "rotation", 1.5 * (1.0 if randf() < 0.5 else -1.0), 0.4)
	fall.parallel().tween_property(node, "modulate:a", 0.0, 0.5)
	fall.tween_callback(node.queue_free)


func _mine(o: Dictionary) -> void:
	var type: String = o["type"]
	var need: int = Inventory.MINE_TIER[type]
	var x: float = o["rect"].get_center().x
	if game.inventory.pickaxe < need:
		_say("Need a %s Pickaxe!" % Inventory.PICKAXE_NAMES[need], Vector2(x, FLOOR_Y - 120.0))
		return
	o["alive"] = false
	o["node"].queue_free()
	var amount := 2 if type == "stone" else 1
	game.add_material(type, amount)
	popup("+%d %s" % [amount, type], Vector2(x, FLOOR_Y - 110.0))


func _on_throw(facing: int) -> void:
	if game.inventory.daggers <= 0:
		_say("No daggers! Find or craft more.", player.global_position + Vector2(0, -80))
		player.do_slash()
		return
	game.inventory.daggers -= 1
	game.update_inventory_hud()
	var start: Vector2 = player.global_position + Vector2(facing * 20.0, -4.0)
	var node := _add_drawing(start, _draw_dagger, 2)
	node.scale.x = facing
	flying_daggers.append({"node": node, "x": start.x, "y": start.y, "dir": float(facing), "dist": 0.0})


func _draw_dagger(n: Node2D) -> void:
	n.draw_colored_polygon(PackedVector2Array([Vector2(-6, -3), Vector2(16, -2), Vector2(22, 0), Vector2(16, 2), Vector2(-6, 3)]), Color(0.88, 0.9, 0.97))
	n.draw_rect(Rect2(-14, -3, 8, 6), Color(0.5, 0.3, 0.15))


func _update_daggers(delta: float) -> void:
	for d in flying_daggers.duplicate():
		var step: float = DAGGER_SPEED * delta
		d["x"] += d["dir"] * step
		d["dist"] += step
		d["node"].position = Vector2(d["x"], d["y"])
		var hit := Rect2(float(d["x"]) - 12.0, float(d["y"]) - 6.0, 24.0, 12.0)
		# Slices through every enemy in its path
		for e in enemies:
			if not e["alive"]:
				continue
			var s: Vector2 = e["def"]["size"]
			if Rect2(float(e["x"]) - s.x / 2.0, float(e["y"]) - s.y, s.x, s.y).intersects(hit):
				var pts := int(e["def"]["points"]) + SLICE_BONUS
				_defeat_enemy(e, pts, "SLICE! +%d" % pts)
		var stopped: bool = d["dist"] > DAGGER_RANGE
		for so in solids:
			if is_instance_valid(so["node"]) and not so["node"].is_queued_for_deletion() and Rect2(so["rect"]).intersects(hit):
				stopped = true
				break
		if stopped:
			d["node"].queue_free()
			flying_daggers.erase(d)


# =============================================================== per frame

func _physics_process(delta: float) -> void:
	if not game.is_playing():
		return
	t += delta
	msg_cooldown -= delta
	var p: Vector2 = player.global_position
	var feet_y := p.y + 24.0

	# Gems and dagger pickups
	for gm in gems:
		if not gm["taken"] and p.distance_to(gm["pos"]) < 34.0:
			gm["taken"] = true
			gm["node"].visible = false
			game.add_score(10)
	for pk in pickups:
		if not pk["taken"] and p.distance_to(pk["pos"]) < 36.0:
			pk["taken"] = true
			pk["node"].visible = false
			game.inventory.add_daggers(1)
			game.update_inventory_hud()
			popup("+1 dagger", pk["pos"] - Vector2(0, 40))

	# Bounce pads
	var vel: Vector2 = player.velocity
	for pd in pads:
		var r: Rect2 = pd["rect"]
		if vel.y > 0.0 and p.x > r.position.x and p.x < r.end.x and prev_feet_y <= r.position.y + 8.0 and feet_y >= r.position.y:
			player.velocity.y = PAD_BOUNCE * sqrt(float(biome["gravity"]))
			var n: Node2D = pd["node"]
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector2(1.2, 0.7), 0.06)
			tw.tween_property(n, "scale", Vector2.ONE, 0.15)

	_update_enemies(delta)
	_update_daggers(delta)

	# Hazards: falling into a gap costs a heart and sends you back to safety
	if feet_y > FLOOR_Y + 30.0:
		var hazard_name: String = biome["hazard_name"]
		game.hazard_hit(hazard_name if hazard_name != "" else "Fell in")
		player.global_position = last_safe
		player.velocity = Vector2.ZERO
		feet_y = last_safe.y + 24.0
	elif player.is_on_floor() and not _over_gap(p.x, 60.0):
		last_safe = p

	prev_feet_y = feet_y

	if not goal_sent and p.x >= GOAL_X:
		goal_sent = true
		goal_reached.emit()


func allow_goal_again() -> void:
	goal_sent = false


## Floating text that rises and fades.
func popup(text: String, pos: Vector2) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.size = Vector2(320, 40)
	lbl.position = pos - Vector2(160, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 5
	game.style_label(lbl, 26)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)


## A popup that won't spam if you keep hitting something.
func _say(text: String, pos: Vector2) -> void:
	if msg_cooldown > 0.0:
		return
	msg_cooldown = 1.0
	popup(text, pos)
