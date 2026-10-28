extends Node
## 声音：BGM（淡入淡出切换）、角色配音、音量设置。
## 配音文件由 tools/gen_audio.py 生成，文件名是 voice_id(角色, 台词)；缺文件时静默跳过。

const VOICE_DIR := "res://assets/audio/voice/"
const BGM_DIR := "res://assets/audio/bgm/"
const SFX_DIR := "res://assets/audio/sfx/"

var bgm_a: AudioStreamPlayer
var bgm_b: AudioStreamPlayer
var voice: AudioStreamPlayer
var sfx: Array = []  # 几个轮流用的音效播放器，音效可以叠在一起
var _sfx_i := 0
var current_bgm := ""
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_a = _player()
	bgm_b = _player()
	voice = _player()
	for i in 4:
		sfx.append(_player())


func _player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	return p


## 与 tools/gen_audio.py 的 voice_id() 一致。
static func voice_id(who: String, text: String) -> String:
	return ("%s|%s" % [who, text]).md5_text().substr(0, 16)


func has_voice(who: String, text: String) -> bool:
	return _exists(VOICE_DIR + voice_id(who, text) + ".mp3")


## 播放一句配音（会打断上一句）。返回是否有配音。
func play_voice(who: String, text: String) -> bool:
	stop_voice()
	var vol := _setting("voice_volume", 1.0)
	if vol <= 0.0:
		return false
	var st := _load(VOICE_DIR + voice_id(who, text) + ".mp3", false)
	if st == null:
		return false
	voice.stream = st
	voice.volume_db = linear_to_db(vol)
	voice.play()
	return true


## 播放一个音效（tools/gen_sfx.py 合成的 ogg），跟随配音音量。
func play_sfx(key: String, volume := 1.0) -> void:
	var vol := _setting("voice_volume", 1.0) * volume
	if vol <= 0.0:
		return
	var path := SFX_DIR + key + ".ogg"
	var st: AudioStream = _cache.get(path)
	if st == null and ResourceLoader.exists(path):
		st = load(path)
		_cache[path] = st
	if st == null:
		return
	var p: AudioStreamPlayer = sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % sfx.size()
	p.stream = st
	p.volume_db = linear_to_db(vol)
	p.play()


func stop_voice() -> void:
	if voice != null and voice.playing:
		voice.stop()


## 切换 BGM（同一首不重播），1 秒交叉淡化。key 为空则淡出。
func play_bgm(key: String) -> void:
	if key == current_bgm:
		return
	var st: AudioStream = null
	if key != "":
		st = _load(BGM_DIR + key + ".mp3", true)
		if st == null:
			return  # 没有这首就保持当前音乐
	current_bgm = key
	var old := bgm_a if bgm_a.playing else bgm_b
	var new := bgm_b if old == bgm_a else bgm_a
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, 1.0)
		tw.tween_callback(old.stop)
	if st == null:
		return
	new.stream = st
	new.volume_db = -40.0
	new.play()
	var target := linear_to_db(maxf(0.0001, _setting("bgm_volume", 0.7)))
	if _setting("bgm_volume", 0.7) <= 0.0:
		new.stop()
		return
	create_tween().tween_property(new, "volume_db", target, 1.0)


## 设置里改了音量后调用。
func apply_volume() -> void:
	var v := _setting("bgm_volume", 0.7)
	for p in [bgm_a, bgm_b]:
		if p.playing:
			if v <= 0.0:
				p.stop()
			else:
				p.volume_db = linear_to_db(v)
	if v > 0.0 and not bgm_a.playing and not bgm_b.playing and current_bgm != "":
		var k := current_bgm
		current_bgm = ""
		play_bgm(k)


func _setting(key: String, def: float) -> float:
	return float(Game.s.get("settings", {}).get(key, def))


func _exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _load(path: String, loop: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
	elif FileAccess.file_exists(path):
		# 未导入（刚生成、还没用编辑器打开过）时直接读字节
		var mp3 := AudioStreamMP3.new()
		mp3.data = FileAccess.get_file_as_bytes(path)
		st = mp3
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = loop
	if loop and st != null:
		_cache[path] = st  # 只缓存 BGM，配音太多不缓存
	return st
