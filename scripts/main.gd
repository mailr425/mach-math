extends Node2D
## Mach Math, first playable version.
## Run right through the answer gates. At each gate, the height you pass
## through picks your answer: LOW = keep running, MIDDLE = jump,
## HIGH = jump off the ledge before the gate.
## When you reach the GOAL, MATH TIME starts: race back to the start before the timer runs out.

const PlayerScript := preload("res://scripts/player.gd")

const FLOOR_Y := 600.0
const STATION_COUNT := 8
const STATION_SPACING := 1300.0
const FIRST_STATION_X := 1300.0
const START_X := 150.0
const ESCAPE_TIME := 75.0

# Gate bands, measured as how high your feet are above the floor
const BAND_LOW := 85.0
const BAND_MID := 195.0
const GATE_TOP := 330.0
const PANEL_WIDTH := 110.0

const PANEL_COLORS := [Color(0.25, 0.45, 0.95, 0.85), Color(0.6, 0.3, 0.9, 0.85), Color(0.1, 0.7, 0.7, 0.85)]
const RIGHT_COLOR := Color(0.2, 0.85, 0.35, 0.95)
const WRONG_COLOR := Color(0.9, 0.25, 0.25, 0.95)
const NORMAL_SKY := Color(0.45, 0.7, 0.95)
const ESCAPE_SKY := Color(0.85, 0.35, 0.3)

const MISTAKE_NAMES := {
	"remainder_too_big": "Remainder bigger than the divisor",
	"forgot_remainder": "Forgot the remainder",
	"off_by_one": "Quotient off by one",
	"wrong_remainder": "Wrong remainder",
}

var player
var stations: Array = []   # Each: {"x", "problem", "resolved", "panels", "answer_labels", "sign"}
var level_end_x := 0.0
var prev_x := 0.0

# Adaptive difficulty: 3 right in a row = harder, 2 wrong in a row = easier
var level := 1
var streak_right := 0
var streak_wrong := 0

var combo := 0
var best_combo := 0
var score := 0
var answered := 0
var correct := 0
var mistakes := {}
var escaping := false
var escape_left := 0.0
var finished := false

var problem_label: Label
var stats_label: Label
var timer_label: Label
var feedback_label: Label
var results_label: Label
var feedback_left := 0.0


func _ready() -> void:
	randomize()
	_setup_input()
	RenderingServer.set_default_clear_color(NORMAL_SKY)
	_build_world()
	_build_hud()
	_spawn_player()
	for st in stations:
		_assign_problem(st, level)
	_show_feedback("Run through the gate with the right answer!", 4.0)


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_keys("restart", [KEY_R])
	# Controller support
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	InputMap.action_add_event("jump", jb)
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


# ---------------------------------------------------------------- world

func _build_world() -> void:
	var last_x := FIRST_STATION_X + (STATION_COUNT - 1) * STATION_SPACING
	level_end_x = last_x + 900.0

	# Floor and walls
	_add_block(Rect2(-200, FLOOR_Y, level_end_x + 800, 300), Color(0.35, 0.25, 0.15))
	_add_block(Rect2(-200, FLOOR_Y, level_end_x + 800, 16), Color(0.3, 0.75, 0.3))
	_add_block(Rect2(-100, FLOOR_Y - 900, 100, 900), Color(0.3, 0.3, 0.35))
	_add_block(Rect2(level_end_x + 300, FLOOR_Y - 900, 100, 900), Color(0.3, 0.3, 0.35))

	for i in STATION_COUNT:
		var x := FIRST_STATION_X + i * STATION_SPACING
		# Ledges on both sides of the gate so the HIGH gate is reachable either direction
		_add_block(Rect2(x - 520, FLOOR_Y - 100, 350, 20), Color(0.75, 0.55, 0.3), true)
		_add_block(Rect2(x + 170, FLOOR_Y - 100, 350, 20), Color(0.75, 0.55, 0.3), true)
		stations.append(_build_station(x))

	# Goal flag
	_add_rect(Rect2(level_end_x, FLOOR_Y - 300, 12, 300), Color.WHITE)
	_add_rect(Rect2(level_end_x + 12, FLOOR_Y - 300, 90, 60), Color(1, 0.85, 0.1))
	_add_world_label("GOAL", Vector2(level_end_x - 100, FLOOR_Y - 360), 40)
	_add_world_label("START", Vector2(START_X - 100, FLOOR_Y - 200), 32)


