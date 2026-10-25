class_name FortFeedback
extends Node3D
## Bounded presentation layer: gameplay events are observations, never mutations.

const MAX_EFFECTS: int = 48
const MAX_GAMEPLAY_VOICES: int = 7
const MAX_VOICES: int = MAX_GAMEPLAY_VOICES + 1
const SOUND_INTERVALS: Dictionary = {
	"shot": 0.07, "hit": 0.05, "kill": 0.10, "built": 0.10,
	"upgraded": 0.10, "castle_hit": 0.14, "wave_started": 0.4,
}
const SOUND_LEVELS: Dictionary = {
	"shot": -17.0, "hit": -20.0, "kill": -15.0, "built": -14.0,
	"upgraded": -13.0, "castle_hit": -11.0, "wave_started": -13.0,
	"victory": -12.0, "defeat": -13.0,
}

var is_muted: bool = false
var effects_root: Node3D
var players: Array[AudioStreamPlayer] = []
var result_player: AudioStreamPlayer
var _streams: Dictionary = {}
var _clock: float = 0.0
var _last_sound: Dictionary = {}
var _voice_ends: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_streams = FortSoundBank.streams()
	effects_root = Node3D.new()
	effects_root.name = "TransientEffects"
	effects_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(effects_root)
	for index in MAX_GAMEPLAY_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "GameplayVoice%d" % index
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		player.max_polyphony = 1
		add_child(player)
		players.append(player)
		_voice_ends.append(0.0)
	result_player = AudioStreamPlayer.new()
	result_player.name = "ResultVoice"
	result_player.process_mode = Node.PROCESS_MODE_ALWAYS
	result_player.max_polyphony = 1
	add_child(result_player)


func _process(delta: float) -> void:
	# Time follows gameplay, including Engine.time_scale in balance simulations.
	if not get_tree().paused:
		_clock += delta


func shot(at: Vector3) -> void:
	if _can_present():
		_effect("shot", at)
		_play("shot")


func hit(at: Vector3) -> void:
	if _can_present():
		_effect("hit", at)
		_play("hit")


func kill(at: Vector3, reward: int) -> void:
	if _can_present():
		_effect("kill", at, maxi(0, reward))
		_play("kill")


func built(at: Vector3) -> void:
	if _can_present():
		_effect("built", at)
		_play("built")


func upgraded(at: Vector3) -> void:
	if _can_present():
		_effect("upgraded", at)
		_play("upgraded")


func castle_hit(at: Vector3, damage: int = 1) -> void:
	if _can_present():
		_effect("castle_hit", at, maxi(0, damage))
		_play("castle_hit")


func wave_started() -> void:
	if _can_present():
		_play("wave_started")


func result(victory: bool) -> void:
	_stop_gameplay_audio()
	if is_muted or not is_instance_valid(result_player):
		return
	var cue := "victory" if victory else "defeat"
	result_player.stop()
	result_player.stream = _streams[cue]
	result_player.volume_db = float(SOUND_LEVELS[cue])
	result_player.play()


func set_muted(value: bool) -> void:
	is_muted = value
	if value:
		_stop_gameplay_audio()
		if is_instance_valid(result_player):
			result_player.stop()


func reset_feedback() -> void:
	_stop_gameplay_audio()
	if is_instance_valid(result_player):
		result_player.stop()
	if is_instance_valid(effects_root):
		for child in effects_root.get_children():
			effects_root.remove_child(child)
			child.queue_free()
	_clock = 0.0
	_last_sound.clear()
	for index in _voice_ends.size():
		_voice_ends[index] = 0.0


func active_effect_count() -> int:
	return effects_root.get_child_count() if is_instance_valid(effects_root) else 0


func active_voice_count() -> int:
	var count := 0
	for player in players:
		if player.playing:
			count += 1
	if is_instance_valid(result_player) and result_player.playing:
		count += 1
	return count


func _can_present() -> bool:
	return is_inside_tree() and not get_tree().paused and is_instance_valid(effects_root)


func _effect(kind: String, at: Vector3, amount: int = 0) -> void:
	if effects_root.get_child_count() >= MAX_EFFECTS:
		# Make room for the latest useful information while maintaining a hard cap.
		var oldest := effects_root.get_child(0)
		effects_root.remove_child(oldest)
		oldest.queue_free()
	var effect := FortTransientEffect.new()
	effect.configure(kind, amount)
	effects_root.add_child(effect)
	effect.global_position = at


func _play(kind: String) -> void:
	if is_muted or _clock - float(_last_sound.get(kind, -100.0)) < float(SOUND_INTERVALS[kind]):
		return
	_last_sound[kind] = _clock
	var voice_index := 0
	for index in players.size():
		if _voice_ends[index] <= _clock:
			voice_index = index
			break
		if _voice_ends[index] < _voice_ends[voice_index]:
			voice_index = index
	var player: AudioStreamPlayer = players[voice_index]
	player.stop()
	player.stream = _streams[kind]
	player.volume_db = float(SOUND_LEVELS[kind])
	player.play()
	_voice_ends[voice_index] = _clock + player.stream.get_length()


func _stop_gameplay_audio() -> void:
	for index in players.size():
		players[index].stop()
		_voice_ends[index] = _clock
