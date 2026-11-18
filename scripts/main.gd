extends Node2D
## Mach Math
##
## RUN between gates: hurdles, gems, and speed. Your combo makes you faster.
## THINK at gates: a wall blocks the way. Three doors show answers.
##   Walk up to a door and press E (or Down / S) to pick it. No timer while you think.
##   A wrong pick gives a hint. A second wrong pick shows the work and lights up the right door.
##   You always finish by picking the right answer, which opens the wall.
## MATH TIME: reach the GOAL, then race back to START. The clock only counts
##   running and stops while you're at a gate.

const PlayerScript := preload("res://scripts/player.gd")

const FLOOR_Y := 600.0
const STATION_COUNT := 6
const STATION_SPACING := 1800.0
const FIRST_STATION_X := 1400.0
const START_X := 150.0
const ESCAPE_TIME := 60.0
const QUICK_BONUS_SECONDS := 10.0

const DOOR_WIDTH := 96.0
const DOOR_HEIGHT := 120.0
const DOOR_SPACING := 120.0
const BARRIER_OFFSET := 240.0   # how far past the middle door the wall sits
const ZONE_REACH := 400.0       # how far before the doors the "thinking zone" starts

const DOOR_COLOR := Color(0.35, 0.3, 0.6)
const DOOR_HOVER_COLOR := Color(0.55, 0.5, 0.95)
const RIGHT_COLOR := Color(0.2, 0.8, 0.35)
const WRONG_COLOR := Color(0.75, 0.2, 0.2)
const REVEAL_COLOR := Color(0.95, 0.75, 0.1)
const BARRIER_COLOR := Color(0.55, 0.15, 0.2)
const NORMAL_SKY := Color(0.45, 0.7, 0.95)
const ESCAPE_SKY := Color(0.85, 0.4, 0.3)

const MISTAKE_NAMES := {
	"remainder_too_big": "Remainder bigger than the divisor",
	"forgot_remainder": "Forgot the remainder",
	"off_by_one": "Quotient off by one",
	"wrong_remainder": "Wrong remainder",
}

var player
var stations: Array = []
var gems: Array = []           # Each: {"node", "pos", "taken"}
var level_end_x := 0.0
var clock := 0.0

# Adaptive difficulty: 3 first-try rights in a row = harder, 2 misses in a row = easier
var level := 1
var streak_right := 0
var streak_wrong := 0

var combo := 0
var best_combo := 0
var score := 0
var answered := 0
var first_try_correct := 0
var mistakes := {}
var escaping := false
var escape_left := 0.0
var finished := false

var problem_label: Label
var stats_label: Label
var timer_label: Label
var feedback_label: Label
var feedback_bg: ColorRect
var prompt_label: Label
var results_label: Label
var results_bg: ColorRect
var door_marker: ColorRect
var feedback_left := 0.0   # < 0 means it stays until the gate is solved


