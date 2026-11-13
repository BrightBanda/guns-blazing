class_name HandIK
extends TwoBoneIK3D

## Plants both hands on a weapon's grip sockets with two-bone IK.
##
## Must be a direct child of the Skeleton3D: Godot collects SkeletonModifiers
## from direct children only. Add Target_Right / Target_Left as children of this
## node - they are reparented onto the weapon's grips on bind, so they track the
## weapon without any per-frame copying.
##
## A weapon opts in by exposing Grip_Right / Grip_Left markers, or by
## implementing get_grip_sockets() (see gun.gd). A hand whose socket is missing
## gets its target pinned to the animated bone pose, which makes the IK a no-op
## for that arm - that is how one-handed weapons work.

signal bound(weapon: Node3D)
signal released(weapon: Node3D)

const RIGHT := 0
const LEFT := 1

@export_category("Bones")
@export var right_bones: PackedStringArray = ["upper_arm.R", "forearm.R", "hand.R"]
@export var left_bones: PackedStringArray = ["upper_arm.L", "forearm.L", "hand.L"]

@export_category("Grip sockets")
@export var right_socket_names: PackedStringArray = ["Grip_Right"]
@export var left_socket_names: PackedStringArray = ["Grip_Left"]

@export_category("Elbow poles")
@export var right_pole: NodePath
@export var left_pole: NodePath

@export_category("Blending")
## Seconds the hands take to travel to a newly equipped weapon's grips.
@export var blend_time := 0.15

@onready var target_right: Node3D = $Target_Right
@onready var target_left: Node3D = $Target_Left

var _weapon: Node3D
var _sockets: Array[Node3D] = [null, null]
var _blend_from: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
var _blend_t := 1.0


func _ready() -> void:
	_configure()
	set_process(false)


## Points both arms at `weapon`. Pass null to let the arms fall back to animation.
func bind(weapon: Node3D) -> void:
	_release_targets()

	var sockets := _resolve_grips(weapon)
	if sockets[RIGHT] == null and sockets[LEFT] == null:
		_weapon = null
		active = false
		set_process(false)
		if weapon != null:
			push_warning("HandIK: '%s' exposes no grip sockets, arms left to animation." % weapon.name)
		return

	_weapon = weapon
	_sockets = sockets
	active = true

	for i in 2:
		var target := _target(i)
		var socket := _sockets[i]
		if socket == null:
			continue
		if target.get_parent() == self:
			# Never bound before: start the blend from the animated hand, not
			# from the rig origin at the feet.
			_pin_to_bone(i, target)
		_blend_from[i] = target.global_transform
		target.reparent(socket, true)
		# Reparenting invalidates the NodePath stored by TwoBoneIK3D, so
		# re-resolve it against the new parent or the IK silently no-ops.
		set_target_node(i, get_path_to(target))

	_blend_t = 0.0
	set_process(true)
	bound.emit(weapon)


## Detaches the hands from the current weapon. Must run before the weapon is
## freed, otherwise the reparented targets would be freed with it.
func unbind() -> void:
	var had_weapon := _weapon != null
	_release_targets()
	_weapon = null
	_sockets = [null, null]
	_blend_t = 1.0
	active = false
	set_process(false)
	if had_weapon:
		released.emit(null)


func is_bound_to(weapon: Node3D) -> bool:
	return weapon != null and _weapon == weapon


func _process(delta: float) -> void:
	if _blend_t < 1.0:
		_blend_t = minf(1.0, _blend_t + delta / maxf(blend_time, 0.001))

	var weight := _blend_t * _blend_t * (3.0 - 2.0 * _blend_t)
	var needs_pin := false

	for i in 2:
		var target := _target(i)
		var socket := _sockets[i]
		if socket == null or not is_instance_valid(socket):
			_pin_to_bone(i, target)
			needs_pin = true
			continue
		if _blend_t < 1.0:
			target.global_transform = _blend_from[i].interpolate_with(socket.global_transform, weight)

	if not needs_pin and _blend_t >= 1.0:
		set_process(false)


func _configure() -> void:
	setting_count = 2
	for i in 2:
		set_target_node(i, get_path_to(_target(i)))
		_configure_chain(i, right_bones if i == RIGHT else left_bones)

	var right_pole_node := get_node_or_null(right_pole) if right_pole else $Pole_Right
	if right_pole_node != null:
		set_pole_node(RIGHT, get_path_to(right_pole_node))
	var left_pole_node := get_node_or_null(left_pole) if left_pole else $Pole_Left
	if left_pole_node != null:
		set_pole_node(LEFT, get_path_to(left_pole_node))


func _configure_chain(index: int, bones: PackedStringArray) -> void:
	if bones.size() < 3:
		push_error("HandIK: bone chain needs root, middle and end bone names.")
		return
	set_root_bone_name(index, bones[0])
	set_middle_bone_name(index, bones[1])
	set_end_bone_name(index, bones[2])


## Moves the targets back under this node so they outlive the weapon.
func _release_targets() -> void:
	for i in 2:
		var target := _target(i)
		if target.get_parent() != self:
			target.reparent(self, true)
			set_target_node(i, get_path_to(target))


## Holds a socket-less hand at its animated pose, which makes that IK chain a no-op.
func _pin_to_bone(index: int, target: Node3D) -> void:
	var skeleton := get_parent() as Skeleton3D
	if skeleton == null:
		return
	var bones := right_bones if index == RIGHT else left_bones
	if bones.size() < 3:
		return
	var bone := skeleton.find_bone(bones[2])
	if bone < 0:
		return
	target.global_transform = skeleton.global_transform * skeleton.get_bone_global_pose(bone)


## Grip sockets `weapon` exposes, [right, left]; null where it has none.
func find_grip_sockets(weapon: Node3D) -> Array[Node3D]:
	return _resolve_grips(weapon)


func _resolve_grips(weapon: Node3D) -> Array[Node3D]:
	var grips: Array[Node3D] = [null, null]
	if weapon == null:
		return grips
	if weapon.has_method(&"get_grip_sockets"):
		var from_weapon: Array = weapon.call(&"get_grip_sockets")
		if from_weapon.size() >= 2:
			grips[RIGHT] = from_weapon[RIGHT] as Node3D
			grips[LEFT] = from_weapon[LEFT] as Node3D
			# A weapon that only implements one grip still gets the name fallback.
			if grips[RIGHT] != null or grips[LEFT] != null:
				return grips
	grips[RIGHT] = _find_grip(weapon, right_socket_names)
	grips[LEFT] = _find_grip(weapon, left_socket_names)
	return grips


func _find_grip(root: Node, names: PackedStringArray) -> Node3D:
	for socket_name in names:
		var direct := root.get_node_or_null(NodePath(socket_name))
		if direct is Node3D:
			return direct
		var nested := root.find_child(socket_name, true, false)
		if nested is Node3D:
			return nested
	return null


func _target(index: int) -> Node3D:
	return target_right if index == RIGHT else target_left
