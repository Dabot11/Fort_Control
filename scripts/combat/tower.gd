class_name FortTower
extends Node3D
## No economy coupling: GameManager validates and pays before calling upgrade.

const VisualScript = preload("res://scripts/combat/tower_visual.gd")
const ProjectileScript = preload("res://scripts/combat/projectile.gd")

var level: int = 1
var visual: Node3D
var _levels: Array = []
var _projectile_speed: float = 15.0
var _enemies_root: Node3D
var _projectiles_root: Node3D
var _cooldown: float = 0.0
var _target: FortEnemy


func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "Visual"
	add_child(visual)
	visual.call("set_level", level)


func configure(levels: Array, projectile_speed: float, enemies_root: Node3D, projectiles_root: Node3D) -> void:
	_levels = levels.duplicate(true)
	_projectile_speed = projectile_speed
	_enemies_root = enemies_root
	_projectiles_root = projectiles_root
	level = 1
	_cooldown = 0.0
	if is_instance_valid(visual):
		visual.call("set_level", level)


func stats() -> Dictionary:
	if _levels.is_empty():
		return {}
	return _levels[level - 1].duplicate()


func upgrade() -> bool:
	if level >= mini(3, _levels.size()):
		return false
	level += 1
	if is_instance_valid(visual):
		visual.call("set_level", level)
	return true


func _physics_process(delta: float) -> void:
	if _levels.is_empty() or not is_instance_valid(_enemies_root) or not is_instance_valid(_projectiles_root):
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if is_instance_valid(_target) and _target.is_targetable() and is_instance_valid(visual):
		visual.call("aim_at", _target.global_position)
	if _cooldown > 0.0:
		return
	_target = select_target()
	if not is_instance_valid(_target):
		return
	var current := stats()
	visual.call("aim_at", _target.global_position)
	var bolt: FortProjectile = ProjectileScript.new()
	bolt.configure(_target, float(current["damage"]), _projectile_speed)
	_projectiles_root.add_child(bolt)
	bolt.global_position = visual.call("muzzle_position")
	_cooldown = maxf(float(current["interval"]), 0.05)


func select_target() -> FortEnemy:
	if _levels.is_empty() or not is_instance_valid(_enemies_root):
		return null
	var best: FortEnemy = null
	var furthest: float = -1.0
	var radius: float = float(_levels[level - 1]["range"])
	for child in _enemies_root.get_children():
		if not child is FortEnemy:
			continue
		var enemy := child as FortEnemy
		if not enemy.is_targetable():
			continue
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length_squared() <= radius * radius and enemy.progress > furthest:
			best = enemy
			furthest = enemy.progress
	return best
