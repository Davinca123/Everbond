# game_manager.gd
extends Node

# A játék globális állapota. Az érkezési pontot már az ajtók adják meg
# (target_map + target_spawn), ezért a régi world_spawn_position kerülő megoldás megszűnt.

# A pályák mentett állapota (docs/map-structure-plan.md, "Saving map state"):
# map_id -> { a csomópont útja a pálya gyökerétől -> a csomópont save_state()-je }.
# Csak a memóriában él, a játék bezárásakor elveszik.
var map_state: Dictionary = {}
