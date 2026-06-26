extends PlayerState

@export var jump_height : float = 2.25
@export var jump_time_to_peak : float = 0.4
@export var jump_time_to_descent : float = 0.3

# Air control parameters for strafe adjustment mid-air
@export var air_control_speed: float = 5.0
@export var air_acceleration: float = 15.0

@onready var jump_velocity : float = ((2.0 * jump_height) / jump_time_to_peak)
@onready var jump_gravity : float = ((2.0 * jump_height) / (jump_time_to_peak * jump_time_to_peak))
@onready var fall_gravity : float = ((2.0 * jump_height) / (jump_time_to_descent * jump_time_to_descent))

func enter() -> void:
	player.velocity.y = jump_velocity
	player.play_anim("jumping_up")
	

func physics_update(delta: float) -> void:
	var gravity = jump_gravity if player.velocity.y > 0.0 else fall_gravity
	player.velocity.y -= gravity * delta
	
	if player.velocity.y < 0:
		player.play_anim("falling")

	var input_dir := get_movement_input()
	var direction := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction != Vector3.ZERO:
		player.velocity.x = move_toward(player.velocity.x, direction.x * air_control_speed, air_acceleration * delta)
		player.velocity.z = move_toward(player.velocity.z, direction.z * air_control_speed, air_acceleration * delta)
	else:
		# Slight air resistance
		player.velocity.x = move_toward(player.velocity.x, 0.0, air_acceleration * 0.5 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, air_acceleration * 0.5 * delta)

	player.move_and_slide()

	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.play_anim("landing")
		if input_dir != Vector2.ZERO:
			get_parent().transition_to("move") 
		else:
			get_parent().transition_to("idle")
