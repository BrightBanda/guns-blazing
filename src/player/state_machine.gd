class_name StateMachine
extends Node

@export var initial_state: PlayerState
var current_state: PlayerState
var states: Dictionary = {}

func _ready() -> void:
	# Wait for the parent (Player) to be ready so states can reference it
	await owner.ready
	
	for child in get_children():
		var state:= child as PlayerState
		if child is PlayerState:
			if state:
				states[child.name.to_lower()] = state
				state.player = owner as CharacterBody3D
	
	if initial_state:
		current_state = initial_state
		current_state.enter()

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


# Call this from inside a state to switch to another
func transition_to(new_state_name: String) -> void:
	var target_state = states.get(new_state_name.to_lower())
	if not target_state:
		return
		
	if current_state:
		current_state.exit()
		
	current_state = target_state
	current_state.enter()
