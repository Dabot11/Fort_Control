extends SceneTree
## Presentation integration must remain a read-only observer of gameplay state.
## Audio checks validate streams/routing; listening and mobile output need hardware.

var _checks := 0
var _failures := 0
var _game: FortGame


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("POLISH CHECK FAILED: " + description)


func _frames() -> void:
	await process_frame
	await process_frame


func _touch_tap(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await _frames()


func _inside(control: Control) -> bool:
	var rect := control.get_global_rect()
	var size := root.get_visible_rect().size
	return rect.position.x >= -1.0 and rect.position.y >= -1.0 \
		and rect.end.x <= size.x + 1.0 and rect.end.y <= size.y + 1.0


func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func():
		push_error("Presentation verification timed out before reporting completion.")
		quit(124)
	)
	root.size = Vector2i(720, 1280)
	_game = load("res://scenes/main/main.tscn").instantiate() as FortGame
	root.add_child(_game)
	await _frames()
	await _test_range_and_upgrade_preview()
	await _test_sound_controls()
	await _test_effect_limits_and_lifetime()
	await _test_combat_feedback()
	await _test_result_and_restart()
	await _test_overlay_layout()
	paused = false
	_game.free()
	await _frames()
	print("POLISH TESTS: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_range_and_upgrade_preview() -> void:
	var indicator = _game.range_indicator
	var levels: Array = _game.balance["tower_levels"]
	var slot: FortBuildSlot = _game.map.slots[2]
	_check(not indicator.visible, "Range starts hidden before selection")
	_game.select_slot(slot)
	_check(indicator.visible, "Empty slot previews construction range")
	_check(is_equal_approx(indicator.current_radius, float(levels[0].range)), "Build preview matches level-one combat radius")
	_check(is_zero_approx(indicator.next_radius), "Empty slot does not advertise an upgrade")
	_check(is_equal_approx(indicator.global_position.x, slot.global_position.x)
		and is_equal_approx(indicator.global_position.z, slot.global_position.z), "Range is centered on the selected world position")
	_check(indicator.find_children("*", "CollisionObject3D", true, false).is_empty(), "Range cannot intercept selection raycasts")
	_check(_game.build_tower(slot), "Build succeeds with range preview active")
	_check(is_equal_approx(indicator.current_radius, float(levels[0].range)), "Building preserves actual level-one range")
	_check(is_equal_approx(indicator.next_radius, float(levels[1].range)), "Built tower previews next level's range")
	_check_upgrade_text(levels[0], levels[1])
	_check(_game.upgrade_tower(slot), "Upgrade succeeds with preview active")
	_check(is_equal_approx(indicator.current_radius, float(levels[1].range)), "Purchased upgrade refreshes actual range")
	_check(is_equal_approx(indicator.next_radius, float(levels[2].range)), "Level two previews maximum-level range")
	_check_upgrade_text(levels[1], levels[2])
	_game.economy.add_gold(int(levels[2].cost))
	_check(_game.upgrade_tower(slot), "Maximum upgrade succeeds")
	_check(is_equal_approx(indicator.current_radius, float(levels[2].range)), "Maximum level uses its configured combat range")
	_check(is_zero_approx(indicator.next_radius), "Maximum level has no phantom upgrade circle")
	_check(_game.hud._context_action.disabled, "Maximum level prevents another purchase")
	_game.set_paused(true)
	_check(not indicator.visible, "Pause hides the selected tower's range")
	_game.set_paused(false)
	_check(indicator.visible and is_equal_approx(indicator.current_radius, float(levels[2].range)), "Resume restores selected tower's range")
	_game.clear_selection()
	_check(not indicator.visible and is_zero_approx(indicator.current_radius) and is_zero_approx(indicator.next_radius), "Clearing selection removes both range values")
	_game.restart_game()
	await _frames()
	_check(not indicator.visible, "Restart does not leave a range marker")


func _check_upgrade_text(current: Dictionary, next: Dictionary) -> void:
	var details: String = _game.hud._context_details.text
	_check(details.contains(str(int(current.damage))) and details.contains(str(int(next.damage))), "Upgrade preview contains both current and next damage")
	_check(details.contains("%.1f" % float(current.range)) and details.contains("%.1f" % float(next.range)), "Upgrade preview contains both current and next range")
	_check(details.contains("%.2f" % (1.0 / float(current.interval)))
		and details.contains("%.2f" % (1.0 / float(next.interval))), "Upgrade preview contains both current and next attacks per second")
	_check(_game.hud._context_action.text.contains(str(int(next.cost))), "Preview price uses the next level's actual purchase cost")


func _test_sound_controls() -> void:
	var feedback = _game.feedback
	_check(not feedback.is_muted, "Sound begins enabled")
	_game.set_paused(true)
	await _frames()
	_check(_game.hud._sound_button.is_visible_in_tree(), "Sound control is reachable from pause")
	await _touch_tap(_game.hud._sound_button.get_global_rect().get_center())
	_check(feedback.is_muted, "Touching the sound control mutes the real feedback system")
	_check(feedback.active_voice_count() == 0, "Muting stops currently active audio voices")
	_game.restart_game()
	await _frames()
	_check(feedback.is_muted, "Restart preserves the player's sound preference")
	feedback.shot(Vector3.ZERO)
	feedback.hit(Vector3.ZERO)
	feedback.kill(Vector3.ZERO, 25)
	feedback.result(true)
	_check(feedback.active_voice_count() == 0, "Muted combat and result events cannot start voices")
	_game.set_paused(true)
	await _frames()
	await _touch_tap(_game.hud._sound_button.get_global_rect().get_center())
	_check(not feedback.is_muted, "Touching sound again restores audio")
	_game.set_paused(false)
	feedback.reset_feedback()
	feedback.built(Vector3.ZERO)
	_check(feedback.active_voice_count() > 0, "Unmuted construction starts an audio stream")
	_check(feedback.players.size() + 1 <= 8, "Audio pool has at most eight total players")
	var valid_streams := true
	for player: AudioStreamPlayer in feedback.players:
		if player.playing:
			valid_streams = valid_streams and player.stream is AudioStreamWAV and player.stream.get_length() > 0.0
	_check(valid_streams, "Playing effects use nonempty generated PCM streams")
	_game.restart_game()
	await _frames()


func _test_effect_limits_and_lifetime() -> void:
	var feedback = _game.feedback
	var gold_before := _game.economy.gold
	var health_before := _game.castle.health
	for index in range(100):
		feedback.hit(Vector3(index % 8, 0.5, index % 5))
		feedback.kill(Vector3(index % 8, 0.5, index % 5), 25)
	_check(feedback.active_effect_count() > 0, "Combat events create visible effect nodes")
	_check(feedback.active_effect_count() <= 48, "Bursts of combat events respect the visual-effect cap")
	_check(feedback.active_voice_count() <= 8, "Bursts of combat events respect the audio-voice cap")
	_check(_game.economy.gold == gold_before and _game.castle.health == health_before, "Presentation events cannot award gold or apply castle damage")
	_check(feedback.effects_root.find_children("*", "CollisionObject3D", true, false).is_empty(), "Combat effects never add collision objects")
	feedback.reset_feedback()
	await _frames()
	_check(feedback.active_effect_count() == 0 and feedback.active_voice_count() == 0, "Reset clears visual and audio transients")
	feedback.kill(Vector3.ZERO, 25)
	var effect: Node = feedback.effects_root.get_child(0)
	var active_players: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in feedback.players:
		if player.playing:
			active_players.append(player)
	_game.set_paused(true)
	await _frames()
	var age_before := float(effect.age)
	await create_timer(1.1, true).timeout
	_check(is_instance_valid(effect) and is_equal_approx(float(effect.age), age_before), "Paused visual effects do not age or disappear")
	var paused_voices := true
	for player: AudioStreamPlayer in feedback.players:
		paused_voices = paused_voices and not player.can_process()
	_check(paused_voices, "Gameplay sound players are paused with the match")
	var streams_paused := not active_players.is_empty()
	for player: AudioStreamPlayer in active_players:
		streams_paused = streams_paused and player.stream_paused
	_check(streams_paused, "Already playing audio streams pause rather than merely stopping node updates")
	_game.set_paused(false)
	await create_timer(1.2).timeout
	await _frames()
	_check(feedback.active_effect_count() == 0, "Transient effects expire after gameplay resumes")
	_game.restart_game()
	await _frames()


func _test_combat_feedback() -> void:
	var slot: FortBuildSlot = _game.map.slots[2]
	_game.build_tower(slot)
	_game.start_wave()
	_game.waves.set_process(false)
	var enemy := _game.enemies_root.get_child(0) as FortEnemy
	enemy.set_physics_process(false)
	enemy.global_position = slot.global_position + Vector3(0, 0, 1)
	var event_counts := {"shots": 0, "hits": 0}
	slot.tower.fired.connect(func(_at: Vector3): event_counts.shots += 1)
	enemy.damaged.connect(func(_enemy: FortEnemy, _amount: float): event_counts.hits += 1)
	_game.feedback.reset_feedback()
	slot.tower._physics_process(0.0)
	_check(event_counts.shots == 1, "Real tower shot emits exactly one presentation event")
	_check(_game.projectiles_root.get_child_count() == 1, "Presentation event accompanies a real projectile")
	_check(_game.feedback.active_voice_count() > 0, "Game connects tower shots to the audio system")
	var projectile := _game.projectiles_root.get_child(0) as FortProjectile
	projectile._physics_process(1.0)
	projectile._physics_process(1.0)
	_check(event_counts.hits == 1, "A projectile produces one damage-feedback event")
	_check(_game.feedback.active_effect_count() > 0, "Actual projectile damage creates hit feedback")
	var gold_before := _game.economy.gold
	enemy.take_damage(enemy.health)
	enemy.take_damage(100.0)
	_game._on_enemy_killed(enemy)
	_check(event_counts.hits == 2, "Terminal damage emits once despite repeated damage attempts")
	_check(_game.economy.gold == gold_before + enemy.reward, "Kill feedback never duplicates the actual reward")
	_game.restart_game()
	_game.waves.set_process(true)
	await _frames()
	_game.start_wave()
	_game.waves.set_process(false)
	enemy = _game.enemies_root.get_child(0) as FortEnemy
	enemy.set_physics_process(false)
	enemy.castle_damage = 3
	_game.feedback.reset_feedback()
	enemy._physics_process(1000.0)
	_check(_game.castle.health == int(_game.balance.castle_health) - 3, "Arrival uses the enemy's actual damage with feedback attached")
	_check(_game.hud._health_value.text == str(_game.castle.health), "Castle feedback keeps HUD health authoritative")
	_check(_game.feedback.active_effect_count() > 0, "Arrival creates castle damage feedback")
	var castle_effect: Node = _game.feedback.effects_root.get_child(0)
	_check(castle_effect.amount == 3, "Castle feedback receives actual damage instead of a fixed amount")
	var labels := castle_effect.find_children("*", "Label3D", true, false)
	_check(labels.size() == 1 and labels[0].text == "−3 vidas", "Castle damage label displays the actual loss")
	_game.restart_game()
	_game.waves.set_process(true)
	await _frames()


func _test_result_and_restart() -> void:
	_game.feedback.reset_feedback()
	_game._finish(true)
	_check(paused, "Result freezes the match")
	_check(_game.feedback.result_player.can_process(), "Result sound remains processable while the match is frozen")
	_check(_game.feedback.result_player.playing, "Victory starts the result cue")
	_game.restart_game()
	await _frames()
	_check(not paused and _game.state == "playing", "Restart returns from result to a playable match")
	_check(_game.feedback.active_voice_count() == 0 and _game.feedback.active_effect_count() == 0, "Restart removes result audio and all effects")
	_check(not _game.range_indicator.visible, "Restart clears selection visuals")
	_game._finish(false)
	_check(_game.feedback.result_player.playing, "Defeat also starts a result cue")
	_game.restart_game()
	await _frames()


func _test_overlay_layout() -> void:
	for size in [Vector2i(390, 844), Vector2i(768, 1024), Vector2i(1024, 768)]:
		root.size = size
		await _frames()
		_game.set_paused(true)
		await _frames()
		_check(_inside(_game.hud._sound_button) and _inside(_game.hud._restart_button), "Pause sound and restart controls fit " + str(size))
		_game.set_paused(false)
