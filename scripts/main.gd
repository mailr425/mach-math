extends Node2D
## Mach Math: runs the whole game.
##
## A RUN is 3 STAGES, each in a random environment (see biomes.gd), with a
## CRAFTING TABLE before each one. Each stage has 3 math gates.
##   RUN between gates: hurdles, gems, enemies, trees, ore, hazards.
##   THINK at gates: walk up to a door and press E. No timer while you think.
##     First miss = a hint. Second miss = the work is shown and the right door turns gold.
## After stage 3, MATH TIME: race back to the start. The clock stops at gates.
## Hazards cost a heart (armor shields go first). Out of hearts = restart the stage.

const StageScript := preload("res://scripts/stage.gd")

const STAGES_PER_RUN := 3
const ESCAPE_TIME := 45.0
const QUICK_BONUS_SECONDS := 10.0
const MAX_HP := 6            # in half-hearts, so 3 hearts
const HAZARD_DAMAGE := 2     # one heart

const DOOR_HOVER_COLOR := Color(0.55, 0.5, 0.95)
const RIGHT_COLOR := Color(0.2, 0.8, 0.35)
const WRONG_COLOR := Color(0.75, 0.2, 0.2)
const REVEAL_COLOR := Color(0.95, 0.75, 0.1)

const MISTAKE_NAMES := {
	"remainder_too_big": "Remainder bigger than the divisor",
	"forgot_remainder": "Forgot the remainder",
	"off_by_one": "Quotient off by one",
	"wrong_remainder": "Wrong remainder",
}

var inventory := Inventory.new()
var stage = null
var run_biomes: Array = []
var stage_index := 0
var state := "crafting"   # crafting, playing, escape, transition, results
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
var enemies_defeated := 0
var run_mats := {"wood": 0, "stone": 0, "iron": 0, "diamond": 0}
var escape_left := 0.0

var hp := MAX_HP
var shield := 0
var shield_max := 0
var invuln := 0.0

# HUD
var problem_label: Label
var stats_label: Label
var timer_label: Label
var feedback_label: Label
var feedback_bg: ColorRect
var prompt_label: Label
var inv_label: Label
var help_label: Label
var hearts_box: HBoxContainer
var results_label: Label
var results_bg: ColorRect
var door_marker: ColorRect
var feedback_left := 0.0   # < 0 means it stays until the gate is solved

# Crafting screen
var craft_root: ColorRect
var craft_next: Label
var craft_inv: Label
var craft_gear: Label
var craft_grid: GridContainer
var craft_desc: Label
var start_btn: Button


func _ready() -> void:
	randomize()
	_setup_input()
	inventory.load_save()
	var ids := Biomes.ids()
	ids.shuffle()
	run_biomes = ids.slice(0, STAGES_PER_RUN)
	_build_hud()
	_show_crafting()


func is_playing() -> bool:
	return state == "playing" or state == "escape"


# ================================================================ input

