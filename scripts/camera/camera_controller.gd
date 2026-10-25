class_name FortCamera
extends Node3D
## Camera gestures operate only on input not consumed by the HUD.

signal slot_selected(slot: FortBuildSlot)
signal selection_cleared

const TAP_THRESHOLD := 14.0
# Godot uses device -1 for mouse events synthesized from a touchscreen.
const EMULATED_MOUSE_DEVICE := -1
const MIN_ZOOM := 14.0
const MAX_ZOOM := 44.0
const PAN_FRACTION := 0.40

var camera: Camera3D
var _bounds := Rect2(-5.0, -8.75, 10.0, 17.5)
var _touches: Dictionary = {}
var _touch_starts: Dictionary = {}
var _touch_moved := false
var _had_multitouch := false
var _mouse_down := false
var _mouse_start := Vector2.ZERO
var _mouse_last := Vector2.ZERO
var _mouse_moved := false
var _zoom_ratio := 1.0
var _base_zoom := 32.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "IsometricCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.1
	camera.far = 100.0
	camera.position = Vector3(11.0, 19.0, 18.0)
	add_child(camera)
	camera.look_at(global_position, Vector3.UP)
	camera.current = true
	get_viewport().size_changed.connect(_update_viewport)
	_update_viewport()


func setup(bounds: Rect2) -> void:
	_bounds = bounds
	position = Vector3(bounds.get_center().x, 0.0, bounds.get_center().y)
	_zoom_ratio = 1.0
	if is_node_ready():
		_update_viewport()


func _update_viewport() -> void:
	if not is_instance_valid(camera):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	_base_zoom = clampf(18.7 / aspect, 23.5, 37.5)
	camera.size = clampf(_base_zoom * _zoom_ratio, MIN_ZOOM, MAX_ZOOM)
	_clamp_position()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == EMULATED_MOUSE_DEVICE:
		return
	# GUI can swallow a release after a drag started on the map. Deferred
	# cancellation prevents a stuck gesture without turning that release into a tap.
	if event is InputEventScreenTouch and not event.pressed:
		if _touches.has(event.index):
			call_deferred("_cancel_touch", event.index)
	elif event is InputEventScreenDrag and _touch_starts.has(event.index):
		if event.position.distance_to(_touch_starts[event.index]) > TAP_THRESHOLD:
			_touch_moved = true
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			call_deferred("_cancel_mouse")
	elif event is InputEventMouseMotion and _mouse_down:
		if event.position.distance_to(_mouse_start) > TAP_THRESHOLD:
			_mouse_moved = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == EMULATED_MOUSE_DEVICE:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_down:
		if _mouse_moved:
			_pan(_mouse_last, event.position)
		_mouse_last = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		_zoom_at(camera.size / maxf(event.factor, 0.1), event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var center := get_viewport().get_visible_rect().size * 0.5
		_pan(center, center - event.delta * 8.0)
		get_viewport().set_input_as_handled()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touches.is_empty():
			_touch_moved = false
			_had_multitouch = false
		_touches[event.index] = event.position
		_touch_starts[event.index] = event.position
		if _touches.size() > 1:
			_had_multitouch = true
	else:
		if not _touches.has(event.index):
			return
		var start: Vector2 = _touch_starts[event.index]
		if not event.canceled and not _touch_moved and not _had_multitouch \
				and event.position.distance_to(start) <= TAP_THRESHOLD:
			_select_at(event.position)
		_cancel_touch(event.index)
	get_viewport().set_input_as_handled()


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	if not _touches.has(event.index):
		return
	var old_position: Vector2 = _touches[event.index]
	if _touches.size() == 1:
		_touches[event.index] = event.position
		if _touch_moved:
			_pan(old_position, event.position)
	elif _touches.size() >= 2:
		var indices := _touches.keys()
		var first: Vector2 = _touches[indices[0]]
		var second: Vector2 = _touches[indices[1]]
		var old_distance := first.distance_to(second)
		var old_center := (first + second) * 0.5
		_touches[event.index] = event.position
		first = _touches[indices[0]]
		second = _touches[indices[1]]
		var new_distance := first.distance_to(second)
		var new_center := (first + second) * 0.5
		if old_distance > 5.0 and new_distance > 5.0:
			_zoom_at(camera.size * old_distance / new_distance, old_center)
		_pan(old_center, new_center)
	get_viewport().set_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_mouse_moved = false
			_mouse_start = event.position
			_mouse_last = event.position
		elif _mouse_down:
			if not _mouse_moved and event.position.distance_to(_mouse_start) <= TAP_THRESHOLD:
				_select_at(event.position)
			_cancel_mouse()
		get_viewport().set_input_as_handled()
	elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var zoom_factor := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
		_zoom_at(camera.size * zoom_factor, event.position)
		get_viewport().set_input_as_handled()


func _ground_point(screen_position: Vector2) -> Vector3:
	var ray_start := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	if absf(ray_direction.y) < 0.001:
		return global_position
	return ray_start + ray_direction * (-ray_start.y / ray_direction.y)


func _pan(from: Vector2, to: Vector2) -> void:
	var movement := _ground_point(from) - _ground_point(to)
	position += Vector3(movement.x, 0.0, movement.z)
	_clamp_position()


func _zoom_at(new_size: float, screen_position: Vector2) -> void:
	var before := _ground_point(screen_position)
	camera.size = clampf(new_size, MIN_ZOOM, MAX_ZOOM)
	_zoom_ratio = camera.size / _base_zoom
	var after := _ground_point(screen_position)
	position += Vector3(before.x - after.x, 0.0, before.z - after.z)
	_clamp_position()


func _clamp_position() -> void:
	var center := _bounds.get_center()
	var travel := _bounds.size * PAN_FRACTION
	position.x = clampf(position.x, center.x - travel.x, center.x + travel.x)
	position.z = clampf(position.z, center.y - travel.y, center.y + travel.y)
	position.y = 0.0


func _select_at(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * camera.far
	var query := PhysicsRayQueryParameters3D.create(origin, end, 2)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty() and result.collider is FortBuildSlot:
		slot_selected.emit(result.collider)
	else:
		selection_cleared.emit()


func _cancel_touch(index: int) -> void:
	_touches.erase(index)
	_touch_starts.erase(index)
	if _touches.is_empty():
		_touch_moved = false
		_had_multitouch = false


func _cancel_mouse() -> void:
	_mouse_down = false
	_mouse_moved = false


func cancel_gestures() -> void:
	_touches.clear()
	_touch_starts.clear()
	_touch_moved = false
	_had_multitouch = false
	_cancel_mouse()


func reset_view() -> void:
	cancel_gestures()
	position = Vector3(_bounds.get_center().x, 0.0, _bounds.get_center().y)
	_zoom_ratio = 1.0
	_update_viewport()
