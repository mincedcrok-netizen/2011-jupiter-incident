class_name Actor
extends CharacterBody3D
## Base class for anything that acts in the world (players now, enemies later).
## `peer_id` is the peer that CONTROLS this actor; authority over shared world
## state stays with the host regardless (see docs/ARCHITECTURE.md).

@export var actor_id: StringName = &""
@export var peer_id: int = 1


func is_locally_controlled() -> bool:
	return peer_id == Net.local_peer_id()
