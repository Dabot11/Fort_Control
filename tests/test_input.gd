extends SceneTree
## Real Input.parse_input_event dispatch exercises GUI interception and gestures.
## Run via scripts/run_tests.sh; no third-party framework or hardware required.

var _checks := 0
var _failures := 0
var _game: FortGame


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("INPUT CHECK FAILED: " + description)


func _frame() -> void:
	await process_frame
	await process_frame


func _mouse(point: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	var mask := MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_LEFT
	event.button_mask = mask if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frame()


func _mouse_tap(point: Vector2) -> void:
	await _mouse(point, true)
	await _mouse(point, false)


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	Input.parse_input_event(event)
	await _frame()


func _touch_tap(point: Vector2) -> void:
	await _touch(0, point, true)
	await _touch(0, point, false)


func _drag_mouse(from: Vector2, to: Vector2) -> void:
	await _mouse(from, true)
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)
	await _frame()
	await _mouse(to, false)


func _drag_right_mouse(from: Vector2, to: Vector2) -> void:
	await _mouse(from, true, MOUSE_BUTTON_RIGHT)
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	event.relative = to - from
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(event)
	await _frame()
	await _mouse(to, false, MOUSE_BUTTON_RIGHT)


func _drag_touch(index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	Input.parse_input_event(event)
	await _frame()


func _drag_touch_pair(first_from: Vector2, first_to: Vector2, second_from: Vector2, second_to: Vector2) -> void:
	# Devices deliver separate finger events. Deliver both before the next frame,
	# so tests exercise a real parallel drag instead of two independent pinches.
	for movement in [[0, first_from, first_to], [1, second_from, second_to]]:
		var event := InputEventScreenDrag.new()
		event.index = int(movement[0])
		event.position = movement[2]
		event.relative = movement[2] - movement[1]
		Input.parse_input_event(event)
	await _frame()


func _orbit_touch_pair(distance: float) -> void:
	var first := Vector2(260, 640)
	var second := Vector2(380, 640)
	await _touch(0, first, true)
	await _touch(1, second, true)
	for step in range(6):
		var movement := Vector2(distance / 6.0, 0)
		await _drag_touch_pair(first, first + movement, second, second + movement)
		first += movement
		second += movement
	await _touch(0, first, false)
	await _touch(1, second, false)


func _slot_point(index: int) -> Vector2:
	return _game.camera_controller.camera.unproject_position(
		_game.map.slots[index].global_position + Vector3(0, 0.12, 0)
	)


func _inside(control: Control) -> bool:
	var rect := control.get_global_rect()
	var viewport_size := root.get_visible_rect().size
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 \
		and rect.end.x <= viewport_size.x + 1.0 and rect.end.y <= viewport_size.y + 1.0


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func():
		push_error("Input verification timed out before reporting completion.")
		quit(124)
	)
	# Equal window/canvas coordinates make synthetic desktop events deterministic.
	root.size = Vector2i(720, 1280)
	_game = load("res://scenes/main/main.tscn").instantiate() as FortGame
	root.add_child(_game)
	await physics_frame
	await _frame()
	var cam := _game.camera_controller
	var hud := _game.hud
	_check(hud._gold_value.text == "300" and hud._health_value.text == "20", "HUD initial state")

	await _mouse_tap(_slot_point(2))
	_check(_game.selected_slot == _game.map.slots[2], "Mouse tap raycasts the requested slot")
	_check(not _game.map.slots[2].occupied and _game.economy.gold == 300, "Selection alone never builds")
	_check(hud._context.visible and not hud._context_action.disabled, "Affordable build panel appears")
	await _mouse_tap(hud._context_action.get_global_rect().get_center())
	_check(_game.map.slots[2].occupied and _game.economy.gold == 200, "GUI mouse build purchases once")
	_check(hud._context_title.text.contains("Nivel 1"), "HUD reflects construction")
	await _touch_tap(hud._context_action.get_global_rect().get_center())
	_check(_game.map.slots[2].tower.level == 2 and _game.economy.gold == 75, "GUI touch upgrade purchases once")
	_check(hud._context_action.disabled and hud._context_hint.text.contains("125"), "Unaffordable next upgrade disabled")
	_game.economy.add_gold(200)
	await _frame()
	await _touch_tap(hud._context_action.get_global_rect().get_center())
	_check(_game.map.slots[2].tower.level == 3 and hud._context_action.disabled, "HUD exposes max level")
	_game.restart_game()
	await _frame()

	var point := _slot_point(2)
	await _drag_mouse(point, point + Vector2(110, 25))
	_check(_game.selected_slot == null, "Mouse camera drag never selects or builds")
	_check(cam.position.length() > 0.01, "Mouse drag pans camera")
	_check(not cam._mouse_down, "Mouse gesture ends on release")
	cam.reset_view()
	await _touch_tap(_slot_point(2))
	_check(_game.selected_slot == _game.map.slots[2], "Touch tap selects exactly one slot")
	_check(not _game.map.slots[2].occupied, "Touch selection does not build")
	_game.clear_selection()
	await _frame()

	point = _slot_point(2)
	await _touch(0, point, true)
	await _drag_touch(0, point, point + Vector2(100, 20))
	await _touch(0, point + Vector2(100, 20), false)
	_check(_game.selected_slot == null and cam.position.length() > 0.01, "One finger drag pans without selection")
	cam.reset_view()
	var first := Vector2(300, 640)
	var second := Vector2(420, 640)
	await _touch(0, first, true)
	await _touch(1, second, true)
	var old_zoom := cam.camera.size
	var orientation_before_pinch := cam.camera.global_basis
	await _drag_touch(1, second, second + Vector2(100, 0))
	await _touch(0, first, false)
	await _touch(1, second + Vector2(100, 0), false)
	_check(cam.camera.size < old_zoom, "Two finger pinch zooms")
	_check(cam.camera.global_basis.is_equal_approx(orientation_before_pinch), "Pinch with one stationary finger does not rotate the view")
	_check(_game.selected_slot == null, "Pinch release never selects")
	_check(cam._touches.is_empty(), "All touch state clears after pinch")
	cam.reset_view()
	await _test_two_finger_rotation()

	point = hud._gold_value.get_global_rect().get_center()
	await _drag_mouse(point, Vector2(360, 640))
	_check(cam.position == Vector3.ZERO and _game.selected_slot == null, "Drag started on HUD cannot pan or select")
	await _touch_tap(hud._pause_button.get_global_rect().get_center())
	_check(paused and hud._overlay.visible, "Touch pause button responds")
	_check(cam.position == Vector3.ZERO and cam._touches.is_empty(), "UI touch does not activate camera")
	await _touch_tap(hud._resume_button.get_global_rect().get_center())
	_check(not paused and not hud._overlay.visible, "Touch resume works while game is paused")

	_game._finish(false)
	await _frame()
	_check(hud._overlay.visible and not hud._resume_button.visible, "Result overlay blocks gameplay")
	await _touch_tap(hud._restart_button.get_global_rect().get_center())
	_check(not paused and _game.state == "playing" and not hud._overlay.visible, "Touch restart clears result and pause")
	_check(_game.economy.gold == 300 and _game.castle.health == 20, "Restart restores HUD data source")

	for window_size in [Vector2i(390, 844), Vector2i(768, 1024), Vector2i(1024, 768)]:
		root.size = window_size
		await _frame()
		_game.select_slot(_game.map.slots[2])
		await _frame()
		_check(_inside(hud._wave_button) and _inside(hud._context_action), "Bottom actions inside " + str(window_size))
		_check(_inside(hud._pause_button) and _inside(hud._context), "Context and pause inside " + str(window_size))
		_check(hud._safe_top.get_global_rect().end.y < hud._safe_bottom.get_global_rect().position.y, "HUD leaves a world interaction area " + str(window_size))
		if window_size.x == 390:
			var canvas_scale := root.get_final_transform().get_scale()
			_check(hud._pause_button.size.y * canvas_scale.y >= 44.0, "Pause target is at least 44 pixels on 390-wide window")
			_check(hud._context_action.size.y * canvas_scale.y >= 44.0, "Build target is at least 44 pixels on 390-wide window")
		_game.clear_selection()
	_game.queue_free()
	await _frame()
	print("INPUT TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_two_finger_rotation() -> void:
	var cam := _game.camera_controller
	var initial_view := cam.camera.global_transform
	var initial_pivot := cam.global_position
	var initial_zoom := cam.camera.size
	var initial_radius := cam.camera.global_position.distance_to(initial_pivot)
	await _orbit_touch_pair(120.0)
	_check(not cam.camera.global_basis.is_equal_approx(initial_view.basis), "Dragging two fingers horizontally rotates the real camera")
	_check(cam.global_position.is_equal_approx(initial_pivot), "Two-finger orbit keeps the map's viewing pivot fixed")
	_check(is_equal_approx(cam.camera.size, initial_zoom), "Parallel finger movement does not accidentally pinch-zoom")
	_check(is_equal_approx(cam.camera.global_position.y, initial_view.origin.y)
		and is_equal_approx(cam.camera.global_position.distance_to(cam.global_position), initial_radius), "Orbit preserves camera elevation and distance from its pivot")
	_check(_game.selected_slot == null and _game.economy.gold == 300, "Releasing an orbit cannot select or purchase a tower")
	_check(cam._touches.is_empty(), "Both fingers are cleared after orbit release")

	# Raycasting and world-space panning must follow the newly oriented camera.
	await physics_frame
	await _touch_tap(_slot_point(2))
	_check(_game.selected_slot == _game.map.slots[2], "Tap raycasts the intended slot after rotating the view")
	_game.clear_selection()
	await _frame()
	var rotated_basis := cam.camera.global_basis
	var pivot_before_pan := cam.global_position
	var pan_start := Vector2(360, 640)
	await _touch(0, pan_start, true)
	await _drag_touch(0, pan_start, pan_start + Vector2(70, 20))
	await _touch(0, pan_start + Vector2(70, 20), false)
	_check(not cam.global_position.is_equal_approx(pivot_before_pan)
		and cam.camera.global_basis.is_equal_approx(rotated_basis), "One-finger drag pans at the rotated angle without changing it")
	_check(_game.selected_slot == null, "Panning after orbit never selects a slot")
	cam.reset_view()
	_check(cam.camera.global_transform.is_equal_approx(initial_view)
		and is_equal_approx(cam.camera.size, initial_zoom), "Reset restores the original viewing angle, pivot and zoom")

	# Finger callbacks may straddle frames; common movement must not be lost.
	var separated_first := Vector2(260, 640)
	var separated_second := Vector2(380, 640)
	await _touch(0, separated_first, true)
	await _touch(1, separated_second, true)
	for step in range(5):
		var movement := Vector2(16, 0)
		await _drag_touch(0, separated_first, separated_first + movement)
		separated_first += movement
		await _drag_touch(1, separated_second, separated_second + movement)
		separated_second += movement
	await _touch(0, separated_first, false)
	await _touch(1, separated_second, false)
	_check(not cam.camera.global_basis.is_equal_approx(initial_view.basis), "Parallel finger events arriving on different frames still rotate")
	_check(is_equal_approx(cam.camera.size, initial_zoom), "Interleaved parallel finger events leave the final zoom unchanged")
	_check(cam.global_position.is_equal_approx(initial_pivot), "Interleaved parallel movement cannot accumulate unintended camera pan")
	_check(_game.selected_slot == null and cam._touches.is_empty(), "Interleaved orbit releases both fingers without selection")
	cam.reset_view()

	# A temporary distance change between finger callbacks can hit the zoom
	# clamp. Completing the parallel drag must still restore the starting zoom.
	var zoom_first := Vector2(300, 640)
	var zoom_second := Vector2(420, 640)
	await _touch(0, zoom_first, true)
	await _touch(1, zoom_second, true)
	await _drag_touch(1, zoom_second, zoom_first + Vector2(8, 0))
	await _touch(0, zoom_first, false)
	await _touch(1, zoom_first + Vector2(8, 0), false)
	_check(is_equal_approx(cam.camera.size, FortCamera.MAX_ZOOM), "Pinching inward reaches the maximum camera zoom bound")
	var zoom_bound := cam.camera.size
	var zoom_bound_pivot := cam.global_position
	separated_first = Vector2(260, 640)
	separated_second = Vector2(380, 640)
	await _touch(0, separated_first, true)
	await _touch(1, separated_second, true)
	await _drag_touch(0, separated_first, separated_first + Vector2(30, 0))
	await _drag_touch(1, separated_second, separated_second + Vector2(30, 0))
	await _touch(0, separated_first + Vector2(30, 0), false)
	await _touch(1, separated_second + Vector2(30, 0), false)
	_check(is_equal_approx(cam.camera.size, zoom_bound), "Parallel orbit at the zoom limit does not lose zoom through an intermediate clamp")
	_check(cam.global_position.is_equal_approx(zoom_bound_pivot), "Orbit at the zoom limit preserves its viewing pivot")
	cam.reset_view()

	# Pinching and orbiting may occur during one continuous two-finger gesture.
	var combined_first := Vector2(260, 640)
	var combined_second := Vector2(380, 640)
	await _touch(0, combined_first, true)
	await _touch(1, combined_second, true)
	await _drag_touch(0, combined_first, combined_first + Vector2(60, 0))
	combined_first += Vector2(60, 0)
	var after_pinch_basis := cam.camera.global_basis
	var after_pinch_zoom := cam.camera.size
	await _drag_touch_pair(combined_first, combined_first + Vector2(20, 0), combined_second, combined_second + Vector2(20, 0))
	combined_first += Vector2(20, 0)
	combined_second += Vector2(20, 0)
	_check(not cam.camera.global_basis.is_equal_approx(after_pinch_basis), "A pinch can transition into orbit without lifting either finger")
	var positive_heading := Vector3(cam.camera.global_basis.z.x, 0, cam.camera.global_basis.z.z)
	var original_heading := Vector3(after_pinch_basis.z.x, 0, after_pinch_basis.z.z)
	var positive_angle := original_heading.signed_angle_to(positive_heading, Vector3.UP)
	await _drag_touch_pair(combined_first, combined_first - Vector2(20, 0), combined_second, combined_second - Vector2(20, 0))
	combined_first -= Vector2(20, 0)
	combined_second -= Vector2(20, 0)
	await _touch(0, combined_first, false)
	await _touch(1, combined_second, false)
	_check(cam.camera.global_basis.is_equal_approx(after_pinch_basis)
		and is_equal_approx(cam.camera.size, after_pinch_zoom), "Reversing orbit after a pinch restores the prior angle and zoom")
	cam.reset_view()
	combined_first = Vector2(260, 640)
	combined_second = Vector2(380, 640)
	await _touch(0, combined_first, true)
	await _touch(1, combined_second, true)
	await _drag_touch(0, combined_first, combined_first + Vector2(60, 0))
	combined_first += Vector2(60, 0)
	await _drag_touch_pair(combined_first, combined_first - Vector2(20, 0), combined_second, combined_second - Vector2(20, 0))
	var negative_heading := Vector3(cam.camera.global_basis.z.x, 0, cam.camera.global_basis.z.z)
	_check(original_heading.signed_angle_to(negative_heading, Vector3.UP) * positive_angle < 0.0, "A pinch can transition directly into orbit in the opposite direction")
	await _touch(0, combined_first - Vector2(20, 0), false)
	await _touch(1, combined_second - Vector2(20, 0), false)
	cam.reset_view()

	# Releasing just one finger ends rotation cleanly and never produces a tap.
	var first := Vector2(260, 640)
	var second := Vector2(380, 640)
	await _touch(0, first, true)
	await _touch(1, second, true)
	await _drag_touch_pair(first, first + Vector2(80, 0), second, second + Vector2(80, 0))
	first += Vector2(80, 0)
	second += Vector2(80, 0)
	var before_partial_release := cam.camera.global_transform
	await _touch(0, first, false)
	_check(cam.camera.global_transform.is_equal_approx(before_partial_release)
		and _game.selected_slot == null, "Releasing the first orbit finger causes neither a camera jump nor selection")
	await _drag_touch(1, second, second + Vector2(30, 10))
	await _touch(1, second + Vector2(30, 10), false)
	_check(cam.camera.global_basis.is_equal_approx(before_partial_release.basis)
		and _game.selected_slot == null, "Remaining finger cannot continue orbit or turn its release into a tap")
	cam.reset_view()

	# A paused game discards an in-progress gesture, including deferred movement.
	first = Vector2(260, 640)
	second = Vector2(380, 640)
	await _touch(0, first, true)
	await _touch(1, second, true)
	await _drag_touch_pair(first, first + Vector2(60, 0), second, second + Vector2(60, 0))
	first += Vector2(60, 0)
	second += Vector2(60, 0)
	_game.set_paused(true)
	var paused_view := cam.camera.global_transform
	await _drag_touch_pair(first, first + Vector2(30, 0), second, second + Vector2(30, 0))
	await _touch(0, first + Vector2(30, 0), false)
	await _touch(1, second + Vector2(30, 0), false)
	_check(cam.camera.global_transform.is_equal_approx(paused_view) and cam._touches.is_empty(), "Pause freezes orbit and clears fingers held on the map")
	_game.set_paused(false)
	await _frame()
	_check(cam.camera.global_transform.is_equal_approx(paused_view), "Resuming cannot apply stale two-finger movement")
	cam.reset_view()

	# Both touches begin on non-button HUD content, which must consume them.
	first = Vector2(200, 150)
	second = Vector2(400, 150)
	await _touch(0, first, true)
	await _touch(1, second, true)
	await _drag_touch_pair(first, first + Vector2(70, 0), second, second + Vector2(70, 0))
	await _touch(0, first + Vector2(70, 0), false)
	await _touch(1, second + Vector2(70, 0), false)
	_check(cam.camera.global_transform.is_equal_approx(initial_view)
		and cam._touches.is_empty(), "Two-finger gesture started over the HUD cannot rotate the map")
	_check(_game.selected_slot == null and _game.economy.gold == 300, "HUD gesture cannot select or buy behind the interface")
	cam.reset_view()

	await _drag_right_mouse(Vector2(360, 640), Vector2(460, 640))
	_check(not cam.camera.global_basis.is_equal_approx(initial_view.basis), "Right mouse drag offers desktop orbit control")
	_check(cam.global_position.is_equal_approx(initial_pivot)
		and is_equal_approx(cam.camera.size, initial_zoom), "Desktop orbit changes neither pan nor zoom")
	_check(_game.selected_slot == null, "Right mouse orbit never selects a build slot")
	cam.reset_view()
	await _drag_right_mouse(Vector2(200, 150), Vector2(280, 150))
	_check(cam.camera.global_transform.is_equal_approx(initial_view), "Right drag started over HUD cannot rotate the map")

	await _mouse(Vector2(360, 640), true, MOUSE_BUTTON_RIGHT)
	await _mouse(Vector2(200, 150), false, MOUSE_BUTTON_RIGHT)
	var view_after_hud_release := cam.camera.global_transform
	var unpressed_motion := InputEventMouseMotion.new()
	unpressed_motion.position = Vector2(440, 640)
	unpressed_motion.global_position = unpressed_motion.position
	unpressed_motion.relative = Vector2(80, 0)
	Input.parse_input_event(unpressed_motion)
	await _frame()
	_check(cam.camera.global_transform.is_equal_approx(view_after_hud_release), "Right mouse released over HUD cannot leave orbit stuck on")
	cam.reset_view()
