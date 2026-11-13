extends CharacterBody3D

const HAND_IK_RIG := preload("res://src/player/hand_ik_rig.tscn")

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

@onready var state_machine:=$StateMachine
@onready var cam_node: Node3D = $CamNode
@onready var camera: Camera3D = $Camera3D
@onready var aim_raycast:RayCast3D = $Camera3D/AimRayCast
@onready var camera_target: Node3D = $CamNode/RecoilPivot/SpringArm3D/CameraTarget
@onready var spring_arm: SpringArm3D = $CamNode/RecoilPivot/SpringArm3D

@onready var animation_tree: AnimationTree = $composition12/AnimationTree
@onready var anim_playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/LocomotionSM/playback")

@onready var gun_holder:= $GunHolder
@onready var skeleton: Skeleton3D = $composition12/metarig/Skeleton3D

signal weapon_changed(weapon: Node3D)

@export_category("Weapons")
## Weapons the player cycles through with next_weapon(). Leave empty to keep
## whatever weapon the scene was authored with.
@export var weapon_loadout: Array[PackedScene] = []
## Parent for equipped weapons. Weapons recoil by rotating this node.
## Defaults to GunHolder/WeaponRecoilPivot.
@export var weapon_mount: Node3D
## Skeleton bone the weapon mount rides on, so the gun bobs and sways with the
## body animation and the IK'd hands follow it. The chest keeps the gun steady
## for aiming; use "hand.R" to let the arm animation carry it instead. Leave
## empty to keep the mount fixed to the body.
@export var weapon_bone: StringName = &"spine.003"
## When on, each equipped weapon is slid so its right grip sits in the animated
## right palm. The animator's holding pose is kept and the IK only has to make
## small corrections, instead of dragging the arms to wherever the gun was
## placed in the editor. Only the position moves; the authored aim is kept.
@export var snap_weapon_to_hand := true
@export var hand_bone: StringName = &"hand.R"

var current_weapon: Node3D
var hand_ik: HandIK
var _loadout_index := -1
## The mount's authored aim, in player space. Re-applied once the skeleton
## is animated so the chest's animated tilt does not leak into the barrel.
var _authored_mount_basis := Basis.IDENTITY
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

	hand_ik = _install_hand_ik()
	if weapon_mount == null:
		weapon_mount = $GunHolder/WeaponRecoilPivot
	_authored_mount_basis = global_basis.inverse() * weapon_mount.global_basis
	_attach_mount_to_bone()
	_adopt_authored_weapon()
	_take_weapon(current_weapon)


## Builds the HandIK rig under the skeleton. Idempotent, so the rig can also be
## placed in the scene by hand - a SkeletonModifier only joins the stack as a
## direct child of the Skeleton3D.
func _install_hand_ik() -> HandIK:
	var existing := skeleton.get_node_or_null(^"HandIK") as HandIK
	if existing != null:
		return existing
	var rig := HAND_IK_RIG.instantiate() as HandIK
	skeleton.add_child(rig)
	return rig


## Hangs the weapon mount off `weapon_bone` through a BoneAttachment3D. The
## mount keeps its authored world placement, which becomes its offset from the
## bone, so the gun stays where it was placed in the editor and then moves
## with the animated body from there.
func _attach_mount_to_bone() -> void:
	if weapon_bone.is_empty():
		return
	var bone := skeleton.find_bone(weapon_bone)
	if bone < 0:
		push_warning("Player: bone '%s' not found, weapon mount stays fixed to the body." % weapon_bone)
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "WeaponBone"
	attachment.bone_name = weapon_bone
	skeleton.add_child(attachment)
	# BoneAttachment3D snaps to its bone on the next skeleton update, so place
	# it on the current pose now or the reparent below would bake a stale offset.
	attachment.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	weapon_mount.reparent(attachment, true)


## The authored weapon is a sibling of the mount so it stays visible in the
## editor. Move it under the mount at runtime so the mount can rotate it.
func _adopt_authored_weapon() -> void:
	var authored := get_node_or_null(^"GunHolder/Gun") as Node3D
	if authored == null:
		return
	authored.reparent(weapon_mount, true)
	authored.position = Vector3.ZERO
	authored.rotation = Vector3.ZERO
	current_weapon = authored


## Swaps in a weapon from a scene file. The hands follow via the new weapon's
## own grip sockets, so different weapons need no player-side changes.
func equip_weapon(scene: PackedScene) -> void:
	if scene == null:
		unequip_weapon()
		return
	var weapon := scene.instantiate() as Node3D
	if weapon == null:
		push_error("equip_weapon: '%s' has no Node3D root." % scene.resource_path)
		return
	weapon.name = scene.resource_path.get_file().get_basename()
	weapon_mount.add_child(weapon)
	_take_weapon(weapon)


