class_name FortGeometry
extends RefCounted
## Native low-poly primitives. Materials are shared across the entire battlefield.

static var _materials: Dictionary = {}


static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if not _materials.has(key):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.92
		_materials[key] = result
	return _materials[key] as StandardMaterial3D


static func mesh(parent: Node3D, shape: Mesh, position: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = position
	instance.material_override = material(color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, position, color)


static func cylinder(parent: Node3D, radius: float, height: float, position: Vector3, color: Color, vertices: int = 8, top_radius: float = -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top_radius < 0.0 else top_radius
	shape.height = height
	shape.radial_segments = vertices
	return mesh(parent, shape, position, color)


static func sphere(parent: Node3D, radius: float, position: Vector3, color: Color) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	shape.radial_segments = 8
	shape.rings = 3
	return mesh(parent, shape, position, color)
