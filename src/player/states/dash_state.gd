extends PlayerState

@export_category("Jetpack Dash Tuning")
@export var dash_speed: float = 30.0
@export var dash_distance: float = 6.0

# How much of the dash should be used for slowing down.
# 0.0 = instant stop
# 0.5 = last 50% of the dash slows down
@export_range(0.0, 1.0)
var slowdown_percent: float = 0.3

@export var gravity: float = 25.0

var dash_direction: Vector3 = Vector3.ZERO
var start_position: Vector3

@onready var state_machine = get_parent()

func enter() -> void:
	player.can_dash = false
	start_position = player.global_position

	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_backward",
		"move_forward"
	)

	var forward_vector :Vector3= -player.cam_node.global_transform.basis.z
	var right_vector :Vector3= player.cam_node.global_transform.basis.x

	forward_vector.y = 0
	right_vector.y = 0

	forward_vector = forward_vector.normalized()
	right_vector = right_vector.normalized()

	if input_dir.length() > 0:
		dash_direction = (
			right_vector * input_dir.x +
			forward_vector * input_dir.y
		).normalized()
	else:
		dash_direction = forward_vector


func physics_update(delta: float) -> void:
	var traveled_distance = start_position.distance_to(player.global_position)

	if traveled_distance >= dash_distance:
		var input_dir := Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward"
		)

		if input_dir.length() > 0:
			state_machine.transition_to("move")
		else:
			state_machine.transition_to("idle")

		return

	# --------- DASH SLOWDOWN ---------

	var speed_multiplier := 1.0

	if slowdown_percent > 0.0:
		var slowdown_start = dash_distance * (1.0 - slowdown_percent)

		if traveled_distance > slowdown_start:
			var slowdown_progress = inverse_lerp(
				slowdown_start,
				dash_distance,
				traveled_distance
			)

			speed_multiplier = 1.0 - slowdown_progress

			# Prevent complete stop before transition
			speed_multiplier = max(speed_multiplier, 0.1)

	# Horizontal dash velocity
	player.velocity.x = dash_direction.x * dash_speed * speed_multiplier
	player.velocity.z = dash_direction.z * dash_speed * speed_multiplier

	# Gravity still works
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	player.move_and_slide()


func exit() -> void:
	player.velocity.x = 0.0
	player.velocity.z = 0.0

	player.start_dash_cooldown()
