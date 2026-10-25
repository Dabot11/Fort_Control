class_name FortGame
extends Node3D
## Composition root: owns a match without singleton or absolute-node dependencies.

const ENEMY_SCENE = preload("res://scenes/enemies/skeleton.tscn")
const TOWER_SCENE = preload("res://scenes/towers/crossbow.tscn")

var balance: Dictionary = {}
var wave_data: Array = []
var map_data: Dictionary = {}
var map: FortMap
var economy: FortEconomy
var castle: FortCastle
var waves: FortWaveManager
var camera_controller: FortCamera
var hud: FortHUD
var enemies_root: Node3D
var projectiles_root: Node3D
var towers_root: Node3D
var feedback: FortFeedback
var range_indicator: FortRangeIndicator
var selected_slot: FortBuildSlot
var state: String = "playing"
var _active_enemies: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	balance = _read_json("res://resources/balance/default.json")
	wave_data = _read_json("res://resources/waves/default.json")
	map_data = _read_json("res://resources/maps/meadow.json")
	assert(balance.get("tower_levels", []).size() == 3, "Se requieren tres niveles de torre")
	assert(not wave_data.is_empty(), "Faltan las oleadas")

	map = FortMap.new()
	map.name = "Map"
	map.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(map)
	map.setup(map_data)
	enemies_root = _world_container("Enemies")
	projectiles_root = _world_container("Projectiles")
	towers_root = _world_container("Towers")
	feedback = FortFeedback.new()
	feedback.name = "Feedback"
	feedback.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(feedback)
	range_indicator = FortRangeIndicator.new()
	range_indicator.name = "TowerRange"
	range_indicator.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(range_indicator)

	economy = FortEconomy.new()
	economy.name = "Economy"
	add_child(economy)
	castle = FortCastle.new()
	castle.name = "CastleHealth"
	add_child(castle)
	waves = FortWaveManager.new()
	waves.name = "Waves"
	waves.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(waves)
	waves.configure(wave_data)

	camera_controller = FortCamera.new()
	camera_controller.name = "CameraController"
	camera_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(camera_controller)
	camera_controller.setup(map.world_bounds)
	hud = FortHUD.new()
	hud.name = "HUD"
	add_child(hud)
	_connect_signals()
	economy.reset(int(balance["initial_gold"]))
	castle.reset(int(balance["castle_health"]))
	_refresh_hud()
	hud.show_message("Toca un + y construye tu primera ballesta.")


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "No se puede leer " + path)
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	assert(error == OK, "JSON inválido: " + path + ": " + json.get_error_message())
	return json.data


func _world_container(node_name: String) -> Node3D:
	var container := Node3D.new()
	container.name = node_name
	container.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(container)
	return container


func _connect_signals() -> void:
	economy.gold_changed.connect(func(_value: int) -> void: _refresh_hud())
	castle.health_changed.connect(func(_value: int) -> void: _refresh_hud())
	castle.destroyed.connect(func() -> void: _finish(false))
	waves.spawn_requested.connect(_spawn_enemy)
	waves.wave_started.connect(func(_number: int) -> void: _refresh_hud())
	waves.wave_completed.connect(_on_wave_completed)
	waves.all_waves_completed.connect(_on_all_waves_completed)
	camera_controller.slot_selected.connect(select_slot)
	camera_controller.selection_cleared.connect(clear_selection)
	hud.start_wave_requested.connect(start_wave)
	hud.pause_requested.connect(func() -> void: set_paused(true))
	hud.resume_requested.connect(func() -> void: set_paused(false))
	hud.restart_requested.connect(restart_game)
	hud.build_requested.connect(func() -> void: build_tower(selected_slot))
	hud.upgrade_requested.connect(func() -> void: upgrade_tower(selected_slot))
	hud.close_requested.connect(clear_selection)
	hud.sound_toggled.connect(_on_sound_toggled)


func _valid_slot(slot: FortBuildSlot) -> bool:
	return is_instance_valid(slot) and map.slots.has(slot)


func select_slot(slot: FortBuildSlot) -> void:
	if state != "playing" or get_tree().paused or not _valid_slot(slot):
		return
	if is_instance_valid(selected_slot):
		selected_slot.set_selected(false)
	selected_slot = slot
	selected_slot.set_selected(true)
	hud.show_slot(slot, balance["tower_levels"], economy.gold)
	range_indicator.show_for(slot, balance["tower_levels"])


func clear_selection() -> void:
	if is_instance_valid(selected_slot):
		selected_slot.set_selected(false)
	selected_slot = null
	hud.clear_selection()
	range_indicator.clear()


func build_tower(slot: FortBuildSlot) -> bool:
	if state != "playing" or get_tree().paused or not _valid_slot(slot) or slot.occupied:
		return false
	var levels: Array = balance["tower_levels"]
	if not economy.try_spend(int(levels[0]["cost"])):
		hud.show_message("No tienes monedas suficientes para construir.")
		return false
	var tower := TOWER_SCENE.instantiate() as FortTower
	towers_root.add_child(tower)
	tower.global_position = slot.global_position
	tower.configure(levels, float(balance["projectile_speed"]), enemies_root, projectiles_root)
	tower.fired.connect(_on_tower_fired)
	slot.tower = tower
	slot.set_occupied(true)
	feedback.built(slot.global_position)
	_refresh_hud()
	hud.show_message("Ballesta lista para defender la fortaleza.")
	return true


