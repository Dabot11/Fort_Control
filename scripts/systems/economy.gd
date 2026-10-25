class_name FortEconomy
extends Node
## The only authority for purchases. Failed transactions never alter gold.

signal gold_changed(gold: int)

var gold: int = 0


func reset(initial_gold: int) -> void:
	gold = maxi(0, initial_gold)
	gold_changed.emit(gold)


func try_spend(amount: int) -> bool:
	if amount < 0 or amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	gold_changed.emit(gold)
