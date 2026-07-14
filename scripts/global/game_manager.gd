# game_manager.gd
extends Node

# Ez a változó fogja megjegyezni, hogy a külső világban hol álltunk,
# mielőtt bementünk egy házba.
var world_spawn_position: Vector2 = Vector2.ZERO

# Ez jelzi, hogy épp egy házból jövünk-e vissza
var coming_back_from_interior: bool = false
