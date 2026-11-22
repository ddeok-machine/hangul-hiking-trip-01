extends RefCounted
## PLACEHOLDER roar of the bear, made in code (no audio files): a few low detuned tones with
## their harmonics (a rough, sawlike buzz), a slow vibrato, and a fast growl wobble in the
## loudness, with a swell and a long fall. `distant` cuts the high end hard (a dull rumble far
## away), the loud one lets more through. Never tuned by ear; replace it in the art pass.
## Data: animals.scene_timer.roar.

const MIX_RATE := 11025
const PEAK := 0.8
const HARMONICS := [1.0, 0.55, 0.32, 0.18]

static var _cache := {}


## The samples of a roar as floats, -PEAK..PEAK. `cut` is the one-pole filter's share (0..1):
## lower = duller. Public for tests.
static func samples(config: Dictionary, cut: float) -> PackedFloat32Array:
	var seconds := float(config["seconds"])
	var count := roundi(seconds * MIX_RATE)
	var mix := PackedFloat32Array()
	mix.resize(count)
	var tones: Array = config["hz"]
	var phases := PackedFloat64Array()
	phases.resize(tones.size())
	var growl_hz := float(config["growl_hz"])
	var depth := clampf(float(config["growl_depth"]), 0.0, 1.0)
	var low := 0.0
	var peak := 0.0001
	for i in count:
		var t := float(i) / MIX_RATE
		var vibrato := 1.0 + 0.03 * sin(TAU * 5.3 * t)
		var sum := 0.0
		for k in tones.size():
			phases[k] += TAU * float(tones[k]) * vibrato / MIX_RATE
			for h in HARMONICS.size():
				sum += float(HARMONICS[h]) * sin(phases[k] * float(h + 1)) / float(h + 1 + k)
		var wobble := 1.0 - depth * 0.5 * (1.0 + sin(TAU * growl_hz * t + 1.5 * sin(TAU * 2.7 * t)))
		var swell := minf(t / 0.35, 1.0) * exp(-maxf(t - 0.5, 0.0) / (seconds * 0.3))
		var value := tanh(sum * 1.6) * wobble * swell
		low = lerpf(low, value, clampf(cut, 0.01, 1.0))
		mix[i] = low
		peak = maxf(peak, absf(low))
	for i in count:
		mix[i] = mix[i] / peak * PEAK
	return mix


## The roar as a stream (not looping). Cached per (data, loud).
static func make(config: Dictionary, loud: bool) -> AudioStreamWAV:
	var key := "%s:%s" % [str(config.hash()), loud]
	if _cache.has(key):
		return _cache[key]
	var mix := samples(config, float(config["loud_cut" if loud else "distant_cut"]))
	var data := PackedByteArray()
	data.resize(mix.size() * 2)
	for i in mix.size():
		data.encode_s16(i * 2, int(clampf(mix[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	_cache[key] = stream
	return stream


## The player volume of the roar in dB.
static func volume_db(config: Dictionary, loud: bool) -> float:
	return float(config["loud_db" if loud else "distant_db"])
