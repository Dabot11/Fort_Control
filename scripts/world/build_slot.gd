class_name FortBuildSlot
extends StaticBody3D
## A predefined construction pad. Only these bodies occupy the selection layer.

var index: int = -1
var occupied: bool = false
var tower: Node3D = null
var selected: bool = false
var _marker: Node3D
var _outline: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	input_ray_pickable = true
	_create_geometry()
	set_selected(selected)
	set_occupied(occupied)


func set_selected(value: bool) -> void:
	selected = value
	if is_instance_valid(_outline):
		_outline.visible = value


func set_occupied(value: bool) -> void:
	occupied = value
	if is_instance_valid(_marker):
		_marker.visible = not value
	if is_instance_valid(_collision):
		var shape := _collision.shape as BoxShape3D
		shape.size = Vector3(1.12, 1.9 if value else 0.22, 1.12)
		_collision.position.y = 0.9 if value else 0.05


func _create_geometry() -> void:
	FortGeometry.box(self, Vector3(1.11, 0.12, 1.11), Vector3(0, -0.02, 0), Color("526e68"))
	FortGeometry.box(self, Vector3(0.99, 0.07, 0.99), Vector3(0, 0.055, 0), Color("d5dbbb"))
	for x in [-0.45, 0.45]:
		for z in [-0.45, 0.45]:
			FortGeometry.box(self, Vector3(0.13, 0.10, 0.13), Vector3(x, 0.08, z), Color("8aadb3"))
	_marker = Node3D.new()
	_marker.name = "AvailableMarker"
	add_child(_marker)
	FortGeometry.box(_marker, Vector3(0.58, 0.025, 0.14), Vector3(0, 0.11, 0), Color("438d9d"))
	FortGeometry.box(_marker, Vector3(0.14, 0.025, 0.58), Vector3(0, 0.11, 0), Color("438d9d"))
	_outline = Node3D.new()
	_outline.name = "SelectionOutline"
	add_child(_outline)
	for x in [-0.59, 0.59]:
		FortGeometry.box(_outline, Vector3(0.055, 0.07, 1.23), Vector3(x, 0.13, 0), Color("ffe290"))
	for z in [-0.59, 0.59]:
		FortGeometry.box(_outline, Vector3(1.23, 0.07, 0.055), Vector3(0, 0.13, z), Color("ffe290"))
	_collision = CollisionShape3D.new()
	_collision.name = "SelectionCollider"
	_collision.shape = BoxShape3D.new()
	add_child(_collision)