func unequip_weapon() -> void:
	_drop_weapon()
	hand_ik.unbind()
	hand_ik.active = false


## Cycles the weapon_loadout. Wraps around.
func next_weapon() -> void:
	if weapon_loadout.is_empty():
		return
	_loadout_index = (_loadout_index + 1) % weapon_loadout.size()
	equip_weapon(weapon_loadout[_loadout_index])


func _take_weapon(weapon: Node3D) -> void:
	if current_weapon != null and current_weapon != weapon:
		_drop_weapon()
	current_weapon = weapon

	if weapon.has_signal(&"ammo_changed"):
		weapon.ammo_changed.connect(hud.on_ammo_changed)
	if weapon.has_signal(&"reload_started"):
		weapon.reload_started.connect(hud.on_reload_started)
	if weapon.has_signal(&"reload_finished"):
		weapon.reload_finished.connect(hud.on_reload_finished)
	_bind_hands(weapon)

	if "current_clip" in weapon:
		hud.on_ammo_changed(weapon.current_clip, weapon.reserve_ammo)
	weapon_changed.emit(weapon)


## Plants the hands on `weapon`, after first settling the mount on the
## animated body and snapping the weapon into the palm.
func _bind_hands(weapon: Node3D) -> void:
	hand_ik.unbind()
	# One frame with the IK off, so the skeleton holds the pure animation
	# pose and the palm position is the animator's, not last frame's IK.
	await get_tree().process_frame
	if not is_instance_valid(weapon) or current_weapon != weapon:
		return
	_settle_mount(weapon)
	hand_ik.bind(weapon)


## Restores the authored aim on the now-animated chest, then slides the mount
## so the weapon's right grip lands on `hand_bone`.
func _settle_mount(weapon: Node3D) -> void:
	weapon_mount.global_basis = global_basis * _authored_mount_basis
	if not snap_weapon_to_hand:
		return
	var bone := skeleton.find_bone(hand_bone)
	if bone < 0:
		push_warning("Player: bone '%s' not found, weapon stays where it was authored." % hand_bone)
		return
	var grip := hand_ik.find_grip_sockets(weapon)[HandIK.RIGHT]
	if grip == null:
		return
	var palm := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	weapon_mount.global_position += palm.origin - grip.global_position


func _drop_weapon() -> void:
	if current_weapon == null:
		return
	if hand_ik != null and hand_ik.is_bound_to(current_weapon):
		hand_ik.unbind()
	for signal_name in [&"ammo_changed", &"reload_started", &"reload_finished"]:
		var weapon_signal := Signal(current_weapon, signal_name)
		if weapon_signal.is_connected(_hud_handler(signal_name)):
			weapon_signal.disconnect(_hud_handler(signal_name))
	current_weapon.queue_free()
	current_weapon = null


func _hud_handler(signal_name: StringName) -> Callable:
	match signal_name:
		&"ammo_changed":
			return hud.on_ammo_changed
		&"reload_started":
			return hud.on_reload_started
		_:
			return hud.on_reload_finished


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
	if Input.is_action_just_pressed("reload") and current_weapon != null:
		current_weapon.start_reload()
		
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
	if current_weapon == null:
		return
	aim_raycast.force_raycast_update()
	var aim_point:Vector3
	
	if aim_raycast.is_colliding():
		aim_point = aim_raycast.get_collision_point()
	else:
		var cam_dir = -camera.global_basis.z
		aim_point = camera.global_position + cam_dir * current_weapon.fire_range
		
	var muzzle_pos = current_weapon.muzzle.global_position
	var shoot_direction = (aim_point - muzzle_pos).normalized()
	
	var did_fire:bool = await current_weapon.shoot(shoot_direction)
	if did_fire:
		apply_recoil()
	
func apply_recoil() -> void:
	var current_recoil_up = aim_recoil_up if is_aiming else recoil_up
	var current_recoil_side = aim_recoil_side if is_aiming else recoil_side
	
	target_recoil_x += current_recoil_up
	var random_side = randf_range(-current_recoil_side, current_recoil_side)
	target_recoil_y += random_side
	

	base_recoil_offset_x += current_recoil_up * (1.0 - recoil_recovery_ratio)
	base_recoil_offset_y += random_side * (1.0 - recoil_recovery_ratio)

var current_anim=""
func play_anim(anim_name:String)-> void:
	if anim_name == current_anim:
		return
	current_anim = anim_name
	anim_playback.travel(anim_name)
