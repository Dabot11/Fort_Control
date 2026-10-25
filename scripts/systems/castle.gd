class_name FortCastle
extends Node
## Health is independent of the castle's replaceable map geometry.

signal health_changed(health: int)
signal destroyed

var health: int = 20
var max_health: int = 20


func reset(initial_health: int) -> void:
	max_health = maxi(1, initial_health)
	health = max_health
	health_changed.emit(health)


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health)
	if health == 0:
		destroyed.emit()
