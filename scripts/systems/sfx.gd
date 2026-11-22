# ---------------------------------------------------------------------------
# systems/sfx.gd — SFX procedurales con acordes para momentos memorables.
# shortcut: sin pack de audio real; sustituir por WAV/OGG cuando exista.
# ---------------------------------------------------------------------------
class_name Sfx
extends RefCounted

static var _player: AudioStreamPlayer
static var _queue: Array = []
static var _host: Node

static func ensure(host: Node) -> void:
	_host = host
	if is_instance_valid(_player):
		return
	_player = AudioStreamPlayer.new()
	_player.name = "SfxPlayer"
	_player.bus = "Master"
	host.add_child(_player)
	_player.finished.connect(_on_finished)

static func play(kind: String) -> void:
	if not is_instance_valid(_player):
		return
	match kind:
		"ui":
			_play_tones([[660.0, 45]])
		"pickup":
			_play_tones([[740.0, 40], [880.0, 55], [1175.0, 70]])
		"clear":
			_play_tones([[523.0, 70], [659.0, 80], [784.0, 110]])
		"adlib":
			_play_tones([[988.0, 70], [1175.0, 80], [1319.0, 120]])
		"defeat":
			_play_tones([[220.0, 120], [196.0, 140], [147.0, 180]])
		"victory":
			_play_tones([[523.0, 80], [659.0, 90], [784.0, 90], [1047.0, 140]])
		"pause":
			_play_tones([[330.0, 55]])
		"intro":
			_play_tones([[440.0, 60], [554.0, 80]])
		"warn":
			_play_tones([[370.0, 50], [311.0, 70]])
		"telegraph":
			_play_tones([[415.0, 90]])
		"hazard":
			_play_tones([[277.0, 60], [349.0, 80]])
		"setpiece":
			_play_tones([[466.0, 55], [392.0, 70], [311.0, 90]])
		"phase":
			_play_tones([[220.0, 70], [277.0, 80], [330.0, 70], [415.0, 110]])
		# Acordes por integrante (identidad sonora sin pack real).
		"solar":
			_play_tones([[523.0, 55], [659.0, 70], [784.0, 95]])
		"moonbyul":
			_play_tones([[392.0, 60], [494.0, 70], [587.0, 100]])
		"wheein":
			_play_tones([[440.0, 50], [554.0, 65], [659.0, 80], [880.0, 70]])
		"hwasa":
			_play_tones([[330.0, 45], [415.0, 55], [494.0, 70], [622.0, 110]])
		_:
			_play_tones([[440.0, 70]])

static func _play_tones(tones: Array) -> void:
	_queue.clear()
	for tone in tones:
		_queue.append(tone)
	_play_next()

static func _play_next() -> void:
	if not is_instance_valid(_player) or _queue.is_empty():
		return
	if _player.playing:
		return
	var tone: Array = _queue.pop_front()
	_player.stream = _tone(float(tone[0]), int(tone[1]))
	_player.play()

static func _on_finished() -> void:
	_play_next()

static func _tone(hz: float, ms: int) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * ms / 1000.0)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var env := 1.0 - float(i) / float(maxi(count, 1))
		# Ligero segundo armónico para que no suene a pitido plano.
		var wave := sin(TAU * hz * t) * 0.30 + sin(TAU * hz * 2.0 * t) * 0.08
		var sample := int(wave * env * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
