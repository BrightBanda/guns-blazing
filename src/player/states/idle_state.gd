extends PlayerState

@export var friction: float = 25.0
func enter() -> void:
	pass

func physics_update(delta: float) -> void:
	var input_dir := get_movement_input()
	
	if player.is_on_floor() and Input.is_action_just_pressed("jump"):
		get_parent().transition_to("jump")
		return
	
	if input_dir != Vector2.ZERO:
		get_parent().transition_to("move") 
		return

	player.velocity.x = move_toward(player.velocity.x, 0.0, friction * delta)
	player.velocity.z = move_toward(player.velocity.z, 0.0, friction * delta)

	if not player.is_on_floor():
		player.velocity.y += player.get_gravity().y * delta
		
		
	player.move_and_slide()
