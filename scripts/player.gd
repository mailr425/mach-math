extends CharacterBody2D
## The runner. Pizza Tower-style momentum: the bigger your combo, the faster you can go.

const GRAVITY := 1800.0
const JUMP_VELOCITY := -720.0
const GROUND_ACCEL := 1500.0
const AIR_ACCEL := 1000.0
const FRICTION := 2200.0
const BASE_MAX_SPEED := 460.0
const SPEED_PER_COMBO := 35.0
const MAX_COMBO_BONUS := 8
const COYOTE_TIME := 0.1    # Can still jump just after running off a ledge
const JUMP_BUFFER := 0.12   # Jump pressed just before landing still counts

const BASE_COLOR := Color(1.0, 0.55, 0.1)
const MACH_COLOR := Color(1.0, 0.15, 0.45)

var max_speed := BASE_MAX_SPEED
var coyote_left := 0.0
var buffer_left := 0.0
var facing := 1
var body_rect: ColorRect
var eye_rect: ColorRect


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(32, 48)
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# Placeholder art: an orange block with an eye. Swap for real sprites later.
	body_rect = ColorRect.new()
	body_rect.size = Vector2(32, 48)
	body_rect.position = Vector2(-16, -24)
	body_rect.color = BASE_COLOR
	add_child(body_rect)
	eye_rect = ColorRect.new()
	eye_rect.size = Vector2(8, 8)
	eye_rect.color = Color.WHITE
	add_child(eye_rect)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if is_on_floor():
		coyote_left = COYOTE_TIME
	else:
		velocity.y += GRAVITY * delta
		coyote_left -= delta

	buffer_left -= delta
	if Input.is_action_just_pressed("jump"):
		buffer_left = JUMP_BUFFER
	if buffer_left > 0.0 and coyote_left > 0.0:
		velocity.y = JUMP_VELOCITY
		buffer_left = 0.0
		coyote_left = 0.0
	# Let go of jump early for a short hop
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	if dir != 0.0:
		if velocity.x != 0.0 and signf(dir) != signf(velocity.x):
			accel *= 2.0  # snappy turnarounds
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
		facing = 1 if dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()

	eye_rect.position = Vector2(4, -16) if facing > 0 else Vector2(-12, -16)
	var t := clampf((absf(velocity.x) - BASE_MAX_SPEED) / 250.0, 0.0, 1.0)
	body_rect.color = BASE_COLOR.lerp(MACH_COLOR, t)


func set_combo(combo: int) -> void:
	max_speed = BASE_MAX_SPEED + mini(combo, MAX_COMBO_BONUS) * SPEED_PER_COMBO


## Right answer: a burst of speed.
func boost() -> void:
	velocity.x += facing * 220.0


## Wrong answer: lose speed, but never lose a life.
func stumble() -> void:
	velocity.x *= 0.3
