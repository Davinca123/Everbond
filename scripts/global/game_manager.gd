# game_manager.gd
extends Node

# Ide kerül majd a játék globális állapota (pl. a pályák mentett állapota, lásd
# docs/map-structure-plan.md 7. pont). Az érkezési pontot már az ajtók adják meg
# (target_map + target_spawn), ezért a régi world_spawn_position kerülő megoldás megszűnt.
