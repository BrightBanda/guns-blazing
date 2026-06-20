extends StaticBody3D

@export var data:EnemyResource
var current_health: float

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
var flash_tween: Tween 

func _ready() -> void:
	current_health = data.max_health

func take_damage(amount: float) -> void:
	current_health -= amount
	flash_red()
	if current_health <= 0:
		die()

func flash_red() -> void:
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()
		mesh_instance.set_instance_shader_parameter("flash_modifier", 1.0)
	
	flash_tween = create_tween()
	# Tween the instance uniform back to 0.0 (Normal)
	flash_tween.tween_method(
		func(value): mesh_instance.set_instance_shader_parameter("flash_modifier", value),
		1.0, 0.0, 0.2
	)

func die() -> void:
	if flash_tween: flash_tween.kill()
	queue_free()
