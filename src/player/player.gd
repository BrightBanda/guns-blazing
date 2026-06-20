extends CharacterBody3D

@onready var state_machine:=$StateMachine
@export_category("Camera Settings")
@export var mouse_sensitivity : float = 0.003
@export var aim_mouse_sensitivity: float = 0.002
@export var default_offset: Vector3 = Vector3(0.5, 0.6, 0.0)
@export var aim_offset: Vector3 = Vector3(0.5, 0.6, 0.0)
@export var default_fov:float = 75.0
@export var aim_fov:float = 55  
@export var zoom_speed:float = 20

@export_category("Recoil")
@export var recoil_up := 0.05
@export var recoil_side := 0.02
@export var aim_recoil_up:float = 0.03
@export var aim_recoil_side:float = 0.005
@export var recoil_snappiness := 20.0
@export var recoil_return := 10.0
@export_range(0.0, 1.0) var recoil_recovery_ratio := 0.7

@onready var recoil_pivot:Node3D = $CamNode/RecoilPivot

var target_recoil_x := 0.0
var target_recoil_y := 0.0

var current_recoil_x := 0.0
var current_recoil_y := 0.0

# Tracks the base offset where the gun is trying to return to
var base_recoil_offset_x := 0.0 
var base_recoil_offset_y := 0.0

@export_category("Damping")
@export var translation_damping: float = 20.0  
@export var rotation_damping: float = 25.0

@onready var cam_node: Node3D = $CamNode
@onready var camera: Camera3D = $Camera3D
@onready var aim_raycast:RayCast3D = $Camera3D/AimRayCast
@onready var camera_target: Node3D = $CamNode/RecoilPivot/SpringArm3D/CameraTarget
@onready var spring_arm: SpringArm3D = $CamNode/RecoilPivot/SpringArm3D

@onready var gun_holder:= $GunHolder
@onready var current_gun:=$GunHolder/Gun
var is_aiming:bool = false

@export_category("dash settings")
var can_dash:bool  = true
@export var dash_cooldown_time:float

@onready var hud:CanvasLayer = $"../HUD"


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cam_node.position = default_offset
	camera.global_transform = camera_target.global_transform
	camera.fov = default_fov
	aim_raycast.target_position = Vector3(0,0,-1000)
	if current_gun:
		current_gun.ammo_changed.connect(hud.on_ammo_changed)
		current_gun.reload_started.connect(hud.on_reload_started)
		current_gun.reload_finished.connect(hud.on_reload_finished)
		
		hud.on_ammo_changed(current_gun.current_clip,current_gun.reserve_ammo)

func _process(delta: float) -> void:
	var is_shooting = Input.is_action_pressed("shoot")
	if is_shooting:
		shoot()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_aiming = Input.is_action_pressed("zoom") 
	
	# Smoothly blend the Camera Rig Position (Offset) and FOV
	var target_offset = aim_offset if is_aiming else default_offset
	var target_fov = aim_fov if is_aiming else default_fov
	
	cam_node.position = cam_node.position.lerp(target_offset, zoom_speed * delta)
	camera.fov = lerp(camera.fov, target_fov, zoom_speed * delta)
	
	# Camera tracking
	var target_distance = cam_node.global_position.distance_to(camera_target.global_position)
	var current_distance = cam_node.global_position.distance_to(camera.global_position)
	
	if target_distance < current_distance:
		camera.global_position = camera_target.global_position
	else:
		camera.global_position = camera.global_position.lerp(
			camera_target.global_position, 
			translation_damping * delta
		)
	
	var current_quat = camera.global_transform.basis.get_rotation_quaternion()
	var target_quat = camera_target.global_transform.basis.get_rotation_quaternion()
	var blended_quat = current_quat.slerp(target_quat, rotation_damping * delta)
	camera.global_transform.basis = Basis(blended_quat)
	
	# --- RECOIL RETURN SYSTEM ---
	target_recoil_x = lerp(target_recoil_x, base_recoil_offset_x, recoil_return * delta)
	target_recoil_y = lerp(target_recoil_y, base_recoil_offset_y, recoil_return * delta)

	# LERP current recoil toward target recoil
	current_recoil_x = lerp(current_recoil_x, target_recoil_x, recoil_snappiness * delta)
	current_recoil_y = lerp(current_recoil_y, target_recoil_y, recoil_snappiness * delta)

	# Apply to the separate recoil pivot node
	recoil_pivot.rotation.x = current_recoil_x
	recoil_pivot.rotation.y = current_recoil_y
	
	#bake cam offset to the recoil recovery unit
	if not is_shooting and abs(current_recoil_x - base_recoil_offset_x) < 0.005:
		if abs(current_recoil_x) > 0.0:
			# Bake the persistent offset permanently into the mouse controller
			cam_node.rotate_x(current_recoil_x)
			rotate_y(current_recoil_y)
			
			# Keep angles clean
			cam_node.rotation.x = clamp(cam_node.rotation.x, deg_to_rad(-55), deg_to_rad(35))
			
			# Clear out the pools completely so it's ready for the next spray
			target_recoil_x = 0.0
			target_recoil_y = 0.0
			current_recoil_x = 0.0
			current_recoil_y = 0.0
			base_recoil_offset_x = 0.0
			base_recoil_offset_y = 0.0
			recoil_pivot.rotation = Vector3.ZERO
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("reload"):
		current_gun.start_reload()
		
	if event.is_action_pressed("dash") and can_dash:
		if state_machine.current_state.name != "Dash":
			state_machine.transition_to("Dash")

# Handle mouse movement
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		var sensitivity = aim_mouse_sensitivity if is_aiming else mouse_sensitivity
		rotate_y(-event.relative.x * sensitivity)
		cam_node.rotate_x(-event.relative.y * sensitivity)
		cam_node.rotation.x = clamp(cam_node.rotation.x, deg_to_rad(-55), deg_to_rad(35))
		

func start_dash_cooldown() -> void:
	await get_tree().create_timer(dash_cooldown_time).timeout
	can_dash = true
		
func shoot():
	aim_raycast.force_raycast_update()
	var aim_point:Vector3
	
	if aim_raycast.is_colliding():
		aim_point = aim_raycast.get_collision_point()
	else:
		var cam_dir = -camera.global_basis.z
		aim_point = camera.global_position + cam_dir * current_gun.fire_range
		
	var muzzle_pos = current_gun.muzzle.global_position
	var shoot_direction = (aim_point - muzzle_pos).normalized()
	
	var did_fire:bool = await current_gun.shoot(shoot_direction)
	if did_fire:
		apply_recoil()
	
func apply_recoil() -> void:
	var current_recoil_up = aim_recoil_up if is_aiming else recoil_up
	var current_recoil_side = aim_recoil_side if is_aiming else aim_recoil_side
	
	target_recoil_x += current_recoil_up
	var random_side = randf_range(-current_recoil_side, current_recoil_side)
	target_recoil_y += random_side
	

	base_recoil_offset_x += current_recoil_up * (1.0 - recoil_recovery_ratio)
	base_recoil_offset_y += random_side * (1.0 - recoil_recovery_ratio)
