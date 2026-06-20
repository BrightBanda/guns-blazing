class_name PlayerState
extends Node

var player:CharacterBody3D

func enter()-> void:
	pass

func physics_update(delta:float)-> void:
	pass
	
func exit()-> void:
	pass
	
func get_movement_input()-> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
