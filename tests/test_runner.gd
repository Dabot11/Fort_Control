extends SceneTree
## Integration checks against the real scene and gameplay classes; no addons required.

var checks := 0
var failures: Array[String] = []
var groups := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("FAIL: " + description)


func _group(description: String) -> void:
	groups += 1
	print("TEST ", groups, ": ", description)


func _new_game() -> FortGame:
	var scene := load("res://scenes/main/main.tscn") as PackedScene
	_check(scene != null, "main scene loads")
	var game := scene.instantiate() as FortGame
	root.add_child(game)
	return game


func _dispose_game(game: FortGame) -> void:
	paused = false
	game.queue_free()
	await process_frame


func _run() -> void:
	# A runtime script error must fail CI instead of leaving a silent, hung process.
	create_timer(60.0, true, false, true).timeout.connect(func():
		push_error("Test suite timed out before reporting completion.")
		quit(124)
	)
	await _test_scene_and_map()
	await _test_enemy_movement_and_death()
	await _test_enemy_escape()
	await _test_build_and_economy()
	await _test_upgrades()
	await _test_projectiles_and_targeting()
	await _test_rewards_and_castle()
	await _test_wave_lifecycle()
	await _test_victory()
	await _test_defeat()
	await _test_pause_and_restart()
	print("\nFORT CONTROL TEST RESULTS: ", groups, " groups, ", checks, " checks, ", failures.size(), " failures")
	if failures.is_empty():
		print("PASS: all checks executed successfully.")
		quit(0)
	else:
		for failure in failures:
			print("  FAIL: ", failure)
		quit(1)


func _test_scene_and_map() -> void:
	_group("main scene, initial state and map data")
	var game := _new_game()
	_check(game.state == "playing", "initial state is playing")
	_check(game.economy.gold == 300, "initial gold is 300")
	_check(game.castle.health == 20, "initial castle health is 20")
	_check(game.waves.total_waves == 5, "five waves configured")
	_check(game.map.slots.size() == 8, "eight build slots generated")
	_check(game.map.waypoints.size() >= 2, "real path has multiple waypoints")
	_check(game.get_viewport().get_camera_3d() != null, "main scene has active 3D camera")
	var unique_positions: Array[Vector3] = []
	for slot in game.map.slots:
		_check(not unique_positions.has(slot.global_position), "slot positions are unique")
		unique_positions.append(slot.global_position)
		var on_path := false
		for point in game.map.waypoints:
			if Vector2(point.x, point.z).distance_to(Vector2(slot.global_position.x, slot.global_position.z)) < 0.1:
				on_path = true
		_check(not on_path, "build slot does not intersect path")
		_check((slot.collision_layer & 2) != 0, "slot supports selection raycast")
	await _dispose_game(game)


func _test_enemy_movement_and_death() -> void:
	_group("enemy movement, damage and one terminal death event")
	var enemy := FortEnemy.new()
	var path: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -2), Vector3(2, 0, -2)]
	var events := {"killed": 0, "escaped": 0}
	enemy.configure(path, {"health": 40.0, "speed": 1.0}, 25, 1)
	enemy.killed.connect(func(_enemy): events.killed += 1)
	enemy.escaped.connect(func(_enemy): events.escaped += 1)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._physics_process(0.5)
	_check(is_equal_approx(enemy.progress, 0.5), "enemy advances by speed times delta")
	_check(enemy.global_position.is_equal_approx(Vector3(0, 0, -0.5)), "enemy follows first segment")
	enemy._physics_process(2.0)
	_check(enemy.global_position.is_equal_approx(Vector3(0.5, 0, -2)), "enemy turns and consumes remaining segment distance")
	enemy.take_damage(12.0)
	_check(is_equal_approx(enemy.health, 28.0), "damage reduces actual health")
	enemy.take_damage(100.0)
	enemy.take_damage(100.0)
	enemy._physics_process(100.0)
	_check(events.killed == 1, "death emits exactly once")
	_check(events.escaped == 0, "dead enemy cannot escape")
	_check(not enemy.is_targetable(), "dead enemy is no longer targetable")
	await process_frame


func _test_enemy_escape() -> void:
	_group("castle arrival emits once and never counts as a kill")
	var enemy := FortEnemy.new()
	var path: Array[Vector3] = [Vector3.ZERO, Vector3(1, 0, 0)]
	var events := {"killed": 0, "escaped": 0}
	root.add_child(enemy)
	enemy.configure(path, {"health": 40.0, "speed": 1.0}, 25, 1)
	enemy.set_physics_process(false)
	enemy.killed.connect(func(_enemy): events.killed += 1)
	enemy.escaped.connect(func(_enemy): events.escaped += 1)
	enemy._physics_process(2.0)
	enemy._physics_process(2.0)
	enemy.take_damage(100.0)
	_check(events.escaped == 1, "arrival emits exactly once")
	_check(events.killed == 0, "escaped enemy cannot subsequently die")
	_check(not enemy.is_targetable(), "escaped enemy is no longer targetable")
	await process_frame


