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


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
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


func _drag_touch(index: int, from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = to
	event.relative = to - from
	Input.parse_input_event(event)
	await _frame()


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
	await _drag_touch(1, second, second + Vector2(100, 0))
	await _touch(0, first, false)
	await _touch(1, second + Vector2(100, 0), false)
	_check(cam.camera.size < old_zoom, "Two finger pinch zooms")
	_check(_game.selected_slot == null, "Pinch release never selects")
	_check(cam._touches.is_empty(), "All touch state clears after pinch")
	cam.reset_view()

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