func _ready() -> void:
	randomize()
	_setup_input()
	RenderingServer.set_default_clear_color(NORMAL_SKY)
	_build_world()
	_build_hud()
	_spawn_player()
	for st in stations:
		_assign_problem(st, level)
	_show_feedback("Run to the gate, then walk up to a door and press E to pick an answer!", 5.0)


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_keys("interact", [KEY_E, KEY_S, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER])
	_add_keys("restart", [KEY_R])
	# Controller: A = jump, X = pick a door, left stick / d-pad = move
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("interact", JOY_BUTTON_X)
	_add_joy_button("interact", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("move_right", JOY_BUTTON_DPAD_RIGHT)
	for pair in [["move_left", -1.0], ["move_right", 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXIS_LEFT_X
		jm.axis_value = pair[1]
		InputMap.action_add_event(pair[0], jm)


func _add_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)  # avoids duplicates when the scene restarts
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _add_joy_button(action: String, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var last_x := FIRST_STATION_X + (STATION_COUNT - 1) * STATION_SPACING
	level_end_x = last_x + 1100.0

	_add_block(Rect2(-200, FLOOR_Y, level_end_x + 800, 300), Color(0.35, 0.25, 0.15))
	_add_block(Rect2(-200, FLOOR_Y, level_end_x + 800, 16), Color(0.3, 0.75, 0.3))
	_add_block(Rect2(-100, FLOOR_Y - 900, 100, 900), Color(0.3, 0.3, 0.35))
	_add_block(Rect2(level_end_x + 300, FLOOR_Y - 900, 100, 900), Color(0.3, 0.3, 0.35))

	# Running sections: hurdles with gems
	_add_hurdle(650.0)
	for i in STATION_COUNT:
		var x := FIRST_STATION_X + i * STATION_SPACING
		stations.append(_build_station(x))
		_add_hurdle(x + 550.0)
		if i < STATION_COUNT - 1:
			_add_hurdle(x + 1000.0)
			for g in 3:
				_add_gem(Vector2(x + 720.0 + g * 60.0, FLOOR_Y - 40.0))

	_add_rect(Rect2(level_end_x, FLOOR_Y - 300, 12, 300), Color.WHITE)
	_add_rect(Rect2(level_end_x + 12, FLOOR_Y - 300, 90, 60), Color(1, 0.85, 0.1))
	_add_world_label("GOAL", Vector2(level_end_x - 194, FLOOR_Y - 360), 40)
	_add_world_label("START", Vector2(START_X - 200, FLOOR_Y - 200), 32)


func _add_hurdle(x: float) -> void:
	var h := randf_range(40.0, 90.0)
	_add_block(Rect2(x - 30, FLOOR_Y - h, 60, h), Color(0.6, 0.45, 0.3))
	_add_gem(Vector2(x, FLOOR_Y - h - 60.0))


func _add_gem(pos: Vector2) -> void:
	var gem := ColorRect.new()
	gem.size = Vector2(18, 18)
	gem.pivot_offset = Vector2(9, 9)
	gem.position = pos - Vector2(9, 9)
	gem.rotation = PI / 4
	gem.color = Color(1, 0.9, 0.2)
	add_child(gem)
	gems.append({"node": gem, "pos": pos, "taken": false})


func _build_station(x: float) -> Dictionary:
	var doors: Array = []
	var labels: Array = []
	for i in 3:
		var dx := x + (i - 1) * DOOR_SPACING
		var door := _add_rect(Rect2(dx - DOOR_WIDTH / 2, FLOOR_Y - DOOR_HEIGHT, DOOR_WIDTH, DOOR_HEIGHT), DOOR_COLOR)
		var lbl := Label.new()
		lbl.size = Vector2(DOOR_WIDTH, 56)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_label(lbl, 26)
		door.add_child(lbl)
		doors.append(door)
		labels.append(lbl)
	var sign := _add_world_label("", Vector2(x - 200, FLOOR_Y - DOOR_HEIGHT - 80), 36)
	var st := {"x": x, "problem": null, "resolved": false, "doors": doors, "labels": labels,
		"locked": [false, false, false], "misses": 0, "barrier": null, "sign": sign, "arrived": -1.0}
	st["barrier"] = _make_barrier(x + BARRIER_OFFSET)
	return st


func _make_barrier(x: float) -> StaticBody2D:
	var rect := Rect2(x - 15, FLOOR_Y - 420, 30, 420)
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	body.add_child(col)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.position = -rect.size / 2
	vis.color = BARRIER_COLOR
	body.add_child(vis)
	add_child(body)
	return body


func _assign_problem(st: Dictionary, lvl: int) -> void:
	var p := DivisionProblem.make(lvl)
	st["problem"] = p
	st["resolved"] = false
	st["locked"] = [false, false, false]
	st["misses"] = 0
	st["arrived"] = -1.0
	st["sign"].text = p.question_text()
	for i in 3:
		st["doors"][i].color = DOOR_COLOR
		st["labels"][i].text = p.choices[i]["text"]


func _add_block(rect: Rect2, color: Color) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	body.add_child(col)
	var vis := ColorRect.new()
	vis.size = rect.size
	vis.position = -rect.size / 2
	vis.color = color
	body.add_child(vis)
	add_child(body)


func _add_rect(rect: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = rect.position
	r.size = rect.size
	r.color = color
	add_child(r)
	return r


func _add_world_label(text: String, pos: Vector2, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = Vector2(400, 50)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(lbl, font_size)
	add_child(lbl)
	return lbl


func _spawn_player() -> void:
	door_marker = _add_rect(Rect2(0, 0, DOOR_WIDTH, 8), Color.WHITE)
	door_marker.visible = false
	player = PlayerScript.new()
	player.position = Vector2(START_X, FLOOR_Y - 24)
	add_child(player)
	var cam := Camera2D.new()
	cam.offset = Vector2(200, -120)
	cam.position_smoothing_enabled = true
	cam.limit_bottom = int(FLOOR_Y + 150)
	cam.limit_left = -100
	player.add_child(cam)
	cam.make_current()


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	problem_label = _hud_label(hud, Vector2(0, 16), 44)

	feedback_bg = ColorRect.new()
	feedback_bg.color = Color(0, 0, 0, 0.6)
	feedback_bg.position = Vector2(140, 84)
	feedback_bg.size = Vector2(1000, 110)
	feedback_bg.visible = false
	hud.add_child(feedback_bg)
	feedback_label = _hud_label(hud, Vector2(160, 90), 26)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.size = Vector2(960, 100)
	feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	stats_label = _hud_label(hud, Vector2(20, 16), 24)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_label.size = Vector2(300, 100)
	timer_label = _hud_label(hud, Vector2(860, 16), 32)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size = Vector2(400, 100)
	prompt_label = _hud_label(hud, Vector2(0, 620), 30)

	var help := _hud_label(hud, Vector2(0, 680), 18)
	help.text = "Move: A/D or arrows     Jump: Space     Pick a door: E (or Down)     Restart: R"

	results_bg = ColorRect.new()
	results_bg.color = Color(0, 0, 0, 0.7)
	results_bg.position = Vector2(190, 120)
	results_bg.size = Vector2(900, 500)
	results_bg.visible = false
	hud.add_child(results_bg)
	results_label = _hud_label(hud, Vector2(190, 140), 30)
	results_label.size = Vector2(900, 460)
	results_label.visible = false


func _hud_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = Vector2(1280, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(lbl, font_size)
	parent.add_child(lbl)
	return lbl


func _style_label(lbl: Label, font_size: int) -> void:
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)


## seconds < 0 keeps the message up until the gate is solved.
func _show_feedback(text: String, seconds := 3.0) -> void:
	feedback_label.text = text
	feedback_bg.visible = text != ""
	feedback_left = seconds


func _clear_feedback() -> void:
	feedback_label.text = ""
	feedback_bg.visible = false
	feedback_left = 0.0


# ---------------------------------------------------------------- game loop

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if finished:
		return
	clock += delta

	_collect_gems()
	var zone_station = _zone_station()
	if zone_station != null and zone_station["arrived"] < 0.0:
		zone_station["arrived"] = clock

	var door := _door_under_player(zone_station)
	_update_door_hover(zone_station, door)
	if door >= 0 and Input.is_action_just_pressed("interact"):
		_pick(zone_station, door)

	if not escaping and player.global_position.x >= level_end_x:
		_start_escape()
	elif escaping:
		if zone_station == null:
			escape_left -= delta  # the clock only runs while you're running
		if player.global_position.x <= START_X + 50:
			_finish(true)
		elif escape_left <= 0.0:
			_finish(false)

	_update_hud(delta, zone_station)


func _collect_gems() -> void:
	var p: Vector2 = player.global_position
	for g in gems:
		if not g["taken"] and p.distance_to(g["pos"]) < 34.0:
			g["taken"] = true
			g["node"].visible = false
			score += 10


## The unsolved gate you're standing near, or null.
func _zone_station():
	var x: float = player.global_position.x
	for st in stations:
		if st["resolved"]:
			continue
		var sx: float = st["x"]
		if not escaping and x > sx - ZONE_REACH and x < sx + BARRIER_OFFSET:
			return st
		if escaping and x < sx + ZONE_REACH and x > sx - BARRIER_OFFSET:
			return st
	return null


func _door_under_player(st) -> int:
	if st == null or not player.is_on_floor():
		return -1
	var x: float = player.global_position.x
	for i in 3:
		var dx: float = st["x"] + (i - 1) * DOOR_SPACING
		if absf(x - dx) < DOOR_WIDTH / 2:
			return i
	return -1


func _update_door_hover(st, door: int) -> void:
	if st != null:
		for i in 3:
			if st["locked"][i]:
				continue
			var revealed: bool = st["misses"] >= 2 and i == st["problem"].correct_index
			if revealed:
				st["doors"][i].color = REVEAL_COLOR
			else:
				st["doors"][i].color = DOOR_HOVER_COLOR if i == door else DOOR_COLOR
	if door >= 0:
		var dx: float = st["x"] + (door - 1) * DOOR_SPACING
		door_marker.position = Vector2(dx - DOOR_WIDTH / 2, FLOOR_Y - DOOR_HEIGHT - 16)
		door_marker.visible = true
	else:
		door_marker.visible = false


func _pick(st: Dictionary, i: int) -> void:
	var p: DivisionProblem = st["problem"]
	if st["locked"][i]:
		_show_feedback("You already tried that door. Pick another one!", 2.0)
		return

	if i == p.correct_index:
		_solve(st, i)
		return

	# Wrong pick
	var kind: String = p.choices[i]["kind"]
	mistakes[kind] = mistakes.get(kind, 0) + 1
	st["locked"][i] = true
	st["doors"][i].color = WRONG_COLOR
	st["misses"] += 1
	combo = 0
	player.set_combo(combo)
	if st["misses"] == 1:
		streak_wrong += 1
		streak_right = 0
		_show_feedback("Not quite! " + p.hint_for(kind) + "\nTry another door.", -1.0)
		if not escaping and streak_wrong >= 2 and level > 1:
			level -= 1
			streak_wrong = 0
			_refresh_ahead(st)
	else:
		_show_feedback(p.hint_for(kind) + "\n" + p.work_text() + "\nThe gold door has the answer!", -1.0)


func _solve(st: Dictionary, i: int) -> void:
	var p: DivisionProblem = st["problem"]
	st["resolved"] = true
	st["doors"][i].color = RIGHT_COLOR
	if st["barrier"] != null:
		st["barrier"].queue_free()
		st["barrier"] = null
	answered += 1

	if st["misses"] == 0:
		first_try_correct += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		score += 100 + 25 * (combo - 1)
		streak_right += 1
		streak_wrong = 0
		var msg := "Nice!  %s" % p.answer_text()
		if clock - st["arrived"] <= QUICK_BONUS_SECONDS:
			score += 50
			msg += "    Quick thinking! +50"
		if combo >= 3:
			msg += "    COMBO x%d!" % combo
		if not escaping and streak_right >= 3 and level < 3:
			level += 1
			streak_right = 0
			msg += "    LEVEL UP!"
			_refresh_ahead(st)
		_show_feedback(msg, 3.0)
		player.boost()
	else:
		score += 25
		_show_feedback("You got it!  %s" % p.answer_text(), 3.0)
	player.set_combo(combo)


## When difficulty changes, give the gates still ahead new problems.
func _refresh_ahead(current: Dictionary) -> void:
	for st in stations:
		if st != current and not st["resolved"]:
			_assign_problem(st, level)


func _start_escape() -> void:
	escaping = true
	escape_left = ESCAPE_TIME
	RenderingServer.set_default_clear_color(ESCAPE_SKY)
	for st in stations:
		_assign_problem(st, 0)  # quicker problems for the race back
		st["barrier"] = _make_barrier(st["x"] - BARRIER_OFFSET)
	_show_feedback("MATH TIME!  Race back to the START!\nThe clock stops while you're at a gate, so take your time on the math.", 5.0)


func _finish(escaped: bool) -> void:
	finished = true
	player.set_physics_process(false)
	_clear_feedback()
	timer_label.text = ""
	problem_label.text = ""
	prompt_label.text = ""
	door_marker.visible = false

	var accuracy := float(first_try_correct) / maxf(answered, 1)
	var time_bonus := int(escape_left) * 20 if escaped else 0
	score += time_bonus

	var rank := "D"
	if escaped:
		if accuracy >= 1.0:
			rank = "P"
		elif accuracy >= 0.9:
			rank = "S"
		elif accuracy >= 0.75:
			rank = "A"
		elif accuracy >= 0.6:
			rank = "B"
		else:
			rank = "C"

	var lines: Array = []
	lines.append("YOU ESCAPED!" if escaped else "TIME'S UP!")
	lines.append("RANK: %s" % rank)
	lines.append("Score: %d   (time bonus %d)" % [score, time_bonus])
	lines.append("Right on the first try: %d / %d    Best combo: x%d" % [first_try_correct, answered, best_combo])
	if mistakes.size() > 0:
		lines.append("")
		lines.append("Things to practice:")
		for kind in mistakes:
			lines.append("  %s: %d" % [MISTAKE_NAMES.get(kind, kind), mistakes[kind]])
	lines.append("")
	lines.append("Press R to play again")
	results_label.text = "\n".join(lines)
	results_label.visible = true
	results_bg.visible = true
	_save_progress(escaped, rank)


## Appends one line per run to a CSV, so a parent can see trends over time.
## Find it via Project > Open User Data Folder in the Godot editor.
func _save_progress(escaped: bool, rank: String) -> void:
	var path := "user://progress.csv"
	var is_new := not FileAccess.file_exists(path)
	var f: FileAccess
	if is_new:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		return
	if is_new:
		f.store_line("date,problems,first_try_correct,best_combo,escaped,rank,remainder_too_big,forgot_remainder,off_by_one,wrong_remainder")
	else:
		f.seek_end()
	f.store_line("%s,%d,%d,%d,%s,%s,%d,%d,%d,%d" % [
		Time.get_datetime_string_from_system(), answered, first_try_correct, best_combo, str(escaped), rank,
		mistakes.get("remainder_too_big", 0), mistakes.get("forgot_remainder", 0),
		mistakes.get("off_by_one", 0), mistakes.get("wrong_remainder", 0)])
	f.close()


func _update_hud(delta: float, zone_station) -> void:
	# Show the next gate's problem early so he can start thinking while running
	var next = zone_station
	if next == null:
		for st in stations:
			if st["resolved"]:
				continue
			if next == null or (escaping and st["x"] > next["x"]):
				next = st
	if next != null:
		problem_label.text = next["problem"].question_text()
	else:
		problem_label.text = "RUN BACK TO THE START!" if escaping else "Head for the GOAL!"

	var door := _door_under_player(zone_station)
	if door >= 0 and not zone_station["locked"][door]:
		prompt_label.text = "Press E to pick  %s" % zone_station["problem"].choices[door]["text"]
	else:
		prompt_label.text = ""

	stats_label.text = "Score: %d\nCombo: x%d\nLevel: %d" % [score, combo, level]
	if escaping:
		timer_label.text = "TIME: %d" % ceili(escape_left)
		if zone_station != null:
			timer_label.text += "\n(paused)"
	else:
		timer_label.text = ""

	if feedback_left > 0.0:
		feedback_left -= delta
		if feedback_left <= 0.0:
			_clear_feedback()
