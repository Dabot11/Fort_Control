extends SceneTree
## Real movement, tower targeting, projectile hits and purchases. No direct damage.

var game: FortGame
var history: Array = []
var purchases: Array[String] = []
var mode := "strategy"
var failed := false


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error("GAMEPLAY FAIL: " + description)


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		mode = arguments[0]
	if mode not in ["first_one", "strategy"]:
		push_error("Mode must be first_one or strategy")
		quit(2)
		return
	# Ten times real time, preserving the normal 1/60 simulated physics timestep.
	Engine.physics_ticks_per_second = 600
	Engine.max_physics_steps_per_frame = 128
	Engine.time_scale = 10.0
	create_timer(120.0, true, false, true).timeout.connect(func():
		push_error("Gameplay verification exceeded its real-time limit")
		quit(124)
	)
	game = load("res://scenes/main/main.tscn").instantiate() as FortGame
	root.add_child(game)
	await process_frame
	if mode == "first_one":
		_check(_buy(5), "initial single tower can be purchased")
	else:
		for index in [2, 3, 5]:
			_check(_buy(index), "initial defense can be purchased")
	var started := Time.get_ticks_msec()
	_check(game.start_wave(), "first wave starts")
	while game.state == "playing" and Time.get_ticks_msec() - started < 90000:
		await process_frame
		if game.state != "playing":
			break
		if not game.waves.active:
			_record_wave()
			if mode == "first_one":
				break
			_shop()
			_check(game.start_wave(), "subsequent wave starts")
	_record_wave()
	_check(Time.get_ticks_msec() - started < 90000, "simulation completes before timeout")
	if mode == "first_one":
		_check(game.waves.current_wave == 1 and not game.waves.active, "single tower completes wave one")
		_check(game.castle.health == 20, "single-tower first wave has no leaks")
		_check(game.economy.gold == 350, "six genuine kills grant expected rewards")
	else:
		_check(game.state == "victory", "planned purchases win all five waves")
		_check(game.waves.current_wave == 5 and not game.waves.active, "all five waves complete")
		_check(game.waves.pending_count == 0 and game.waves.living_count == 0, "victory has no unresolved enemies")
		_check(game.castle.health > 0, "castle survives the real battle")
	print("GAMEPLAY_RESULT ", JSON.stringify({
		"mode": mode, "state": game.state, "history": history,
		"purchases": purchases, "wall_ms": Time.get_ticks_msec() - started,
		"passed": not failed,
	}))
	paused = false
	game.free()
	await process_frame
	quit(1 if failed else 0)


func _record_wave() -> void:
	if not history.is_empty() and history.back().wave == game.waves.current_wave:
		return
	history.append({
		"wave": game.waves.current_wave,
		"health": game.castle.health,
		"gold": game.economy.gold,
		"towers": game.towers_root.get_child_count(),
	})


func _buy(index: int) -> bool:
	if game.build_tower(game.map.slots[index]):
		purchases.append("build:%d" % index)
		return true
	return false


func _shop() -> void:
	# Use the same gameplay API as buttons, spending only earned gold between waves.
	for index in [3, 5, 2]:
		var slot: FortBuildSlot = game.map.slots[index]
		if slot.occupied and slot.tower.level == 1:
			if game.upgrade_tower(slot):
				purchases.append("upgrade2:%d" % index)
	for index in [3, 5, 2]:
		var slot: FortBuildSlot = game.map.slots[index]
		if slot.occupied and slot.tower.level == 2:
			if game.upgrade_tower(slot):
				purchases.append("upgrade3:%d" % index)
	for index in [4, 7, 1, 6, 0]:
		if not game.map.slots[index].occupied:
			_buy(index)
