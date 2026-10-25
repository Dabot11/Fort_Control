class_name FortTransientEffect
extends Node3D
## Short-lived decoration only. No collisions, damage or economy dependencies.

static var _materials: Dictionary = {}
static var _cube: BoxMesh
static var _ring_mesh: TorusMesh

var age: float = 0.0
var lifetime: float = 0.6
var kind: String = "hit"
var amount: int = 0
var _parts: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _scales: Array[Vector3] = []
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _label: Label3D


func configure(effect_kind: String, reward: int = 0) -> void:
	kind = effect_kind
	amount = reward


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if _cube == null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.88
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 32
		_ring_mesh.ring_segments = 4
	match kind:
		"shot":
			lifetime = 0.12
			_burst(3, Color("fff1b4"), 0.7, 0.045)
		"hit":
			lifetime = 0.24
			_burst(5, Color("ffe2a1"), 1.1, 0.065)
		"kill":
			lifetime = 0.85
			_burst(6, Color("e8dcc0"), 1.4, 0.095)
			_reward_label("+%d oro" % amount, Color("ffdc77"))
		"built":
			lifetime = 0.65
			_make_ring(Color("9ce1ed"))
			_burst(4, Color("e6cc8f"), 0.65, 0.06)
		"upgraded":
			lifetime = 1.0
			_make_ring(Color("ffdb71"))
			_burst(7, Color("ffdc77"), 1.0, 0.065)
			_reward_label("¡Mejora!", Color("ffdc77"))
		"castle_hit":
			lifetime = 0.7
			_make_ring(Color("ef896e"))
			_burst(7, Color("efaa79"), 1.6, 0.12)
			_reward_label("−%d %s" % [amount, "vida" if amount == 1 else "vidas"], Color("ff9e8c"))


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		# Detach immediately so the owner's bound counts only live effects.
		if get_parent() != null:
			get_parent().remove_child(self)
		queue_free()
		return
	var progress := age / lifetime
	var fade := 1.0 - progress
	for index in _parts.size():
		var part: MeshInstance3D = _parts[index]
		var gravity := 3.4 if kind in ["kill", "castle_hit"] else 0.8
		part.position = _velocities[index] * age + Vector3.DOWN * gravity * age * age * 0.5
		part.scale = _scales[index] * maxf(0.05, fade)
		part.rotation = Vector3(age * (2.0 + index), age * 3.0, age * 1.7)
	if is_instance_valid(_ring):
		var radius := lerpf(0.38, 1.20 if kind == "castle_hit" else 0.85, progress)
		_ring.scale = Vector3(radius, maxf(0.01, fade * 0.10), radius)
		_ring_material.albedo_color.a = fade * 0.8
	if is_instance_valid(_label):
		_label.position.y = 1.0 + progress * 1.2
		_label.modulate.a = minf(1.0, fade * 2.4)


func _burst(count: int, color: Color, speed: float, size: float) -> void:
	for index in count:
		var angle := TAU * float(index) / float(count) + 0.3
		var mesh := MeshInstance3D.new()
		mesh.mesh = _cube
		mesh.material_override = _material(color)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shape := Vector3(size, size * (2.0 if kind == "kill" else 1.0), size)
		mesh.scale = shape
		add_child(mesh)
		_parts.append(mesh)
		_scales.append(shape)
		_velocities.append(Vector3(cos(angle) * speed, speed * (0.7 + float(index % 3) * 0.2), sin(angle) * speed))


func _make_ring(color: Color) -> void:
	_ring = MeshInstance3D.new()
	_ring.mesh = _ring_mesh
	# Per-effect alpha keeps fading compatible with Mobile and Compatibility.
	_ring_material = _material(color).duplicate() as StandardMaterial3D
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color.a = 0.8
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = 0.12
	_ring.scale = Vector3(0.38, 0.10, 0.38)
	add_child(_ring)


func _reward_label(text: String, color: Color) -> void:
	_label = Label3D.new()
	_label.text = text
	_label.font_size = 46
	_label.pixel_size = 0.010
	_label.outline_size = 9
	_label.outline_modulate = Color("172d37")
	_label.modulate = color
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label.position.y = 1.0
	add_child(_label)


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = material
	return _materials[key]
