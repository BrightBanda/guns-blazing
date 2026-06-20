extends RigidBody3D

@export var speed:float = 15.0


func _ready() -> void:
	linear_velocity = Vector3.ZERO
	
func _physics_process(delta: float) -> void:
	if linear_velocity.length() > 0.1:
		look_at(global_position + linear_velocity,Vector3.UP)

func _process(delta: float) -> void:
	position += Vector3(0,0,speed) * delta
