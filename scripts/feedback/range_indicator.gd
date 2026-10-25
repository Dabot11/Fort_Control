class_name FortRangeIndicator
extends Node3D
## Two shared, flat meshes explain current range and the next upgrade.
## Pure presentation: no colliders, raycasts or gameplay ownership.

const SEGMENTS := 64
const CURRENT_COLOR := Color(0.31, 0.87, 0.97, 0.84)
const NEXT_COLOR := Color(1.0, 0.80, 0.34, 0.90)
const GROUND_OFFSET := 0.10

static var _solid_mesh: ArrayMesh
static var _dashed_mesh: ArrayMesh
static var _current_material: StandardMaterial3D
static var _next_material: StandardMaterial3D

var current_radius: float = 0.0
var next_radius: float = 0.0
var _current_ring: MeshInstance3D
var _next_ring: MeshInstance3D


func _ready() -> void:
	_ensure_rings()
	clear()


func show_for(slot: FortBuildSlot, levels: Array) -> void:
	if not is_instance_valid(slot) or levels.is_empty():
		clear()
		return
	_ensure_rings()
	var level := 1
	var occupied := slot.occupied and is_instance_valid(slot.tower)
	if occupied:
		level = clampi(int(slot.tower.get("level")), 1, levels.size())
	current_radius = maxf(0.0, float(levels[level - 1]["range"]))
	next_radius = float(levels[level]["range"]) if occupied and level < levels.size() else 0.0
	global_position = slot.global_position + Vector3(0, GROUND_OFFSET, 0)
	_current_ring.scale = Vector3(current_radius, 1, current_radius)
	_next_ring.scale = Vector3(next_radius, 1, next_radius)
	_next_ring.visible = next_radius > 0.0
	visible = current_radius > 0.0


func clear() -> void:
	current_radius = 0.0
	next_radius = 0.0
	visible = false


func _ensure_rings() -> void:
	if is_instance_valid(_current_ring):
		return
	if _solid_mesh == null:
		_solid_mesh = _make_ring(false)
		_dashed_mesh = _make_ring(true)
		_current_material = _make_material(CURRENT_COLOR)
		_next_material = _make_material(NEXT_COLOR)
	_current_ring = _ring("CurrentRange", _solid_mesh, _current_material)
	_next_ring = _ring("UpgradeRange", _dashed_mesh, _next_material)
	_next_ring.position.y = 0.008


func _ring(node_name: String, mesh: ArrayMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.name = node_name
	ring.mesh = mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return ring


static func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	return material


static func _make_ring(dashed: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	# The outer edge is the exact gameplay radius. Thickness scales with range.
	for segment in range(SEGMENTS):
		if dashed and segment % 4 >= 2:
			continue
		var start := TAU * float(segment) / SEGMENTS
		var finish := TAU * float(segment + 1) / SEGMENTS
		var outside_a := Vector3(cos(start), 0, sin(start))
		var outside_b := Vector3(cos(finish), 0, sin(finish))
		var inside_a := outside_a * 0.98
		var inside_b := outside_b * 0.98
		vertices.append_array(PackedVector3Array([
			outside_a, inside_a, outside_b,
			outside_b, inside_a, inside_b
		]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
