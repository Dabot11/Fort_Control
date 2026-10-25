class_name FortMap
extends Node3D
## Battlefield geometry is generated from a fixed, editable map resource.

var waypoints: Array[Vector3] = []
var slots: Array[FortBuildSlot] = []
var castle_position: Vector3 = Vector3.ZERO
var world_bounds: Rect2
var _columns: int = 8
var _rows: int = 14
var _cell_size: float = 1.25
var _generated: Node3D


func setup(data: Dictionary) -> void:
	# Rebuilding is safe: detach old nodes before queueing their deletion.
	if is_instance_valid(_generated):
		remove_child(_generated)
		_generated.queue_free()
	waypoints.clear()
	slots.clear()
	_columns = int(data["columns"])
	_rows = int(data["rows"])
	_cell_size = float(data["cell_size"])
	world_bounds = Rect2(Vector2(-_columns * _cell_size / 2.0, -_rows * _cell_size / 2.0), Vector2(_columns * _cell_size, _rows * _cell_size))
	_generated = Node3D.new()
	_generated.name = "Battlefield"
	add_child(_generated)
	var path_cells: Dictionary = {}
	for coordinate in data["path"]:
		var cell: Array = coordinate
		path_cells[Vector2i(int(cell[0]), int(cell[1]))] = true
		waypoints.append(cell_to_world(cell))
	_make_ground(path_cells)
	for coordinate in data["build_slots"]:
		var cell: Array = coordinate
		assert(not path_cells.has(Vector2i(int(cell[0]), int(cell[1]))), "Build slots must not intersect the fixed path.")
		var slot := FortBuildSlot.new()
		slot.name = "BuildSlot%d" % slots.size()
		slot.index = slots.size()
		slot.position = cell_to_world(cell)
		_generated.add_child(slot)
		slots.append(slot)
	castle_position = cell_to_world(data["castle"])
	_make_castle()
	_make_decorations(data)
	_make_lighting()
	_make_entrance(waypoints[0])


func cell_to_world(cell: Array) -> Vector3:
	return Vector3((float(cell[0]) - (_columns - 1) / 2.0) * _cell_size, 0.08, (float(cell[1]) - (_rows - 1) / 2.0) * _cell_size)


func _make_ground(path_cells: Dictionary) -> void:
	var width := _columns * _cell_size
	var length := _rows * _cell_size
	FortGeometry.box(_generated, Vector3(width + 0.18, 0.6, length + 0.18), Vector3(0, -0.45, 0), Color("486653"))
	FortGeometry.box(_generated, Vector3(width + 0.08, 0.18, length + 0.08), Vector3(0, -0.12, 0), Color("6f9b51"))
	for row in range(_rows):
		for column in range(_columns):
			var position := cell_to_world([column, row])
			position.y = -0.01
			var is_path := path_cells.has(Vector2i(column, row))
			var color := Color("d9b468") if is_path else Color("88b967")
			if (row + column) % 2 == 0:
				color = Color("e2c17a") if is_path else Color("91c171")
			FortGeometry.box(_generated, Vector3(_cell_size - 0.035, 0.13, _cell_size - 0.035), position, color)
			if is_path:
				# Large readable paving slabs, with a seam and a smaller inset stone.
				FortGeometry.box(_generated, Vector3(0.68, 0.025, 0.96), position + Vector3(-0.19, 0.078, 0), color.lightened(0.08))
				FortGeometry.box(_generated, Vector3(0.33, 0.025, 0.46), position + Vector3(0.36, 0.078, -0.25), color.darkened(0.035))
				FortGeometry.box(_generated, Vector3(0.33, 0.025, 0.46), position + Vector3(0.36, 0.078, 0.25), color.lightened(0.025))


