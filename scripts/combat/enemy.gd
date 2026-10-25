class_name FortEnemy
extends Node3D
## Combat owns health and movement; the replaceable Visual child owns appearance.

signal killed(enemy: FortEnemy)
signal escaped(enemy: FortEnemy)

const VisualScript = preload("res://scripts/combat/enemy_visual.gd")

var health: float = 0.0
var max_health: float = 0.0
var speed: float = 0.0
var reward: int = 0
var castle_damage: int = 1
var alive: bool = false
var progress: float = 0.0
var visual: Node3D

var _path: Array[Vector3] = []
var _next_waypoint: int = 1
var _configured: bool = false


func _ready() -> void:
	visual = VisualScript.new()
	visual.name = "Visual"
	add_child(visual)
	if _configured and not _path.is_empty():
		global_position = _path[0]
	_update_health_visual()


func configure(path: Array[Vector3], stats: Dictionary, kill_reward: int, escape_damage: int) -> void:
	_path.assign(path)
	max_health = maxf(float(stats.get("health", 1.0)), 1.0)
	health = max_health
	speed = maxf(float(stats.get("speed", 1.0)), 0.0)
	reward = maxi(kill_reward, 0)
	castle_damage = maxi(escape_damage, 0)
	progress = 0.0
	_next_waypoint = 1
	_configured = true
	alive = not _path.is_empty()
	set_physics_process(alive)
	if is_inside_tree() and alive:
		global_position = _path[0]
	_update_health_visual()


func _physics_process(delta: float) -> void:
	if not alive:
		return
	var remaining := speed * delta
	while alive and _next_waypoint < _path.size():
		var destination: Vector3 = _path[_next_waypoint]
		var offset := destination - global_position
		var distance := offset.length()
		if distance <= 0.0001:
			_next_waypoint += 1
			continue
		var direction := offset / distance
		if direction.x * direction.x + direction.z * direction.z > 0.0001:
			rotation.y = atan2(-direction.x, -direction.z)
		var travelled := minf(remaining, distance)
		global_position += direction * travelled
		progress += travelled
		remaining -= travelled
		if travelled >= distance:
			global_position = destination
			_next_waypoint += 1
		else:
			break
		if remaining <= 0.0:
			break
	if _next_waypoint >= _path.size():
		_escape()
	elif is_instance_valid(visual):
		visual.call("animate_walk", delta, speed)


func take_damage(amount: float) -> void:
	if not is_targetable() or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	_update_health_visual()
	if health <= 0.0:
		# Mark terminal before emitting: signal callbacks and other bolts are harmless.
		alive = false
		set_physics_process(false)
		killed.emit(self)
		queue_free()


func is_targetable() -> bool:
	return alive and health > 0.0 and not is_queued_for_deletion()


func _escape() -> void:
	if not alive:
		return
	alive = false
	set_physics_process(false)
	escaped.emit(self)
	queue_free()


func _update_health_visual() -> void:
	if is_instance_valid(visual) and max_health > 0.0:
		visual.call("set_health_ratio", health / max_health)