func _build_station(x: float) -> Dictionary:
	var bands := [
		Rect2(x - PANEL_WIDTH / 2, FLOOR_Y - BAND_LOW, PANEL_WIDTH, BAND_LOW),
		Rect2(x - PANEL_WIDTH / 2, FLOOR_Y - BAND_MID, PANEL_WIDTH, BAND_MID - BAND_LOW),
		Rect2(x - PANEL_WIDTH / 2, FLOOR_Y - GATE_TOP, PANEL_WIDTH, GATE_TOP - BAND_MID),
	]
	var panels: Array = []
	var answer_labels: Array = []
	for b in 3:
		var panel := _add_rect(bands[b], PANEL_COLORS[b])
		var lbl := Label.new()
		lbl.size = bands[b].size
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_style_label(lbl, 26)
		panel.add_child(lbl)
		panels.append(panel)
		answer_labels.append(lbl)
	var sign := _add_world_label("", Vector2(x - 200, FLOOR_Y - GATE_TOP - 60), 34)
	return {"x": x, "problem": null, "resolved": false, "panels": panels,
		"answer_labels": answer_labels, "sign": sign}


func _assign_problem(st: Dictionary, lvl: int) -> void:
	var p := DivisionProblem.make(lvl)
	st["problem"] = p
	st["resolved"] = false
	st["sign"].text = p.question_text()
	for b in 3:
		st["panels"][b].color = PANEL_COLORS[b]
		st["answer_labels"][b].text = p.choices[b]["text"]


func _add_block(rect: Rect2, color: Color, one_way := false) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position + rect.size / 2
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	col.shape = shape
	col.one_way_collision = one_way  # one-way ledges: jump up through them from below
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
	player = PlayerScript.new()
	player.position = Vector2(START_X, FLOOR_Y - 24)
	add_child(player)
	prev_x = player.global_position.x
	var cam := Camera2D.new()
	cam.offset = Vector2(250, -120)  # look ahead so gates come into view early
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
	feedback_label = _hud_label(hud, Vector2(40, 90), 26)
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.size = Vector2(1200, 120)
	stats_label = _hud_label(hud, Vector2(20, 16), 24)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stats_label.size = Vector2(400, 100)
	timer_label = _hud_label(hud, Vector2(860, 16), 36)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.size = Vector2(400, 60)
	var help := _hud_label(hud, Vector2(0, 680), 18)
	help.text = "Move: A/D or arrows    Jump: Space    Restart: R      LOW gate = run   MIDDLE = jump   HIGH = jump off the ledge"
	results_label = _hud_label(hud, Vector2(140, 150), 30)
	results_label.size = Vector2(1000, 500)
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


func _show_feedback(text: String, seconds := 2.5) -> void:
	feedback_label.text = text
	feedback_left = seconds


# ---------------------------------------------------------------- game loop

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if finished:
		return

	_check_gates()

	if not escaping and player.global_position.x >= level_end_x:
		_start_escape()
	elif escaping:
		escape_left -= delta
		if player.global_position.x <= START_X + 50:
			_finish(true)
		elif escape_left <= 0.0:
			_finish(false)

	_update_hud(delta)


func _check_gates() -> void:
	var x: float = player.global_position.x
	for st in stations:
		if st["resolved"]:
			continue
		var sx: float = st["x"]
		var crossed := (prev_x < sx and x >= sx) if not escaping else (prev_x > sx and x <= sx)
		if crossed:
			_resolve(st)
	prev_x = x


