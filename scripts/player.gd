extends CharacterBody2D
## The runner. Pizza Tower-style momentum: the bigger your combo, the faster you can go.
## Attack: tap to slash (also chops trees and mines ore), hold and let go to throw a dagger.

signal slashed(facing: int)
signal threw(facing: int)

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
const HOLD_TO_THROW := 0.25 # Hold attack this long, then let go, to throw
const ATTACK_COOLDOWN := 0.25

const BASE_COLOR := Color(1.0, 0.55, 0.1)
const MACH_COLOR := Color(1.0, 0.15, 0.45)

# Set by the stage for each environment (moon gravity, slippery ice...)
var gravity_scale := 1.0
var friction_scale := 1.0
var accel_scale := 1.0

var max_speed := BASE_MAX_SPEED
var coyote_left := 0.0
var buffer_left := 0.0
var facing := 1
var holding := false
var hold_time := 0.0
var attack_cd := 0.0
var blink_left := 0.0
var body_rect: ColorRect
var eye_rect: ColorRect
var slash_fx: Polygon2D


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

	slash_fx = Polygon2D.new()
	slash_fx.polygon = PackedVector2Array([Vector2(10, -34), Vector2(60, -20), Vector2(78, 0), Vector2(60, 20), Vector2(10, 30), Vector2(40, 0)])
	slash_fx.color = Color(1, 1, 1, 0.75)
	slash_fx.visible = false
	add_child(slash_fx)


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")

	if is_on_floor():
		coyote_left = COYOTE_TIME
	else:
		velocity.y += GRAVITY * gravity_scale * delta
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

	var accel := (GROUND_ACCEL if is_on_floor() else AIR_ACCEL) * accel_scale
	if dir != 0.0:
		if velocity.x != 0.0 and signf(dir) != signf(velocity.x):
			accel *= 2.0  # snappy turnarounds
		velocity.x = move_toward(velocity.x, dir * max_speed, accel * delta)
		facing = 1 if dir > 0.0 else -1
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * friction_scale * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * 0.3 * delta)

	move_and_slide()
	_handle_attack(delta)

	eye_rect.position = Vector2(4, -16) if facing > 0 else Vector2(-12, -16)
	eye_rect.color = Color(1, 0.9, 0.2) if holding and hold_time >= HOLD_TO_THROW else Color.WHITE
	var t := clampf((absf(velocity.x) - BASE_MAX_SPEED) / 250.0, 0.0, 1.0)
	body_rect.color = BASE_COLOR.lerp(MACH_COLOR, t)

	if blink_left > 0.0:
		blink_left -= delta
		visible = int(blink_left * 16.0) % 2 == 0 or blink_left <= 0.0


func _handle_attack(delta: float) -> void:
	attack_cd -= delta
	if Input.is_action_just_pressed("attack"):
		holding = true
		hold_time = 0.0
	if holding:
		hold_time += delta
		if Input.is_action_just_released("attack"):
			holding = false
			if attack_cd <= 0.0:
				attack_cd = ATTACK_COOLDOWN
				if hold_time >= HOLD_TO_THROW:
					threw.emit(facing)
				else:
					do_slash()
	if Input.is_action_just_pressed("throw") and attack_cd <= 0.0:
		attack_cd = ATTACK_COOLDOWN
		threw.emit(facing)


func do_slash() -> void:
	slash_fx.scale.x = facing
	slash_fx.visible = true
	get_tree().create_timer(0.1).timeout.connect(_hide_slash)
	slashed.emit(facing)


func _hide_slash() -> void:
	slash_fx.visible = false


func set_combo(combo: int) -> void:
	max_speed = BASE_MAX_SPEED + mini(combo, MAX_COMBO_BONUS) * SPEED_PER_COMBO


## Right answer: a burst of speed.
func boost() -> void:
	velocity.x += facing * 220.0


## Flash after getting hurt.
func blink(seconds: float) -> void:
	blink_left = seconds
