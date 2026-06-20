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

@export_category("Damping")
@export var translation_damping: float = 20.0  # Increased slightly for snappier catch-up near ground
@export var rotation_damping: float = 25.0

@onready var cam_node: Node3D = $CamNode
@onready var camera: Camera3D = $Camera3D
@onready var aim_raycast:RayCast3D = $Camera3D/AimRayCast
@onready var camera_target: Node3D = $CamNode/SpringArm3D/CameraTarget
@onready var spring_arm: SpringArm3D = $CamNode/SpringArm3D

@onready var gun_holder:= $GunHolder
@onready var current_gun:=$GunHolder/Gun
var is_aiming:bool = false

@export_category("dash settings")
var can_dash:bool  = true
@export var dash_cooldown_time:float

@onready var hud:CanvasLayer = $"../HUD"


func _ready():
	Input.mouse_mode =Input.MOUSE_MODE_CAPTURED
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
	if Input.is_action_pressed("shoot"):
		shoot()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	is_aiming = Input.is_action_pressed("zoom") 
	
	# 4. Smoothly blend the Camera Rig Position (Offset) and FOV
	var target_offset = aim_offset if is_aiming else default_offset
	var target_fov = aim_fov if is_aiming else default_fov
	
	cam_node.position = cam_node.position.lerp(target_offset, zoom_speed * delta)
	camera.fov = lerp(camera.fov, target_fov, zoom_speed * delta)
	
	#camera tracking
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
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Input.is_action_just_pressed("reload"):
		current_gun.start_reload()
		
	if event.is_action_pressed("dash") and can_dash:
		# Check to ensure they aren't already dashing before forcing a state swap
		#if state_machine.current_state.name != "Dash":
		state_machine.transition_to("Dash")
		
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Rotate character horizontally, pivot vertically
		if not is_aiming:
			rotate_y(-event.relative.x * mouse_sensitivity)
			cam_node.rotate_x(-event.relative.y * mouse_sensitivity)
		else :
			rotate_y(-event.relative.x * aim_mouse_sensitivity)
			cam_node.rotate_x(-event.relative.y * aim_mouse_sensitivity)
		cam_node.rotation.x = clamp(cam_node.rotation.x, deg_to_rad(-55), deg_to_rad(35))
		

# Asynchronous function to reset dash eligibility outside of the state execution loop
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
	current_gun.shoot(shoot_direction)