func upgrade_tower(slot: FortBuildSlot) -> bool:
	if state != "playing" or get_tree().paused or not _valid_slot(slot) or not slot.occupied:
		return false
	var tower := slot.tower as FortTower
	if not is_instance_valid(tower) or tower.level >= 3:
		return false
	var levels: Array = balance["tower_levels"]
	if not economy.try_spend(int(levels[tower.level]["cost"])):
		hud.show_message("Te faltan monedas para esta mejora.")
		return false
	if not tower.upgrade():
		# Defensive rollback; normally unreachable after the checks above.
		economy.add_gold(int(levels[tower.level]["cost"]))
		return false
	feedback.upgraded(slot.global_position)
	_refresh_hud()
	hud.show_message("Ballesta mejorada a nivel %d." % tower.level)
	return true


func start_wave() -> bool:
	if state != "playing" or get_tree().paused:
		return false
	var started := waves.begin_wave()
	if started:
		clear_selection()
		feedback.wave_started()
		hud.announce_wave(waves.current_wave, waves.total_waves)
	_refresh_hud()
	return started


func _spawn_enemy(stats: Dictionary) -> void:
	if state != "playing":
		return
	var enemy := ENEMY_SCENE.instantiate() as FortEnemy
	enemies_root.add_child(enemy)
	_active_enemies[enemy.get_instance_id()] = enemy
	enemy.killed.connect(_on_enemy_killed)
	enemy.escaped.connect(_on_enemy_escaped)
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.configure(map.waypoints, stats, int(balance["enemy_reward"]), int(balance["castle_damage"]))


func _on_enemy_killed(enemy: FortEnemy) -> void:
	if state != "playing" or not _active_enemies.erase(enemy.get_instance_id()):
		return
	feedback.kill(enemy.global_position, enemy.reward)
	economy.add_gold(enemy.reward)
	waves.enemy_resolved()


func _on_enemy_escaped(enemy: FortEnemy) -> void:
	if state != "playing" or not _active_enemies.erase(enemy.get_instance_id()):
		return
	feedback.castle_hit(map.castle_position, enemy.castle_damage)
	castle.take_damage(enemy.castle_damage)
	hud.flash_castle_damage(enemy.castle_damage)
	if state == "playing":
		waves.enemy_resolved()


func _on_tower_fired(at: Vector3) -> void:
	if state == "playing":
		feedback.shot(at)


func _on_enemy_damaged(enemy: FortEnemy, _amount: float) -> void:
	if state == "playing" and _active_enemies.has(enemy.get_instance_id()):
		feedback.hit(enemy.global_position + Vector3(0.0, 0.7, 0.0))


func _on_sound_toggled(muted: bool) -> void:
	feedback.set_muted(muted)
	hud.set_sound_muted(muted)


func _on_wave_completed(number: int) -> void:
	_refresh_hud()
	if number < waves.total_waves:
		hud.show_message("Oleada %d superada. Construye o mejora tus defensas." % number)


func _on_all_waves_completed() -> void:
	if _active_enemies.is_empty() and waves.pending_count == 0 and state == "playing":
		_finish(true)


func _finish(victory: bool) -> void:
	if state != "playing":
		return
	state = "victory" if victory else "defeat"
	waves.stop()
	camera_controller.cancel_gestures()
	clear_selection()
	_refresh_hud()
	feedback.result(victory)
	get_tree().paused = true
	hud.show_result(victory)


func set_paused(value: bool) -> void:
	if state != "playing":
		return
	camera_controller.cancel_gestures()
	get_tree().paused = value
	hud.set_paused(value)
	if value:
		range_indicator.clear()
	elif is_instance_valid(selected_slot):
		range_indicator.show_for(selected_slot, balance["tower_levels"])


func restart_game() -> void:
	get_tree().paused = false
	state = "playing"
	_active_enemies.clear()
	feedback.reset_feedback()
	waves.reset()
	clear_selection()
	for container: Node3D in [enemies_root, projectiles_root, towers_root]:
		for child: Node in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for slot: FortBuildSlot in map.slots:
		slot.tower = null
		slot.set_occupied(false)
	economy.reset(int(balance["initial_gold"]))
	castle.reset(int(balance["castle_health"]))
	camera_controller.reset_view()
	hud.reset_hud()
	hud.set_sound_muted(feedback.is_muted)
	_refresh_hud()
	hud.show_message("Nueva partida. Toca un + para construir.")


func _refresh_hud() -> void:
	if not is_instance_valid(hud):
		return
	hud.update_status(economy.gold, castle.health, waves.current_wave, waves.total_waves,
		state == "playing" and not waves.active and waves.current_wave < waves.total_waves)
	if is_instance_valid(selected_slot):
		hud.show_slot(selected_slot, balance["tower_levels"], economy.gold)
		if not get_tree().paused:
			range_indicator.show_for(selected_slot, balance["tower_levels"])


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
		start_wave()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# Never leave an editor run / integration test with a paused SceneTree.
	get_tree().paused = false
