class_name FortProjectile
extends Node3D
## A homing visual bolt. Impact consumes it before forwarding any damage.

const ArrowScene := preload("res://assets/models/arrow/crystal_arrow.glb")

var _target: FortEnemy
var _damage: float = 0.0
var _speed: float = 0.0
var _consumed: bool = false
var _age: float = 0.0


func configure(target: FortEnemy, damage: float, speed: float) -> void:
	_target = target
	_damage = maxf(damage, 0.0)
	_speed = maxf(speed, 0.1)


func _ready() -> void:
	var visual := ArrowScene.instantiate() as Node3D
	visual.name = "CrystalArrow"
	# Source points along +Y and is 0.952148 units long; combat points along -Z.
	visual.rotation.x = -PI * 0.5
	visual.scale = Vector3.ONE * (0.62 / 0.952148)
	add_child(visual)
	for child: Node in visual.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	_age += delta
	if not is_instance_valid(_target) or not _target.is_targetable() or _age > 8.0:
		_consume()
		return
	var destination := _target.global_position + Vector3(0.0, 0.7, 0.0)
	var offset := destination - global_position
	var distance := offset.length()
	if distance <= _speed * delta + 0.08:
		var victim := _target
		_consume()
		victim.take_damage(_damage)
		return
	global_position += offset / distance * _speed * delta
	if offset.length_squared() > 0.0001:
		look_at(destination, Vector3.UP)


func _consume() -> void:
	_consumed = true
	set_physics_process(false)
	queue_free()
