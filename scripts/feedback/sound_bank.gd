class_name FortSoundBank
extends RefCounted
## Original, deterministic PCM cues. No downloaded samples, import or audio plugin.
## Streams are synthesized once and shared by every match in this process.

const SAMPLE_RATE: int = 22050
const MAX_PEAK: float = 0.72
const DURATIONS := {
	"shot": 0.16,
	"hit": 0.13,
	"kill": 0.38,
	"built": 0.30,
	"upgraded": 0.67,
	"castle_hit": 0.44,
	"wave_started": 0.78,
	"victory": 1.10,
	"defeat": 0.98,
}

static var _cache: Dictionary = {}


static func streams() -> Dictionary:
	if _cache.is_empty():
		for cue: String in DURATIONS:
			_cache[cue] = _synthesize(cue, float(DURATIONS[cue]))
	return _cache.duplicate()


static func export_samples(directory: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var bank := streams()
	for cue: String in bank:
		var stream: AudioStreamWAV = bank[cue]
		error = stream.save_to_wav(directory.path_join(cue + ".wav"))
		if error != OK:
			return error
	return OK


static func _synthesize(cue: String, duration: float) -> AudioStreamWAV:
	var count := ceili(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var noise := RandomNumberGenerator.new()
	noise.seed = 31991 + cue.hash()
	var filtered_noise: float = 0.0
	var peak: float = 0.0
	for index in range(count):
		var time := float(index) / SAMPLE_RATE
		filtered_noise = filtered_noise * 0.56 + noise.randf_range(-1.0, 1.0) * 0.44
		var sample := _sample(cue, time, filtered_noise)
		# A shared fade guarantees click-free start/end even for summed notes.
		sample *= smoothstep(0.0, 0.003, time)
		sample *= smoothstep(0.0, 0.018, duration - time)
		samples[index] = sample
		peak = maxf(peak, absf(sample))
	var attenuation := minf(1.0, MAX_PEAK / maxf(peak, 0.0001))
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for index in range(count):
		pcm.encode_s16(index * 2, int(samples[index] * attenuation * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream


static func _sample(cue: String, time: float, noise: float) -> float:
	match cue:
		"shot":
			# Short string release followed by a woody body resonance.
			var phase := TAU * (1020.0 * time - 2150.0 * time * time)
			return sin(phase) * exp(-time * 35.0) * 0.23 \
				+ sin(TAU * 175.0 * time) * exp(-time * 28.0) * 0.28 \
				+ noise * exp(-time * 65.0) * 0.22
		"hit":
			return sin(TAU * 240.0 * time) * exp(-time * 42.0) * 0.30 \
				+ sin(TAU * 410.0 * time) * exp(-time * 48.0) * 0.16 \
				+ noise * exp(-time * 30.0) * 0.30
		"kill":
			return _note(time, 0.0, 0.27, 1046.50, 0.25, true) \
				+ _note(time, 0.085, 0.29, 1567.98, 0.25, true)
		"built":
			return _note(time, 0.0, 0.20, 146.83, 0.36) \
				+ _note(time, 0.065, 0.23, 293.66, 0.22, true) \
				+ noise * exp(-time * 55.0) * 0.20
		"upgraded":
			return _note(time, 0.0, 0.25, 523.25, 0.24, true) \
				+ _note(time, 0.10, 0.25, 659.25, 0.24, true) \
				+ _note(time, 0.20, 0.28, 783.99, 0.24, true) \
				+ _note(time, 0.31, 0.35, 1046.50, 0.25, true)
		"castle_hit":
			var phase := TAU * (94.0 * time - 43.0 * time * time)
			return sin(phase) * exp(-time * 11.0) * 0.52 \
				+ sin(TAU * 180.0 * time) * exp(-time * 22.0) * 0.17 \
				+ noise * exp(-time * 21.0) * 0.26
		"wave_started":
			return _note(time, 0.0, 0.23, 261.63, 0.29) \
				+ _note(time, 0.18, 0.23, 392.0, 0.29) \
				+ _note(time, 0.36, 0.41, 523.25, 0.27)
		"victory":
			return _note(time, 0.0, 0.25, 523.25, 0.24, true) \
				+ _note(time, 0.13, 0.25, 659.25, 0.24, true) \
				+ _note(time, 0.26, 0.28, 783.99, 0.24, true) \
				+ _note(time, 0.43, 0.65, 1046.5, 0.26, true) \
				+ _note(time, 0.43, 0.65, 659.25, 0.12)
		"defeat":
			return _note(time, 0.0, 0.30, 392.0, 0.27) \
				+ _note(time, 0.22, 0.30, 311.13, 0.27) \
				+ _note(time, 0.45, 0.51, 261.63, 0.24) \
				+ _note(time, 0.45, 0.51, 130.81, 0.13)
	return 0.0


static func _note(time: float, start: float, duration: float, frequency: float,
		gain: float, bell: bool = false) -> float:
	var local_time := time - start
	if local_time < 0.0 or local_time >= duration:
		return 0.0
	var phase := TAU * frequency * local_time
	var envelope := smoothstep(0.0, 0.008, local_time) \
		* smoothstep(0.0, minf(0.10, duration * 0.4), duration - local_time)
	if bell:
		return gain * envelope * exp(-local_time * 5.5) \
			* (sin(phase) + 0.23 * sin(phase * 2.73) + 0.09 * sin(phase * 4.12))
	return gain * envelope * exp(-local_time * 2.6) \
		* (sin(phase) + 0.20 * sin(phase * 2.0) + 0.08 * sin(phase * 3.0))