func _make_castle() -> void:
	var castle := Node3D.new()
	castle.name = "CastleVisual"
	castle.position = castle_position
	_generated.add_child(castle)
	var stone := Color("ced3bd")
	var shadow_stone := Color("9aa99f")
	var roof := Color("367db2")
	FortGeometry.box(castle, Vector3(2.75, 0.18, 1.75), Vector3(0, 0.02, -0.15), shadow_stone)
	FortGeometry.box(castle, Vector3(1.65, 1.35, 1.25), Vector3(0, 0.74, -0.15), stone)
	FortGeometry.box(castle, Vector3(1.76, 0.13, 1.34), Vector3(0, 1.44, -0.15), Color("e5e4ce"))
	# A square pyramidal roof, rotated so that its edges align with the keep.
	var keep_roof := FortGeometry.cylinder(castle, 1.28, 0.85, Vector3(0, 1.93, -0.15), roof, 4, 0.0)
	keep_roof.rotation.y = PI / 4.0
	for side in [-1.0, 1.0]:
		var x: float = side * 1.05
		FortGeometry.cylinder(castle, 0.47, 1.8, Vector3(x, 0.95, 0.1), stone)
		FortGeometry.cylinder(castle, 0.52, 0.15, Vector3(x, 1.78, 0.1), shadow_stone)
		FortGeometry.cylinder(castle, 0.65, 0.88, Vector3(x, 2.27, 0.1), roof, 8, 0.0)
		FortGeometry.box(castle, Vector3(0.13, 0.36, 0.035), Vector3(x, 1.24, 0.565), Color("344e53"))
		FortGeometry.box(castle, Vector3(0.08, 0.56, 0.08), Vector3(x, 2.94, 0.1), Color("e6c477"))
		FortGeometry.box(castle, Vector3(0.43, 0.25, 0.035), Vector3(x + 0.22, 3.07, 0.1), Color("edc16a"))
	# Gate faces the advancing path (+Z). Dark inset and timber crosspieces.
	FortGeometry.box(castle, Vector3(0.65, 0.91, 0.06), Vector3(0, 0.53, 0.51), Color("354a46"))
	FortGeometry.box(castle, Vector3(0.48, 0.73, 0.07), Vector3(0, 0.44, 0.55), Color("725a43"))
	for y in [0.22, 0.59]:
		FortGeometry.box(castle, Vector3(0.52, 0.06, 0.04), Vector3(0, y, 0.6), Color("b39a65"))
	for x in [-0.7, -0.35, 0.0, 0.35, 0.7]:
		FortGeometry.box(castle, Vector3(0.18, 0.23, 0.18), Vector3(x, 1.61, 0.49), stone)
	for x in [-0.54, 0.54]:
		FortGeometry.box(castle, Vector3(0.11, 0.3, 0.04), Vector3(x, 1.0, 0.51), Color("344e53"))


func _make_decorations(data: Dictionary) -> void:
	var used: Dictionary = {}
	for key in ["path", "build_slots"]:
		for coordinate in data[key]:
			used[Vector2i(int(coordinate[0]), int(coordinate[1]))] = true
	# Fixed placement keeps the battlefield deterministic and navigation unobstructed.
	var trees := [[0, 0], [7, 1], [0, 5], [7, 9], [0, 13], [7, 13]]
	for coordinate in trees:
		var cell: Array = coordinate
		if used.has(Vector2i(int(cell[0]), int(cell[1]))):
			continue
		var position := cell_to_world(cell)
		FortGeometry.cylinder(_generated, 0.12, 0.7, position + Vector3(0, 0.3, 0), Color("806847"), 6)
		FortGeometry.cylinder(_generated, 0.54, 1.08, position + Vector3(0, 1.05, 0), Color("488c59"), 6, 0.0)
		FortGeometry.cylinder(_generated, 0.4, 0.9, position + Vector3(0, 1.5, 0), Color("60a86a"), 6, 0.0)
	for coordinate in [[0, 7], [7, 4], [6, 12], [0, 2]]:
		var position := cell_to_world(coordinate)
		var rock := FortGeometry.sphere(_generated, 0.28, position + Vector3(0.1, 0.1, 0), Color("9ba994"))
		rock.scale = Vector3(1.25, 0.65, 0.85)
		FortGeometry.sphere(_generated, 0.14, position + Vector3(-0.22, 0.05, 0.17), Color("b0baa1"))
	for coordinate in [[6, 3], [0, 10], [6, 9], [1, 1], [6, 11]]:
		var position := cell_to_world(coordinate)
		for offset in [Vector3(-0.14, 0.05, 0), Vector3(0.07, 0.05, 0.13), Vector3(0.19, 0.05, -0.09)]:
			FortGeometry.cylinder(_generated, 0.055, 0.22, position + offset, Color("649c50"), 4, 0.0)
			FortGeometry.sphere(_generated, 0.055, position + offset + Vector3(0, 0.13, 0), Color("f1dfa1"))


func _make_lighting() -> void:
	var sunlight := DirectionalLight3D.new()
	sunlight.name = "Sunlight"
	sunlight.rotation_degrees = Vector3(-52, -28, 0)
	sunlight.light_color = Color("fff4dc")
	sunlight.light_energy = 1.05
	sunlight.shadow_enabled = false
	_generated.add_child(sunlight)
	var ambient := WorldEnvironment.new()
	ambient.name = "MeadowEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("203c43")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d1e5e3")
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	ambient.environment = environment
	_generated.add_child(ambient)


func _make_entrance(position: Vector3) -> void:
	for side in [-1.0, 1.0]:
		var post := position + Vector3(side * 0.52, 0.4, 0.45)
		FortGeometry.box(_generated, Vector3(0.09, 0.95, 0.09), post, Color("806847"))
		FortGeometry.box(_generated, Vector3(0.27, 0.32, 0.045), post + Vector3(side * 0.14, 0.29, 0), Color("b86e4c"))
