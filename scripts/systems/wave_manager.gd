class_name FortWaveManager
extends Node
## A wave ends only when both its spawn queue and living population are empty.

signal spawn_requested(stats: Dictionary)
signal wave_started(number: int)
signal wave_completed(number: int)
signal all_waves_completed

var current_wave: int = 0
var total_waves: int = 0
var active: bool = false
var pending_count: int = 0
var living_count: int = 0
var _waves: Array = []
var _spawn_timer: float = 0.0


func configure(data: Array) -> void:
	_waves = data.duplicate(true)
	total_waves = _waves.size()
	reset()


func reset() -> void:
	current_wave = 0
	stop()


func stop() -> void:
	active = false
	pending_count = 0
	living_count = 0
	_spawn_timer = 0.0


func begin_wave() -> bool:
	if active or current_wave >= total_waves:
		return false
	var entry: Dictionary = _waves[current_wave]
	current_wave += 1
	pending_count = maxi(0, int(entry["count"]))
	living_count = 0
	_spawn_timer = 0.0
	active = true
	wave_started.emit(current_wave)
	_process(0.0)
	return true


func _process(delta: float) -> void:
	if not active:
		return
	_spawn_timer -= delta
	var entry: Dictionary = _waves[current_wave - 1]
	while pending_count > 0 and _spawn_timer <= 0.0 and active:
		pending_count -= 1
		living_count += 1
		_spawn_timer += maxf(0.05, float(entry["spawn_interval"]))
		spawn_requested.emit(entry.duplicate(true))
	_check_completed()


func enemy_resolved() -> void:
	if not active or living_count <= 0:
		return
	living_count -= 1
	_check_completed()


func _check_completed() -> void:
	if not active or pending_count > 0 or living_count > 0:
		return
	active = false
	wave_completed.emit(current_wave)
	if current_wave == total_waves:
		all_waves_completed.emit()