func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_keys("interact", [KEY_E, KEY_S, KEY_DOWN, KEY_ENTER, KEY_KP_ENTER])
	_add_keys("attack", [KEY_J, KEY_F])
	_add_keys("throw", [KEY_K])
	_add_keys("restart", [KEY_R])
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)
	# Controller: A = jump, X = pick a door, B = attack, Y = throw, stick / d-pad = move
	_add_joy_button("jump", JOY_BUTTON_A)
	_add_joy_button("interact", JOY_BUTTON_X)
	_add_joy_button("interact", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("attack", JOY_BUTTON_B)
	_add_joy_button("throw", JOY_BUTTON_Y)
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


# ================================================================ run flow

func _show_crafting() -> void:
	state = "crafting"
	RenderingServer.set_default_clear_color(Color(0.12, 0.1, 0.08))
	_set_game_hud_visible(false)
	craft_root.visible = true
	_refresh_crafting(-1)


func _start_stage() -> void:
	craft_root.visible = false
	_remove_stage()
	var biome := Biomes.get_biome(run_biomes[stage_index])
	stage = StageScript.new()
	stage.setup(self, biome)
	add_child(stage)
	stage.goal_reached.connect(_on_goal)
	hp = MAX_HP
	shield_max = inventory.shield_max()
	shield = shield_max
	invuln = 0.0
	combo = 0
	stage.player.set_combo(combo)
	for st in stage.stations:
		_assign_problem(st, level)
	state = "playing"
	_set_game_hud_visible(true)
	results_label.visible = false
	results_bg.visible = false
	_update_hearts()
	update_inventory_hud()
	_show_feedback("Stage %d of %d: %s\n%s" % [stage_index + 1, STAGES_PER_RUN, biome["name"], biome["quirk"]], 4.0)


func _remove_stage() -> void:
	if stage != null:
		stage.queue_free()
		stage = null
	door_marker.visible = false


func _on_goal() -> void:
	if state != "playing":
		return
	if stage_index < STAGES_PER_RUN - 1:
		state = "transition"
		inventory.save()
		_show_feedback("STAGE CLEAR!", 2.0)
		get_tree().create_timer(2.0).timeout.connect(_after_stage_clear)
	else:
		_start_escape()


func _after_stage_clear() -> void:
	stage_index += 1
	_remove_stage()
	_show_crafting()


func _out_of_hearts() -> void:
	state = "transition"
	_show_feedback("Out of hearts! Restarting this stage...", 2.0)
	get_tree().create_timer(2.0).timeout.connect(_start_stage)


func _start_escape() -> void:
	state = "escape"
	escape_left = ESCAPE_TIME
	RenderingServer.set_default_clear_color(Color(stage.biome["sky"]).lerp(Color(0.9, 0.2, 0.15), 0.45))
	for st in stage.stations:
		_assign_problem(st, 0)  # quicker problems for the race back
		st["barrier"] = stage.make_barrier(float(st["x"]) - StageScript.BARRIER_OFFSET)
	stage.reset_enemies()
	_show_feedback("MATH TIME!  Race back to the START!\nThe clock stops while you're at a gate, so take your time on the math.", 5.0)


# ================================================================ things the stage calls

func add_score(points: int) -> void:
	score += points


func on_enemy_defeated(points: int) -> void:
	score += points
	enemies_defeated += 1


func add_material(m: String, n: int) -> void:
	inventory.mats[m] = int(inventory.mats[m]) + n
	run_mats[m] = int(run_mats[m]) + n
	update_inventory_hud()


func hazard_hit(hazard_name: String) -> void:
	if invuln > 0.0 or not is_playing():
		return
	invuln = 1.5
	combo = 0
	stage.player.set_combo(combo)
	stage.player.blink(1.5)
	var dmg := HAZARD_DAMAGE
	var absorbed := mini(shield, dmg)
	shield -= absorbed
	dmg -= absorbed
	hp -= dmg
	_update_hearts()
	if hp <= 0:
		_out_of_hearts()
		return
	if absorbed > 0:
		_show_feedback("%s! Your armor took the hit." % hazard_name, 2.5)
	else:
		_show_feedback("Ouch! %s! You lost a heart." % hazard_name, 2.5)


# ================================================================ game loop

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart") and state != "crafting":
		inventory.save()
		get_tree().reload_current_scene()
		return
	if invuln > 0.0:
		invuln -= delta
	_tick_feedback(delta)
	if not is_playing():
		return
	clock += delta

	var zone_station = _zone_station()
	if zone_station != null and zone_station["arrived"] < 0.0:
		zone_station["arrived"] = clock

	var door := _door_under_player(zone_station)
	_update_door_hover(zone_station, door)
	if door >= 0 and Input.is_action_just_pressed("interact"):
		_pick(zone_station, door)

	if state == "escape":
		if zone_station == null:
			escape_left -= delta  # the clock only runs while you're running
		if stage.player.global_position.x <= StageScript.START_X + 50.0:
			_finish(true)
			return
		elif escape_left <= 0.0:
			_finish(false)
			return

	_update_hud(zone_station)


## The unsolved gate you're standing near, or null.
func _zone_station():
	var x: float = stage.player.global_position.x
	for st in stage.stations:
		if st["resolved"]:
			continue
		var sx: float = st["x"]
		if state == "playing" and x > sx - StageScript.ZONE_REACH and x < sx + StageScript.BARRIER_OFFSET:
			return st
		if state == "escape" and x < sx + StageScript.ZONE_REACH and x > sx - StageScript.BARRIER_OFFSET:
			return st
	return null


func _door_under_player(st) -> int:
	if st == null or not stage.player.is_on_floor():
		return -1
	var x: float = stage.player.global_position.x
	for i in 3:
		var dx: float = st["x"] + (i - 1) * StageScript.DOOR_SPACING
		if absf(x - dx) < StageScript.DOOR_WIDTH / 2.0:
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
				st["doors"][i].color = DOOR_HOVER_COLOR if i == door else StageScript.DOOR_COLOR
	if door >= 0:
		var dx: float = st["x"] + (door - 1) * StageScript.DOOR_SPACING
		door_marker.position = Vector2(dx - StageScript.DOOR_WIDTH / 2.0, StageScript.FLOOR_Y - StageScript.DOOR_HEIGHT - 16.0)
		door_marker.visible = true
	else:
		door_marker.visible = false


func _assign_problem(st: Dictionary, lvl: int) -> void:
	var p := DivisionProblem.make(lvl)
	st["problem"] = p
	st["resolved"] = false
	st["locked"] = [false, false, false]
	st["misses"] = 0
	st["arrived"] = -1.0
	st["sign"].text = p.question_text()
	for i in 3:
		st["doors"][i].color = StageScript.DOOR_COLOR
		st["labels"][i].text = p.choices[i]["text"]


func _pick(st: Dictionary, i: int) -> void:
	var p: DivisionProblem = st["problem"]
	if st["locked"][i]:
		_show_feedback("You already tried that door. Pick another one!", 2.0)
		return
	if i == p.correct_index:
		_solve(st, i)
		return

	var kind: String = p.choices[i]["kind"]
	mistakes[kind] = mistakes.get(kind, 0) + 1
	st["locked"][i] = true
	st["doors"][i].color = WRONG_COLOR
	st["misses"] += 1
	combo = 0
	stage.player.set_combo(combo)
	if st["misses"] == 1:
		streak_wrong += 1
		streak_right = 0
		_show_feedback("Not quite! " + p.hint_for(kind) + "\nTry another door.", -1.0)
		if state == "playing" and streak_wrong >= 2 and level > 1:
			level -= 1
			streak_wrong = 0
			_refresh_ahead(st)
	else:
		_show_feedback(p.hint_for(kind) + "\n" + p.work_text() + "\nThe gold door has the answer!", -1.0)


func _solve(st: Dictionary, i: int) -> void:
	var p: DivisionProblem = st["problem"]
	st["resolved"] = true
	st["doors"][i].color = RIGHT_COLOR
	if st["barrier"] != null and is_instance_valid(st["barrier"]):
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
		if clock - float(st["arrived"]) <= QUICK_BONUS_SECONDS:
			score += 50
			msg += "    Quick thinking! +50"
		if combo >= 3:
			msg += "    COMBO x%d!" % combo
		if state == "playing" and streak_right >= 3 and level < 3:
			level += 1
			streak_right = 0
			msg += "    LEVEL UP!"
			_refresh_ahead(st)
		_show_feedback(msg, 3.0)
		stage.player.boost()
	else:
		score += 25
		_show_feedback("You got it!  %s" % p.answer_text(), 3.0)
	stage.player.set_combo(combo)


## When difficulty changes, give the gates still ahead new problems.
func _refresh_ahead(current: Dictionary) -> void:
	for st in stage.stations:
		if st["x"] != current["x"] and not st["resolved"]:
			_assign_problem(st, level)


func _finish(escaped: bool) -> void:
	state = "results"
	stage.player.set_physics_process(false)
	_clear_feedback()
	_set_game_hud_visible(false)
	door_marker.visible = false
	inventory.save()

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
	lines.append("Enemies defeated: %d" % enemies_defeated)
	var got: Array = []
	for m in Inventory.MATERIALS:
		if int(run_mats[m]) > 0:
			got.append("%d %s" % [run_mats[m], m])
	if not got.is_empty():
		lines.append("Gathered: " + ", ".join(got))
	if mistakes.size() > 0:
		lines.append("Things to practice:")
		for kind in mistakes:
			lines.append("  %s: %d" % [MISTAKE_NAMES.get(kind, kind), mistakes[kind]])
	lines.append("")
	lines.append("Press R to play again (your gear is saved)")
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


# ================================================================ HUD

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
	hearts_box = HBoxContainer.new()
	hearts_box.position = Vector2(20, 112)
	hearts_box.add_theme_constant_override("separation", 4)
	hud.add_child(hearts_box)
	timer_label = _hud_label(hud, Vector2(860, 16), 32)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size = Vector2(400, 100)
	prompt_label = _hud_label(hud, Vector2(0, 590), 30)
	inv_label = _hud_label(hud, Vector2(20, 645), 20)
	inv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	help_label = _hud_label(hud, Vector2(0, 685), 17)
	help_label.text = "Move: A/D   Jump: Space   Pick door: E   Attack: J or click (hold to throw)   Throw: K   Restart: R"

	results_bg = ColorRect.new()
	results_bg.color = Color(0, 0, 0, 0.75)
	results_bg.position = Vector2(190, 70)
	results_bg.size = Vector2(900, 580)
	results_bg.visible = false
	hud.add_child(results_bg)
	results_label = _hud_label(hud, Vector2(190, 90), 28)
	results_label.size = Vector2(900, 540)
	results_label.visible = false

	door_marker = ColorRect.new()
	door_marker.size = Vector2(StageScript.DOOR_WIDTH, 8)
	door_marker.color = Color.WHITE
	door_marker.z_index = 3
	door_marker.visible = false
	add_child(door_marker)

	_build_crafting(hud)


func _set_game_hud_visible(v: bool) -> void:
	for n in [problem_label, stats_label, timer_label, prompt_label, inv_label, help_label, hearts_box]:
		n.visible = v
	if not v:
		_clear_feedback()


func _hud_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.size = Vector2(1280, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_label(lbl, font_size)
	parent.add_child(lbl)
	return lbl


func style_label(lbl: Label, font_size: int) -> void:
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


func _tick_feedback(delta: float) -> void:
	if feedback_left > 0.0:
		feedback_left -= delta
		if feedback_left <= 0.0:
			_clear_feedback()


func _update_hearts() -> void:
	for c in hearts_box.get_children():
		hearts_box.remove_child(c)
		c.queue_free()
	for i in MAX_HP / 2:
		hearts_box.add_child(_heart_icon(clampi(hp - i * 2, 0, 2), Color(0.9, 0.15, 0.2)))
	for i in ceili(shield_max / 2.0):
		hearts_box.add_child(_heart_icon(clampi(shield - i * 2, 0, 2), Color(0.3, 0.6, 1.0)))


## A simple square heart: fill 2 = full, 1 = half, 0 = empty.
func _heart_icon(fill: int, color: Color) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(24, 24)
	var bg := ColorRect.new()
	bg.size = Vector2(22, 22)
	bg.color = Color(0.1, 0.05, 0.05, 0.8)
	c.add_child(bg)
	if fill > 0:
		var f := ColorRect.new()
		f.size = Vector2(22.0 if fill >= 2 else 11.0, 22.0)
		f.color = color
		c.add_child(f)
	return c


func update_inventory_hud() -> void:
	var parts: Array = []
	for m in Inventory.MATERIALS:
		parts.append("%s %d" % [m.capitalize(), inventory.mats[m]])
	inv_label.text = "   ".join(parts) + "      Daggers %d/%d" % [inventory.daggers, Inventory.MAX_DAGGERS]


func _update_hud(zone_station) -> void:
	# Show the next gate's problem early so he can start thinking while running
	var next = zone_station
	if next == null:
		for st in stage.stations:
			if st["resolved"]:
				continue
			if next == null or (state == "escape" and st["x"] > next["x"]):
				next = st
	if next != null:
		problem_label.text = next["problem"].question_text()
	else:
		problem_label.text = "RUN BACK TO THE START!" if state == "escape" else "Head for the GOAL!"

	var door := _door_under_player(zone_station)
	if door >= 0 and not zone_station["locked"][door]:
		prompt_label.text = "Press E to pick  %s" % zone_station["problem"].choices[door]["text"]
	else:
		prompt_label.text = ""

	stats_label.text = "Score: %d\nCombo: x%d\nLevel: %d" % [score, combo, level]
	if state == "escape":
		timer_label.text = "TIME: %d" % ceili(escape_left)
		if zone_station != null:
			timer_label.text += "\n(paused)"
	else:
		timer_label.text = "Stage %d/%d" % [stage_index + 1, STAGES_PER_RUN]


# ================================================================ crafting screen

func _build_crafting(hud: CanvasLayer) -> void:
	craft_root = ColorRect.new()
	craft_root.color = Color(0.1, 0.08, 0.06, 0.95)
	craft_root.size = Vector2(1280, 720)
	hud.add_child(craft_root)
	var box := VBoxContainer.new()
	box.position = Vector2(90, 16)
	box.size = Vector2(1100, 690)
	box.add_theme_constant_override("separation", 8)
	craft_root.add_child(box)
	var title := _plain_label(box, 40)
	title.text = "Crafting Table"
	craft_next = _plain_label(box, 24)
	craft_inv = _plain_label(box, 22)
	craft_gear = _plain_label(box, 20)
	craft_grid = GridContainer.new()
	craft_grid.columns = 3
	craft_grid.add_theme_constant_override("h_separation", 8)
	craft_grid.add_theme_constant_override("v_separation", 6)
	craft_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(craft_grid)
	craft_desc = _plain_label(box, 20)
	start_btn = Button.new()
	start_btn.text = "START STAGE"
	start_btn.custom_minimum_size = Vector2(320, 56)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(_start_stage)
	box.add_child(start_btn)


func _plain_label(parent: Node, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style_label(lbl, font_size)
	parent.add_child(lbl)
	return lbl


func _refresh_crafting(focus_index: int) -> void:
	var biome := Biomes.get_biome(run_biomes[stage_index])
	craft_next.text = "Next up: Stage %d of %d, %s\n%s" % [stage_index + 1, STAGES_PER_RUN, biome["name"], biome["quirk"]]
	var parts: Array = []
	for m in Inventory.MATERIALS:
		parts.append("%s: %d" % [m.capitalize(), inventory.mats[m]])
	craft_inv.text = "   ".join(parts)
	var armor_parts: Array = []
	for slot in inventory.armor:
		armor_parts.append("%s %s" % [str(inventory.armor[slot]).capitalize(), slot])
	craft_gear.text = "Pickaxe: %s    Axe: %s    Daggers: %d/%d    Armor: %s  (shield: %s hearts)" % [
		Inventory.PICKAXE_NAMES[inventory.pickaxe], "Yes" if inventory.has_axe else "No",
		inventory.daggers, Inventory.MAX_DAGGERS, ", ".join(armor_parts), str(inventory.shield_max() / 2.0)]

	for c in craft_grid.get_children():
		craft_grid.remove_child(c)
		c.queue_free()
	var buttons: Array = []
	for i in Inventory.RECIPES.size():
		var r: Dictionary = Inventory.RECIPES[i]
		var status := inventory.craft_status(r)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(350, 60)
		btn.add_theme_font_size_override("font_size", 17)
		btn.text = "%s\n%s" % [r["name"], status if status != "" else inventory.cost_text(r)]
		btn.disabled = status != ""
		btn.pressed.connect(_on_craft.bind(i))
		btn.focus_entered.connect(_describe.bind(i))
		btn.mouse_entered.connect(_describe.bind(i))
		craft_grid.add_child(btn)
		buttons.append(btn)
	if focus_index >= 0 and focus_index < buttons.size() and not buttons[focus_index].disabled:
		buttons[focus_index].grab_focus()
	else:
		start_btn.grab_focus()


func _describe(i: int) -> void:
	var r: Dictionary = Inventory.RECIPES[i]
	var status := inventory.craft_status(r)
	craft_desc.text = "%s: %s%s" % [r["name"], r["desc"], ("   (" + status + ")") if status != "" else ""]


func _on_craft(i: int) -> void:
	var r: Dictionary = Inventory.RECIPES[i]
	if inventory.craft(r):
		_refresh_crafting(i)
		craft_desc.text = "Crafted %s!" % r["name"]
