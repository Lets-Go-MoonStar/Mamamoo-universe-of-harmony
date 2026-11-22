# ---------------------------------------------------------------------------
# systems/sfx.gd — SFX procedurales mínimos (sin assets de audio externos).
# shortcut: tonos simples; sustituir por WAV/OGG reales cuando haya pack de audio.
# ---------------------------------------------------------------------------
class_name Sfx
extends RefCounted

static var _player: AudioStreamPlayer

static func ensure(host: Node) -> void:
	if is_instance_valid(_player):
		return
	_player = AudioStreamPlayer.new()
	_player.name = "SfxPlayer"
	_player.bus = "Master"
	host.add_child(_player)

static func play(kind: String) -> void:
	if not is_instance_valid(_player):
		return
	var hz := 440.0
	var ms := 80
	match kind:
		"ui":
			hz = 660.0
			ms = 50
		"pickup":
			hz = 880.0
			ms = 70
		"clear":
			hz = 523.0
			ms = 120
		"adlib":
			hz = 988.0
			ms = 160
		"defeat":
			hz = 196.0
			ms = 280
		"victory":
			hz = 784.0
			ms = 220
		"pause":
			hz = 330.0
			ms = 60
		"intro":
			hz = 440.0
			ms = 100
		_:
			pass
	_player.stream = _tone(hz, ms)
	_player.play()

static func _tone(hz: float, ms: int) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * ms / 1000.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var env := 1.0 - float(i) / float(maxi(count, 1))
		var sample := int(sin(TAU * hz * t) * 0.35 * env * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
