extends Node3D
## Placeholder skeleton. Replace this child without changing enemy gameplay logic.

static var _materials: Dictionary = {}
var _body: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _health_bar: Node3D
var _health_fill: MeshInstance3D
var _phase := 0.0
var _health_ratio := 1.0
var _hit_time := 0.0


func _ready() -> void:
	_body = Node3D.new()
	_body.name = "SkeletonModel"
	add_child(_body)
	var bone := Color("e9e0c4")
	var shade := Color("b6ac94")
	var dark := Color("222d38")
	_box(_body, Vector3(0.10, 0.36, 0.10), Vector3(0, 0.62, 0.02), shade)
	for y in [0.62, 0.70, 0.78]:
		_box(_body, Vector3(0.30, 0.045, 0.14), Vector3(0, y, 0), bone)
	_box(_body, Vector3(0.25, 0.12, 0.15), Vector3(0, 0.43, 0), bone)
	_box(_body, Vector3(0.29, 0.25, 0.24), Vector3(0, 0.98, -0.015), bone)
	_box(_body, Vector3(0.20, 0.065, 0.19), Vector3(0, 0.825, -0.035), bone)
	_box(_body, Vector3(0.075, 0.075, 0.025), Vector3(-0.072, 1.005, -0.145), dark)
	_box(_body, Vector3(0.075, 0.075, 0.025), Vector3(0.072, 1.005, -0.145), dark)
	_box(_body, Vector3(0.042, 0.05, 0.025), Vector3(0, 0.925, -0.145), dark)
	for x in [-0.06, 0.0, 0.06]:
		_box(_body, Vector3(0.018, 0.025, 0.025), Vector3(x, 0.855, -0.14), dark)
	_left_leg = _limb(Vector3(-0.085, 0.40, 0), 0.34, bone, true)
	_right_leg = _limb(Vector3(0.085, 0.40, 0), 0.34, bone, true)
	_left_arm = _limb(Vector3(-0.23, 0.78, 0), 0.32, bone, false)
	_right_arm = _limb(Vector3(0.23, 0.78, 0), 0.32, bone, false)
	_left_arm.rotation.z = -0.12
	_right_arm.rotation.z = 0.12
	_health_bar = Node3D.new()
	_health_bar.position.y = 1.28
	add_child(_health_bar)
	_box(_health_bar, Vector3(0.49, 0.065, 0.045), Vector3.ZERO, dark)
	_health_fill = _box(_health_bar, Vector3(0.43, 0.04, 0.055), Vector3.ZERO, Color("a2dc67"))
	set_health_ratio(_health_ratio)


func _limb(origin: Vector3, length: float, color: Color, foot: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = origin
	_body.add_child(pivot)
	_box(pivot, Vector3(0.075, length, 0.075), Vector3(0, -length * 0.5, 0), color)
	_box(pivot, Vector3(0.095, 0.08, 0.09), Vector3(0, -length * 0.5, 0), color)
	if foot:
		_box(pivot, Vector3(0.11, 0.065, 0.18), Vector3(0, -length, -0.045), color)
	else:
		_box(pivot, Vector3(0.10, 0.09, 0.10), Vector3(0, -length, 0), color)
	return pivot


func animate_walk(delta: float, speed: float) -> void:
	if not is_instance_valid(_body):
		return
	_phase += delta * maxf(speed, 0.2) * 7.0
	var swing := sin(_phase) * 0.52
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.65 - 0.2
	_right_arm.rotation.x = swing * 0.65 - 0.2
	_body.position.y = absf(sin(_phase)) * 0.035
	_body.rotation.z = sin(_phase) * 0.025


func show_hit() -> void:
	_hit_time = 0.15


func _process(delta: float) -> void:
	if _hit_time <= 0.0 or not is_instance_valid(_body):
		return
	_hit_time = maxf(0.0, _hit_time - delta)
	var strength := _hit_time / 0.15
	_body.scale = Vector3.ONE * (1.0 + strength * 0.12)
	_body.position.x = sin(strength * TAU) * strength * 0.035


func set_health_ratio(ratio: float) -> void:
	_health_ratio = clampf(ratio, 0.0, 1.0)
	if not is_instance_valid(_health_fill):
		return
	_health_fill.scale.x = maxf(0.001, _health_ratio)
	_health_fill.position.x = -0.215 * (1.0 - _health_ratio)
	_health_bar.visible = _health_ratio < 0.999 and _health_ratio > 0.0


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
		material.roughness = 0.88
		_materials[key] = material
	return _materials[key]