func _test_build_and_economy() -> void:
	_group("valid and invalid construction, affordability and gold invariants")
	var game := _new_game()
	var slot := game.map.slots[0]
	_check(game.build_tower(slot), "valid build succeeds")
	_check(slot.occupied and is_instance_valid(slot.tower), "slot owns built tower")
	_check(game.economy.gold == 200, "construction deducts exactly 100")
	_check(not game.build_tower(slot), "duplicate tower is rejected")
	_check(game.economy.gold == 200, "duplicate build does not charge gold")
	var outsider := FortBuildSlot.new()
	_check(not game.build_tower(outsider), "unregistered build slot is rejected")
	_check(not game.build_tower(null), "null build slot is rejected")
	outsider.free()
	_check(game.build_tower(game.map.slots[1]), "second construction succeeds")
	_check(game.build_tower(game.map.slots[2]), "third construction succeeds")
	_check(game.economy.gold == 0, "spending exact balance is supported")
	_check(not game.build_tower(game.map.slots[3]), "insufficient funds prevent construction")
	_check(not game.map.slots[3].occupied, "failed build leaves slot available")
	_check(not game.economy.try_spend(-50), "negative purchase is rejected")
	_check(not game.economy.try_spend(1), "cannot overspend economy")
	_check(game.economy.gold == 0, "gold remains zero after invalid purchases")
	await _dispose_game(game)


func _test_upgrades() -> void:
	_group("upgrade costs, maximum level and invalid upgrades")
	var game := _new_game()
	var slot := game.map.slots[0]
	_check(not game.upgrade_tower(slot), "empty slot cannot upgrade")
	game.build_tower(slot)
	var initial_damage: float = slot.tower.stats().damage
	_check(game.upgrade_tower(slot), "level two purchase succeeds")
	_check(slot.tower.level == 2 and game.economy.gold == 75, "level two costs 125")
	_check(float(slot.tower.stats().damage) > initial_damage, "upgrade increases damage")
	_check(not game.upgrade_tower(slot), "insufficient gold prevents level three")
	_check(slot.tower.level == 2 and game.economy.gold == 75, "failed upgrade leaves level and gold intact")
	game.economy.add_gold(125)
	_check(game.upgrade_tower(slot), "level three purchase succeeds")
	_check(slot.tower.level == 3 and game.economy.gold == 0, "level three costs 200")
	game.economy.add_gold(500)
	_check(not game.upgrade_tower(slot), "level four is rejected")
	_check(slot.tower.level == 3 and game.economy.gold == 500, "maximum-level attempt does not charge")
	await _dispose_game(game)


func _test_projectiles_and_targeting() -> void:
	_group("tower prioritizes advanced enemies; projectile hits once and handles freed targets")
	var game := _new_game()
	var slot := game.map.slots[0]
	game.build_tower(slot)
	var tower := slot.tower as FortTower
	tower.set_physics_process(false)
	var targets: Array[FortEnemy] = []
	for index in range(2):
		var enemy := FortEnemy.new()
		var origin := tower.global_position + Vector3(1.0, 0, 0)
		var path: Array[Vector3] = [origin, origin + Vector3(0, 0, -1)]
		enemy.configure(path, {"health": 500.0, "speed": 0.0}, 25, 1)
		game.enemies_root.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.progress = float(index + 1)
		targets.append(enemy)
	_check(tower.select_target() == targets[1], "tower picks most advanced target in range")
	tower._physics_process(1.0)
	_check(game.projectiles_root.get_child_count() == 1, "tower spawns visible projectile")
	if game.projectiles_root.get_child_count() > 0:
		var projectile := game.projectiles_root.get_child(0) as FortProjectile
		projectile.set_physics_process(false)
		projectile._physics_process(1.0)
		projectile._physics_process(1.0)
		_check(is_equal_approx(targets[1].health, 500.0 - float(tower.stats().damage)), "projectile damage is applied exactly once")
		_check(is_equal_approx(targets[0].health, 500.0), "non-target enemy is unharmed")
	var orphan := FortProjectile.new()
	orphan.configure(targets[0], 50.0, 15.0)
	game.projectiles_root.add_child(orphan)
	orphan.set_physics_process(false)
	targets[0].free()
	orphan._physics_process(0.1)
	_check(orphan.is_queued_for_deletion(), "projectile safely retires when its target is freed")
	await _dispose_game(game)


func _test_rewards_and_castle() -> void:
	_group("real spawned enemies reward once or damage castle once")
	var game := _new_game()
	game.start_wave()
	var enemy := game.enemies_root.get_child(0) as FortEnemy
	enemy.set_physics_process(false)
	enemy.take_damage(10000.0)
	game._on_enemy_killed(enemy)
	game._on_enemy_escaped(enemy)
	_check(game.economy.gold == 325, "one killed skeleton rewards exactly 25 despite duplicate callbacks")
	_check(game.castle.health == 20, "killed skeleton never damages castle")
	game.waves._process(2.0)
	var runner: FortEnemy
	for child in game.enemies_root.get_children():
		if child is FortEnemy and child.is_targetable():
			runner = child
			break
	_check(runner != null, "next enemy actually spawns")
	if runner != null:
		runner.set_physics_process(false)
		runner._physics_process(1000.0)
		game._on_enemy_escaped(runner)
		game._on_enemy_killed(runner)
		_check(game.castle.health == 19, "one escaped skeleton causes exactly one damage")
		_check(game.economy.gold == 325, "escaped skeleton grants no kill reward")
	await _dispose_game(game)