func _resolve(st: Dictionary) -> void:
	var feet_height: float = FLOOR_Y - (player.global_position.y + 24.0)
	var band := 0
	if feet_height >= BAND_MID:
		band = 2
	elif feet_height >= BAND_LOW:
		band = 1

	var p: DivisionProblem = st["problem"]
	st["resolved"] = true
	answered += 1
	var old_level := level

	if band == p.correct_index:
		correct += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		score += 100 + 25 * (combo - 1)
		streak_right += 1
		streak_wrong = 0
		st["panels"][band].color = RIGHT_COLOR
		var msg := "Nice!  %s" % p.answer_text()
		if combo >= 3:
			msg += "    COMBO x%d!" % combo
		if not escaping and streak_right >= 3 and level < 3:
			level += 1
			streak_right = 0
			msg += "    LEVEL UP!"
		_show_feedback(msg)
		player.boost()
	else:
		var kind: String = p.choices[band]["kind"]
		mistakes[kind] = mistakes.get(kind, 0) + 1
		combo = 0
		streak_wrong += 1
		streak_right = 0
		st["panels"][band].color = WRONG_COLOR
		st["panels"][p.correct_index].color = RIGHT_COLOR
		_show_feedback(p.hint_for(kind) + "\n" + p.work_text(), 5.0)
		player.stumble()
		if not escaping and streak_wrong >= 2 and level > 1:
			level -= 1
			streak_wrong = 0

	player.set_combo(combo)

	# If difficulty changed, refresh the gates still ahead
	if level != old_level:
		for other in stations:
			if not other["resolved"]:
				_assign_problem(other, level)


func _start_escape() -> void:
	escaping = true
	escape_left = ESCAPE_TIME
	RenderingServer.set_default_clear_color(ESCAPE_SKY)
	for st in stations:
		_assign_problem(st, 0)  # quick problems for speed
	_show_feedback("MATH TIME!  Race back to the START!", 3.0)


func _finish(escaped: bool) -> void:
	finished = true
	player.set_physics_process(false)
	feedback_label.text = ""
	timer_label.text = ""
	problem_label.text = ""

	var accuracy := float(correct) / maxf(answered, 1)
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
	lines.append("Correct: %d / %d    Best combo: x%d" % [correct, answered, best_combo])
	if mistakes.size() > 0:
		lines.append("")
		lines.append("Things to practice:")
		for kind in mistakes:
			lines.append("  %s: %d" % [MISTAKE_NAMES.get(kind, kind), mistakes[kind]])
	lines.append("")
	lines.append("Press R to play again")
	results_label.text = "\n".join(lines)
	results_label.visible = true
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
		f.store_line("date,answered,correct,best_combo,escaped,rank,remainder_too_big,forgot_remainder,off_by_one,wrong_remainder")
	else:
		f.seek_end()
	f.store_line("%s,%d,%d,%d,%s,%s,%d,%d,%d,%d" % [
		Time.get_datetime_string_from_system(), answered, correct, best_combo, str(escaped), rank,
		mistakes.get("remainder_too_big", 0), mistakes.get("forgot_remainder", 0),
		mistakes.get("off_by_one", 0), mistakes.get("wrong_remainder", 0)])
	f.close()


func _update_hud(delta: float) -> void:
	var next = null
	for st in stations:
		if st["resolved"]:
			continue
		if next == null:
			next = st
		elif escaping and st["x"] > next["x"]:
			next = st  # heading left, the nearest gate has the biggest x
	if next != null:
		problem_label.text = next["problem"].question_text()
	else:
		problem_label.text = "RUN BACK TO THE START!" if escaping else "Head for the GOAL!"

	stats_label.text = "Score: %d\nCombo: x%d\nLevel: %d" % [score, combo, level]
	timer_label.text = ("TIME: %d" % ceili(escape_left)) if escaping else ""

	if feedback_left > 0.0:
		feedback_left -= delta
		if feedback_left <= 0.0:
			feedback_label.text = ""
