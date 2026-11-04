extends Node
## Ses efektleri (autoload: Sfx). Ses dosyası kullanmaz: tüm sesler açılışta kodla sentezlenir
## (sinüs/üçgen/kare dalgalar, gürültü, perde kayması, zarf). Lisans gerektirmez, iOS'ta aynen çalışır.

const RATE := 22050
const VOICES := 10

var enabled := true
var streams: Dictionary = {}
var players: Array = []
var _next := 0

func _ready() -> void:
	enabled = bool(Progress.p.get("sound", true))
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	_build()

## Bir sesi çalar. pitch: perde çarpanı (puan sayımında her adımda biraz yükselir)
func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not enabled or not streams.has(name):
		return
	var p: AudioStreamPlayer = players[_next]
	_next = (_next + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	p.volume_db = volume_db
	p.play()

# ───────── Sentez ─────────
## Bir katman: {f: frekans, f2: bitiş frekansı, wave: sine|tri|square|saw|noise, dur, at: başlangıç (sn),
## a: atak, d: sönüm üssü, vol}
func _render(layers: Array, total: float) -> AudioStreamWAV:
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for L in layers:
		var start := int(L.get("at", 0.0) * RATE)
		var dur: float = L.get("dur", 0.2)
		var cnt := int(dur * RATE)
		var f0: float = L.get("f", 440.0)
		var f1: float = L.get("f2", f0)
		var wave: int = ["sine", "tri", "square", "saw", "noise"].find(L.get("wave", "sine"))
		var att: float = maxf(0.001, L.get("a", 0.005))
		var dec: float = L.get("d", 4.0)
		var vol: float = L.get("vol", 0.5)
		var phase := 0.0
		var lp := 0.0
		for i in cnt:
			var idx := start + i
			if idx >= n:
				break
			var t := float(i) / RATE
			var k := float(i) / cnt
			var f := lerpf(f0, f1, k)
			phase += f / RATE
			var ph := phase - floorf(phase)
			var s := 0.0
			if wave == 0:
				s = sin(TAU * ph)
			elif wave == 1:
				s = 4.0 * absf(ph - 0.5) - 1.0
			elif wave == 2:
				s = 1.0 if ph < 0.5 else -1.0
			elif wave == 3:
				s = 2.0 * ph - 1.0
			else:
				lp += (randf() * 2.0 - 1.0 - lp) * clampf(f / RATE * 4.0, 0.02, 1.0)
				s = lp * 2.0
			var env := minf(1.0, t / att) * pow(1.0 - k, dec)
			buf[idx] += s * env * vol
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _note(semi: int) -> float:
	return 440.0 * pow(2.0, (semi - 9) / 12.0)   # 0 = Do (C5 civarı)

func _build() -> void:
	# arayüz
	streams.click = _render([{"f": 1400, "f2": 900, "wave": "tri", "dur": 0.05, "d": 3, "vol": 0.35}], 0.06)
	streams.select = _render([{"f": 900, "f2": 1300, "wave": "tri", "dur": 0.07, "d": 2, "vol": 0.4},
		{"f": 3000, "wave": "noise", "dur": 0.03, "d": 3, "vol": 0.15}], 0.08)
	streams.deny = _render([{"f": 220, "f2": 180, "wave": "square", "dur": 0.12, "d": 2, "vol": 0.18}], 0.13)
	# kartlar
	streams.draw = _render([{"f": 2500, "f2": 5000, "wave": "noise", "dur": 0.12, "a": 0.02, "d": 2.5, "vol": 0.35}], 0.13)
	streams.whoosh = _render([{"f": 800, "f2": 3500, "wave": "noise", "dur": 0.28, "a": 0.08, "d": 2, "vol": 0.4}], 0.3)
	# puan sayımı
	streams.chip = _render([{"f": _note(12), "wave": "sine", "dur": 0.11, "d": 3, "vol": 0.45},
		{"f": _note(24), "wave": "sine", "dur": 0.06, "d": 4, "vol": 0.12}], 0.12)
	streams.mult = _render([{"f": _note(7), "wave": "square", "dur": 0.13, "d": 3, "vol": 0.16},
		{"f": _note(19), "wave": "tri", "dur": 0.13, "d": 3, "vol": 0.3}], 0.14)
	streams.xmult = _render([{"f": _note(0), "f2": _note(12), "wave": "saw", "dur": 0.22, "d": 2, "vol": 0.18},
		{"f": _note(12), "f2": _note(24), "wave": "tri", "dur": 0.22, "d": 2, "vol": 0.3}], 0.24)
	# sonuçlar
	streams.hit = _render([
		{"f": _note(0), "wave": "tri", "dur": 0.5, "d": 2, "vol": 0.3},
		{"f": _note(4), "wave": "tri", "dur": 0.5, "at": 0.04, "d": 2, "vol": 0.28},
		{"f": _note(7), "wave": "tri", "dur": 0.55, "at": 0.08, "d": 2, "vol": 0.28},
		{"f": _note(12), "wave": "sine", "dur": 0.6, "at": 0.12, "d": 2, "vol": 0.3},
		{"f": 120, "f2": 60, "wave": "sine", "dur": 0.2, "d": 3, "vol": 0.5}], 0.75)
	streams.miss = _render([{"f": 160, "f2": 70, "wave": "sine", "dur": 0.3, "d": 2.5, "vol": 0.6},
		{"f": 300, "wave": "noise", "dur": 0.15, "d": 3, "vol": 0.25}], 0.32)
	streams.spell = _render([
		{"f": _note(12), "f2": _note(24), "wave": "sine", "dur": 0.6, "a": 0.05, "d": 1.5, "vol": 0.25},
		{"f": _note(19), "f2": _note(31), "wave": "sine", "dur": 0.6, "a": 0.1, "d": 1.5, "vol": 0.2},
		{"f": 6000, "wave": "noise", "dur": 0.5, "a": 0.1, "d": 2, "vol": 0.08}], 0.65)
	streams.power = _render([{"f": _note(-5), "f2": _note(7), "wave": "saw", "dur": 0.35, "a": 0.03, "d": 1.8, "vol": 0.18},
		{"f": _note(7), "f2": _note(19), "wave": "tri", "dur": 0.4, "a": 0.05, "d": 1.8, "vol": 0.3}], 0.45)
	streams.coin = _render([{"f": _note(23), "wave": "square", "dur": 0.07, "d": 1, "vol": 0.14},
		{"f": _note(28), "wave": "square", "dur": 0.3, "at": 0.07, "d": 3, "vol": 0.14}], 0.38)
	streams.event_good = _render([{"f": _note(7), "wave": "tri", "dur": 0.25, "d": 2, "vol": 0.3},
		{"f": _note(12), "wave": "tri", "dur": 0.4, "at": 0.12, "d": 2, "vol": 0.3}], 0.55)
	streams.event_bad = _render([{"f": _note(3), "wave": "saw", "dur": 0.3, "d": 2, "vol": 0.16},
		{"f": _note(-2), "wave": "saw", "dur": 0.45, "at": 0.15, "d": 2, "vol": 0.16},
		{"f": 90, "f2": 55, "wave": "sine", "dur": 0.4, "at": 0.15, "d": 2, "vol": 0.45}], 0.65)
	streams.event = _render([{"f": _note(9), "wave": "sine", "dur": 0.35, "d": 2, "vol": 0.3},
		{"f": _note(14), "wave": "sine", "dur": 0.4, "at": 0.1, "d": 2, "vol": 0.25}], 0.55)
	var fan: Array = []
	var arp := [0, 4, 7, 12, 16, 19, 24]
	for i in arp.size():
		fan.append({"f": _note(arp[i]), "wave": "tri", "dur": 0.35, "at": i * 0.07, "d": 2, "vol": 0.26})
	fan.append({"f": _note(12), "wave": "square", "dur": 0.9, "at": 0.5, "d": 2.5, "vol": 0.08})
	fan.append({"f": _note(24), "wave": "sine", "dur": 0.9, "at": 0.5, "d": 2.5, "vol": 0.2})
	streams.fanfare = _render(fan, 1.45)
	streams.boss = _render([{"f": 70, "f2": 45, "wave": "sine", "dur": 0.6, "d": 2, "vol": 0.7},
		{"f": 140, "f2": 90, "wave": "saw", "dur": 0.5, "d": 2, "vol": 0.12},
		{"f": 70, "f2": 45, "wave": "sine", "dur": 0.6, "at": 0.35, "d": 2, "vol": 0.6}], 1.0)
	streams.life_lost = _render([{"f": _note(7), "f2": _note(-5), "wave": "tri", "dur": 0.7, "d": 1.6, "vol": 0.35},
		{"f": _note(3), "f2": _note(-9), "wave": "tri", "dur": 0.7, "at": 0.1, "d": 1.6, "vol": 0.25}], 0.85)
	streams.heal = _render([{"f": _note(12), "wave": "sine", "dur": 0.25, "d": 2, "vol": 0.3},
		{"f": _note(16), "wave": "sine", "dur": 0.25, "at": 0.08, "d": 2, "vol": 0.3},
		{"f": _note(19), "wave": "sine", "dur": 0.4, "at": 0.16, "d": 2, "vol": 0.3}], 0.6)
	streams.achievement = _render([{"f": _note(19), "wave": "sine", "dur": 0.3, "d": 2, "vol": 0.3},
		{"f": _note(24), "wave": "sine", "dur": 0.5, "at": 0.1, "d": 2, "vol": 0.3},
		{"f": _note(31), "wave": "sine", "dur": 0.6, "at": 0.2, "d": 2.5, "vol": 0.18},
		{"f": 8000, "wave": "noise", "dur": 0.4, "at": 0.1, "a": 0.05, "d": 2, "vol": 0.05}], 0.85)
	streams.shield = _render([{"f": _note(0), "f2": _note(7), "wave": "sine", "dur": 0.5, "a": 0.05, "d": 1.5, "vol": 0.35},
		{"f": 4000, "wave": "noise", "dur": 0.3, "d": 2, "vol": 0.06}], 0.55)
