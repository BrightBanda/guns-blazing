extends PlayerState

@export var move_speed: float = 8.0
@export var acceleration: float = 60.0    
@export var deceleration: float = 50.0

func physics_update(delta: float) -> void:
	
	#check if is jump pressed 
	if player.is_on_floor() and Input.is_action_just_pressed("jump"):
		get_parent().transition_to("jump")
		return
	
	var input_dir: Vector2 = get_movement_input()
	
		#stop movement slowly
	if input_dir == Vector2.ZERO and player.velocity.slide(Vector3.UP).length() < 0.1:
		get_parent().transition_to("idle")
		return

	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var current_accel = acceleration if input_dir != Vector2.ZERO else deceleration
	
	player.velocity.x = move_toward(player.velocity.x, direction.x * move_speed, current_accel * delta)
	player.velocity.z = move_toward(player.velocity.z, direction.z * move_speed, current_accel * delta)


	if not player.is_on_floor():
		player.velocity.y += player.get_gravity().y * delta
	else:
		# Keep the player snapped firmly to the floor while running down slopes
		if player.velocity.y < 0:
			player.velocity.y = 0
			
	player.move_and_slide()
