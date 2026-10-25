extends Node3D
## Native low-poly crossbow; gameplay and targeting belong to the parent tower.

static var _materials: Dictionary = {}
var _level := 1
var _model: Node3D
var _head: Node3D
var _recoil_time := 0.0


func _ready() -> void:
	_rebuild()


func set_level(level: int) -> void:
	_level = clampi(level, 1, 3)
	if is_inside_tree():
		_rebuild()


func aim_at(world_target: Vector3) -> void:
	if not is_instance_valid(_head):
		return
	var direction := world_target - _head.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.0001:
		_head.global_rotation.y = atan2(-direction.x, -direction.z)


func muzzle_position() -> Vector3:
	if is_instance_valid(_head):
		return _head.to_global(Vector3(0, 0.05, -0.75))
	return global_position + Vector3.UP


func play_recoil() -> void:
	_recoil_time = 0.16


func _process(delta: float) -> void:
	if _recoil_time <= 0.0 or not is_instance_valid(_head):
		return
	_recoil_time = maxf(0.0, _recoil_time - delta)
	var kick := sin((_recoil_time / 0.16) * PI)
	_head.position.x = sin(_head.rotation.y) * kick * 0.12
	_head.position.z = cos(_head.rotation.y) * kick * 0.12
	_head.rotation.x = -kick * 0.07


func _rebuild() -> void:
	_recoil_time = 0.0
	var previous_yaw := 0.0
	if is_instance_valid(_head):
		previous_yaw = _head.rotation.y
	if is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	_model = Node3D.new()
	_model.name = "CrossbowModel"
	add_child(_model)
	var stone := Color("bcc7c0")
	var dark_stone := Color("647c85")
	var wood := Color("8a4d2d")
	var wood_light := Color("bc8550")
	var accent := Color("407fc5") if _level < 3 else Color("e6bb4e")
	var height := 0.68 + float(_level - 1) * 0.16
	_box(_model, Vector3(0.88, 0.16, 0.88), Vector3(0, 0.08, 0), dark_stone)
	_box(_model, Vector3(0.61, height, 0.61), Vector3(0, 0.16 + height * 0.5, 0), stone)
	for y in [0.20, 0.16 + height * 0.5, 0.16 + height]:
		_box(_model, Vector3(0.66, 0.055, 0.66), Vector3(0, y, 0), dark_stone)
	_box(_model, Vector3(0.78, 0.12, 0.78), Vector3(0, 0.19 + height, 0), accent)
	for x in [-0.30, 0.30]:
		_box(_model, Vector3(0.09, height * 0.73, 0.07), Vector3(x, 0.18 + height * 0.5, -0.32), accent)
	if _level >= 2:
		for x in [-0.38, 0.38]:
			for z in [-0.38, 0.38]:
				_box(_model, Vector3(0.14, 0.28, 0.14), Vector3(x, 0.22 + height, z), stone)
	if _level == 3:
		_box(_model, Vector3(0.23, 0.29, 0.05), Vector3(0, 0.46 + height * 0.25, -0.34), accent)
		_box(_model, Vector3(0.045, 0.21, 0.035), Vector3(0, 0.46 + height * 0.25, -0.375), wood)
		_box(_model, Vector3(0.15, 0.04, 0.035), Vector3(0, 0.46 + height * 0.25, -0.375), wood)
	_head = Node3D.new()
	_head.name = "AimHead"
	_head.position.y = height + 0.45
	_model.add_child(_head)
	_head.rotation.y = previous_yaw
	_box(_head, Vector3(0.18, 0.15, 0.86), Vector3(0, 0, -0.14), wood)
	_box(_head, Vector3(0.24, 0.10, 0.25), Vector3(0, -0.08, 0.19), wood_light)
	var span := 0.48 + float(_level - 1) * 0.06
	_beam(_head, Vector3(-span, 0.02, -0.18), Vector3(-0.20, 0.02, -0.39), 0.055, wood_light)
	_beam(_head, Vector3(-0.20, 0.02, -0.39), Vector3(0.20, 0.02, -0.39), 0.06, wood_light)
	_beam(_head, Vector3(0.20, 0.02, -0.39), Vector3(span, 0.02, -0.18), 0.055, wood_light)
	_beam(_head, Vector3(-span, 0.02, -0.18), Vector3(0, 0.02, 0.16), 0.012, Color("e6d8b7"))
	_beam(_head, Vector3(span, 0.02, -0.18), Vector3(0, 0.02, 0.16), 0.012, Color("e6d8b7"))
	_box(_head, Vector3(0.035, 0.04, 0.72), Vector3(0, 0.10, -0.23), Color("ddd5bc"))
	_box(_head, Vector3(0.10, 0.045, 0.13), Vector3(0, 0.10, -0.62), dark_stone)
	if _level >= 2:
		_box(_head, Vector3(0.22, 0.19, 0.10), Vector3(0, 0.02, -0.33), accent)
	if _level == 3:
		for x in [-0.12, 0.12]:
			_box(_head, Vector3(0.03, 0.04, 0.66), Vector3(x, 0.10, -0.23), Color("ddd5bc"))


func _box(parent: Node3D, size: Vector3, origin: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = origin
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _beam(parent: Node3D, start: Vector3, end: Vector3, radius: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 6
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = (start + end) * 0.5
	instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	instance.material_override = _material(color)
	parent.add_child(instance)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.87
		_materials[key] = material
	return _materials[key]
