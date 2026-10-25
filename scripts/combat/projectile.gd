class_name FortProjectile
extends Node3D
## A homing visual bolt. Impact consumes it before forwarding any damage.

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
	var mesh_instance := MeshInstance3D.new()
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.055, 0.055, 0.45)
	mesh_instance.mesh = shaft
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffe193")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(0.16, 0.08, 0.18)
	tip.mesh = tip_mesh
	tip.position.z = -0.25
	tip.material_override = material
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tip)


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
