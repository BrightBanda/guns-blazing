# base_enemy.gd
class_name BaseEnemy
extends StaticBody3D

@export var data: EnemyResource
var current_health: float
var flash_tween: Tween 


@export var mesh_instance: MeshInstance3D

func _ready() -> void:
	current_health = data.max_health
	if not mesh_instance:
		mesh_instance = get_node_or_null("MeshInstance3D")

func take_damage(amount: float) -> void:
	current_health -= amount
	flash_red()
	if current_health <= 0:
		die()

func flash_red() -> void:
	if not mesh_instance: return
	
	if flash_tween and flash_tween.is_running():
		flash_tween.kill()
		mesh_instance.set_instance_shader_parameter("flash_modifier", 1.0)
	
	flash_tween = create_tween()
	flash_tween.tween_method(
		func(value): mesh_instance.set_instance_shader_parameter("flash_modifier", value),
		1.0, 0.0, 0.2
	)

func die() -> void:
	if flash_tween: flash_tween.kill()
	queue_free()