func _test_wave_lifecycle() -> void:
	_group("concurrent wave prevention and spawning/living completion gates")
	var game := _new_game()
	_check(game.start_wave(), "first wave starts")
	_check(not game.start_wave(), "cannot overlap active waves")
	_check(game.waves.current_wave == 1, "duplicate start does not advance index")
	_check(game.waves.pending_count > 0, "wave has scheduled future enemies")
	var first := game.enemies_root.get_child(0) as FortEnemy
	first.take_damage(10000.0)
	_check(game.waves.active, "wave stays active while unspawned enemies remain")
	game.waves._process(100.0)
	_check(game.waves.pending_count == 0, "spawn schedule drains fully")
	_check(game.waves.active, "wave stays active while living enemies remain")
	for child in game.enemies_root.get_children():
		if child is FortEnemy and child.is_targetable():
			child.take_damage(10000.0)
	_check(not game.waves.active, "wave completes after pending and living counts reach zero")
	_check(game.state == "playing", "finishing first wave does not win game")
	_check(game.economy.gold == 450, "all six first-wave kills award gold")
	_check(game.start_wave() and game.waves.current_wave == 2, "next wave starts only after prior completion")
	await _dispose_game(game)


func _test_victory() -> void:
	_group("five full waves, no early victory and last-enemy completion")
	var game := _new_game()
	for number in range(1, 6):
		_check(game.start_wave(), "wave %d starts" % number)
		game.waves._process(100.0)
		var living: Array[FortEnemy] = []
		for child in game.enemies_root.get_children():
			if child is FortEnemy and child.is_targetable():
				living.append(child)
		_check(living.size() == int(game.wave_data[number - 1].count), "wave %d spawns configured count" % number)
		for index in range(living.size() - 1):
			living[index].take_damage(10000.0)
		_check(game.state == "playing" and game.waves.active, "wave %d cannot win/end with last enemy alive" % number)
		living.back().take_damage(10000.0)
		if number < 5:
			_check(game.state == "playing", "victory waits for all five waves")
	_check(game.state == "victory", "fifth wave's final kill triggers victory")
	_check(not game.start_wave(), "no sixth wave after victory")
	_check(not game.build_tower(game.map.slots[0]), "building is disabled after victory")
	await _dispose_game(game)


func _test_defeat() -> void:
	_group("castle loss ends gameplay and freezes remaining enemies")
	var game := _new_game()
	game.start_wave()
	game.waves._process(100.0)
	game.castle.take_damage(19)
	var runner := game.enemies_root.get_child(0) as FortEnemy
	runner._physics_process(1000.0)
	_check(game.castle.health == 0, "last leak removes final castle health")
	_check(game.state == "defeat", "zero health triggers defeat")
	_check(not game.start_wave(), "waves cannot start after defeat")
	_check(not game.build_tower(game.map.slots[0]), "construction is disabled after defeat")
	var survivor := game.enemies_root.get_child(1) as FortEnemy
	var old_position := survivor.global_position
	await physics_frame
	await physics_frame
	_check(survivor.global_position.is_equal_approx(old_position), "defeat stops surviving enemy motion")
	game.castle.take_damage(5)
	_check(game.castle.health == 0, "castle health never becomes negative")
	await _dispose_game(game)


func _test_pause_and_restart() -> void:
	_group("pause/resume and complete restart from modified state")
	var game := _new_game()
	var slot := game.map.slots[0]
	game.build_tower(slot)
	game.upgrade_tower(slot)
	game.select_slot(slot)
	game.start_wave()
	game.castle.take_damage(7)
	game.set_paused(true)
	_check(paused, "pause stops SceneTree gameplay")
	game.set_paused(false)
	_check(not paused, "resume restores SceneTree processing")
	game.set_paused(true)
	game.restart_game()
	_check(not paused, "restart also clears pause")
	_check(game.state == "playing", "restart restores playing state")
	_check(game.economy.gold == 300 and game.castle.health == 20, "restart restores economy and castle")
	_check(game.waves.current_wave == 0 and not game.waves.active, "restart resets wave index and activity")
	_check(game.enemies_root.get_child_count() == 0, "restart removes all enemies")
	_check(game.projectiles_root.get_child_count() == 0, "restart removes all projectiles")
	_check(game.towers_root.get_child_count() == 0, "restart removes all towers")
	_check(game.selected_slot == null, "restart clears selection")
	for available_slot in game.map.slots:
		_check(not available_slot.occupied and not is_instance_valid(available_slot.tower), "restart frees each build slot")
	_check(game.start_wave(), "new match can start wave one")
	await _dispose_game(game)
