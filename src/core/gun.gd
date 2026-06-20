extends Node3D

# Changed parameter name to 'current_clip' to accurately reflect the system structure
signal ammo_changed(current_clip: int, reserve_ammo: int)
signal reload_started
signal reload_finished

@export_category("Weapon stats")
@export var data: WeaponResource
var damage: float
var fire_rate: float
var fire_range: float
var reload_speed: float
var max_ammo: float
var clip_size: int
var reserve_ammo: int

var current_clip: int
var can_shoot: bool = true
var is_reloading: bool = false

@onready var raycast: RayCast3D = $ShootRaycast
@onready var muzzle: Marker3D = $Muzzle
@onready var muzzle_flash_mesh: MeshInstance3D = $Muzzle/MuzzleFlashMesh


func _ready() -> void:
	damage = data.damage
	fire_rate = data.fire_rate
	fire_range = data.range
	reload_speed = data.reload_speed
	clip_size = data.clip_size
	reserve_ammo = data.max_reserve
	
	current_clip = clip_size
	ammo_changed.emit(current_clip, reserve_ammo)


func shoot(aim_direction: Vector3) -> bool:
	if not can_shoot or is_reloading or current_clip <= 0:
		if current_clip <= 0 and reserve_ammo > 0 and not is_reloading:
			start_reload()
		return false
		
	current_clip -= 1
	ammo_changed.emit(current_clip, reserve_ammo)
	
	raycast.global_position = muzzle.global_position
	_trigger_muzzle_flash()
	AudioManager.play_sfx(data.gun_sound)
	
	var global_target_point = muzzle.global_position + (aim_direction * fire_range)
	raycast.target_position = raycast.to_local(global_target_point)
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var hit_point = raycast.get_collision_point()
		var hit_object = raycast.get_collider()
		
		if hit_object.has_method("take_damage"):
			hit_object.take_damage(damage)
			
	can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	if not is_reloading:
		can_shoot = true
	return true


func _trigger_muzzle_flash():
	var material = muzzle_flash_mesh.get_active_material(0) as ShaderMaterial
	if material:
		material.set_shader_parameter("seed", randf())
		material.set_shader_parameter("flash_intensity", 5.0)
		var tween = create_tween()
		
		material.set_shader_parameter("flash_intensity", 10.0)
		tween.tween_property(material, "shader_parameter/flash_intensity", 0.0, 0.05)


func start_reload() -> void:
	if is_reloading or current_clip == clip_size or reserve_ammo <= 0:
		return
		
	is_reloading = true
	can_shoot = false
	reload_started.emit()
	
	await get_tree().create_timer(reload_speed).timeout
	
	var bullets_needed: int = clip_size - current_clip

	if reserve_ammo >= bullets_needed:
		# Scenario A: You have enough reserve ammo to completely fill the clip
		reserve_ammo -= bullets_needed
		current_clip = clip_size
	else:
		# Scenario B: You have some reserve ammo left, but not enough for a full clip
		current_clip += reserve_ammo
		reserve_ammo = 0 
		
	is_reloading = false
	can_shoot = true
	reload_finished.emit()
	ammo_changed.emit(current_clip, reserve_ammo)
