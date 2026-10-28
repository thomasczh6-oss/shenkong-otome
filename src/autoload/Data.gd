extends Node
## 静态数据：角色、思念卡、许愿池、剧情、消息、商店等都来自 data/*.json。
## 图片统一通过 texture(key) 取：优先 user://gen（游戏内生成）→ res://assets/gen（流水线生成）→ 占位渐变。

var characters: Dictionary = {}
var char_order: Array = []
var cards: Dictionary = {}
var card_order: Array = []
var gacha: Dictionary = {}
var chapters: Array = []
var chapter_by_id: Dictionary = {}
var chats: Dictionary = {}
var calls: Dictionary = {}
var moments: Array = []
var shop: Dictionary = {}
var enemies: Dictionary = {}
## 约会（data/dates.json）
var dates_cfg: Dictionary = {}
var dates: Array = []
var date_by_id: Dictionary = {}
## 美术清单（assets/manifest.json）：key → 生图提示词，游戏内「AI 工坊」会用到。
var manifest: Dictionary = {}

var _tex_cache: Dictionary = {}


## 正式 Logo（assets/gen/ui/logo_N.png），换一版只改这里。
const LOGO_KEY := "ui/logo_1"


func _ready() -> void:
	load_all()


func load_all() -> void:
	var ch: Dictionary = _json("res://data/characters.json")
	for c in ch.get("characters", []):
		characters[c.id] = c
		char_order.append(c.id)

	var cd: Dictionary = _json("res://data/cards.json")
	for c in cd.get("cards", []):
		cards[c.id] = c
		card_order.append(c.id)

	gacha = _json("res://data/gacha.json")

	var st: Dictionary = _json("res://data/story.json")
	chapters = st.get("chapters", [])
	for c in chapters:
		chapter_by_id[c.id] = c

	var ms: Dictionary = _json("res://data/messages.json")
	chats = ms.get("chats", {})
	calls = ms.get("calls", {})
	moments = ms.get("moments", [])

	shop = _json("res://data/shop.json")
	enemies = _json("res://data/enemies.json").get("enemies", {})
	dates_cfg = _json("res://data/dates.json")
	dates = dates_cfg.get("dates", [])
	for d in dates:
		date_by_id[d.id] = d
	if FileAccess.file_exists("res://assets/manifest.json"):
		manifest = _json("res://assets/manifest.json")


## 清单里某个 key 的生图提示词（没有则返回空字符串）。
func prompt_for(key: String) -> String:
	for a in manifest.get("assets", []):
		if str(a.get("key", "")) == key:
			return str(a.get("prompt", ""))
	return ""


func manifest_keys() -> Array:
	var out: Array = []
	for a in manifest.get("assets", []):
		out.append(str(a.get("key", "")))
	return out


func _json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("读取失败: " + path)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("JSON 格式错误: " + path)
		return {}
	return parsed


# ---------------- 查询 ----------------

func character(cid: String) -> Dictionary:
	return characters.get(cid, {})


func char_name(cid: String) -> String:
	return str(character(cid).get("name", cid))


func cards_of(cid: String) -> Array:
	var out: Array = []
	for id in card_order:
		if str(cards[id].get("char", "")) == cid:
			out.append(id)
	return out


func chapter(ch_id: String) -> Dictionary:
	return chapter_by_id.get(ch_id, {})


func scene(ch_id: String, scene_id: String) -> Dictionary:
	for s in chapter(ch_id).get("scenes", []):
		if str(s.id) == scene_id:
			return s
	return {}


func date(id: String) -> Dictionary:
	return date_by_id.get(id, {})


func dates_of(cid: String) -> Array:
	var out: Array = []
	for d in dates:
		if str(d.get("char", "")) == cid:
			out.append(d)
	return out


## 主线与约会里出现的全部 CG（按剧情顺序，约会在后）：[{key, chapter_title, scene_title, char}]。
func cg_list() -> Array:
	var out: Array = []
	for ch in chapters:
		for sc in ch.get("scenes", []):
			for line in sc.get("lines", []):
				if str(line.get("t", "")) == "cg":
					out.append({"key": str(line.key), "chapter": str(ch.id), "chapter_title": str(ch.title),
						"scene": str(sc.id), "scene_title": str(sc.title), "char": str(sc.get("char", ""))})
	for d in dates:
		for line in d.get("lines", []):
			if str(line.get("t", "")) == "cg":
				out.append({"key": str(line.key), "chapter": "date", "chapter_title": "约会 · " + char_name(str(d.char)),
					"scene": str(d.id), "scene_title": str(d.title), "char": str(d.char)})
	return out


func enemy(eid: String) -> Dictionary:
	return enemies.get(eid, {})


# ---------------- 图片 ----------------

func texture(key: String) -> Texture2D:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var tex: Texture2D = null
	var user_path := "user://gen/%s.png" % key
	if FileAccess.file_exists(user_path):
		tex = _load_runtime(user_path)
	if tex == null:
		for ext in ["png", "jpg", "webp"]:
			var res_path := "res://assets/gen/%s.%s" % [key, ext]
			if ResourceLoader.exists(res_path):
				tex = load(res_path)
			elif FileAccess.file_exists(res_path):
				tex = _load_runtime(res_path)
			if tex != null:
				break
	if tex == null:
		tex = placeholder(key)
	_tex_cache[key] = tex
	return tex


## 动态思念（tools/gen_video.py 生成的 Ogg Theora），没有则返回 null。
func card_video(card_id: String) -> VideoStream:
	var path := "res://assets/video/cards/%s.ogv" % card_id
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var st := VideoStreamTheora.new()
		st.file = path
		return st
	return null


func has_real_texture(key: String) -> bool:
	if FileAccess.file_exists("user://gen/%s.png" % key):
		return true
	for ext in ["png", "jpg", "webp"]:
		if FileAccess.file_exists("res://assets/gen/%s.%s" % [key, ext]):
			return true
	return false


func invalidate(key: String) -> void:
	_tex_cache.erase(key)


func _load_runtime(path: String) -> Texture2D:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


## 没有美术时的占位：按 key 哈希出一个稳定的渐变色。
func placeholder(key: String) -> Texture2D:
	var h := absi(key.hash())
	var hue := float(h % 360) / 360.0
	var g := Gradient.new()
	g.set_color(0, Color.from_hsv(hue, 0.55, 0.55))
	g.set_color(1, Color.from_hsv(fmod(hue + 0.12, 1.0), 0.6, 0.2))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 256
	gt.fill_from = Vector2(0.2, 0.0)
	gt.fill_to = Vector2(0.8, 1.0)
	return gt


## 角色立绘 key：characters/<id>/<表情>，表情缺失时退回 calm。
func portrait_key(cid: String, expression := "calm") -> String:
	var key := "characters/%s/%s" % [cid, expression]
	if expression != "calm" and not has_real_texture(key):
		return "characters/%s/calm" % cid
	return key
