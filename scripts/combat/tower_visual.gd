extends Node3D
## Imported crossbow: the pedestal stays fixed while its weapon aims and recoils.

const ModelScene = preload("res://assets/models/tower/crossbow.glb")

static var _materials: Dictionary = {}
var _level := 1
var _model: Node3D
var _base: Node3D
var _head: Node3D
var _muzzle: Node3D
var _upgrade_details: Node3D
var _head_origin := Vector3.ZERO
var _recoil_time := 0.0


func _ready() -> void:
	_model = ModelScene.instantiate() as Node3D
	_model.name = "CrossbowModel"
	add_child(_model)
	_base = _model.find_child("TowerBase", true, false) as Node3D
	_head = _model.find_child("AimHead", true, false) as Node3D
	_muzzle = _model.find_child("Muzzle", true, false) as Node3D
	assert(_base != null and _head != null and _muzzle != null, "Crossbow import must preserve its base, pivot and muzzle.")
	_head_origin = _head.position
	_upgrade_details = Node3D.new()
	_upgrade_details.name = "UpgradeDetails"
	add_child(_upgrade_details)
	_apply_level()


func set_level(level: int) -> void:
	_level = clampi(level, 1, 3)
	if is_node_ready():
		_apply_level()


func aim_at(world_target: Vector3) -> void:
	if not is_instance_valid(_head):
		return
	var direction := world_target - _head.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_head.global_rotation.y = atan2(-direction.x, -direction.z)


func muzzle_position() -> Vector3:
	if is_instance_valid(_muzzle):
		return _muzzle.global_position
	return global_position + Vector3.UP


func play_recoil() -> void:
	_recoil_time = 0.16


func _process(delta: float) -> void:
	if _recoil_time <= 0.0 or not is_instance_valid(_head):
		return
	_recoil_time = maxf(0.0, _recoil_time - delta)
	var kick := sin((_recoil_time / 0.16) * PI)
	var backwards := Basis(Vector3.UP, _head.rotation.y) * Vector3(0, 0, kick * 0.08)
	_head.position = _head_origin + backwards
	_head.rotation.x = -kick * 0.045


func _apply_level() -> void:
	# Keep the imported meshes/materials shared and preserve the weapon's yaw.
	_recoil_time = 0.0
	_head.position = _head_origin
	_head.rotation.x = 0.0
	for child in _upgrade_details.get_children():
		_upgrade_details.remove_child(child)
		child.queue_free()
	var lift := float(_level - 1) * 0.10
	_model.position.y = lift
	if _level == 1:
		return
	var trim := Color("407fc5") if _level == 2 else Color("dfb34f")
	var studs := Color("e9e0bf") if _level == 2 else Color("f7d57a")
	_box(_upgrade_details, Vector3(1.10, lift, 1.10), Vector3(0, lift * 0.5, 0), Color("718087"))
	_box(_upgrade_details, Vector3(1.13, 0.035, 1.13), Vector3(0, lift - 0.015, 0), trim)
	# The two silver / three gold studs make rank visible from either path side.
	for side in [-1.0, 1.0]:
		for rank in range(_level):
			var x := (float(rank) - float(_level - 1) * 0.5) * 0.17
			_box(_upgrade_details, Vector3(0.08, 0.055, 0.025), Vector3(x, lift * 0.5, side * 0.56), studs)
	if _level == 3:
		for x in [-0.47, 0.47]:
			for z in [-0.47, 0.47]:
				_box(_upgrade_details, Vector3(0.13, 0.09, 0.13), Vector3(x, lift + 0.02, z), trim)


func _box(parent: Node3D, size: Vector3, origin: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.87
		_materials[key] = material
	return _materials[key]
