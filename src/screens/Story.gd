extends "res://src/screens/BaseScreen.gd"
## 剧情播放器（视觉小说）：背景、立绘、打字机对话、选项、好感、战斗穿插、记录、自动/跳过。
## 剧本在 data/story.json，行类型：title / say / bg / cg / cg_end / choice / battle / aff。
## say 的 who 可以是角色 id、narrator、me，或 npc（配合 name 字段，用于局长等配角）。
## cg 会铺满全屏并解锁到「回忆」相册，直到 cg_end 或本节结束。
## touch 是约会里的触碰互动：在立绘上点亮几个部位，每碰一处他会回应并加好感，全部碰完后继续。
## params 里传 date=<约会 id> 时以约会模式播放（data/dates.json），结束时按约会结算。

const TYPE_SPEED := 26.0  # 每秒字数（×设置里的倍率）

var ch_id := ""
var sc_id := ""
var scene_data: Dictionary = {}
var lines: Array = []
var idx := -1
var typing := false
var auto := false
var skipping := false
var ended := false
var history: Array = []
var gained: Dictionary = {}

var bg_rect: TextureRect
var portrait: TextureRect
var dialog_panel: PanelContainer
var name_tag: PanelContainer
var name_label: Label
var text_label: Label
var hint_label: Label
var choice_layer: Control = null
var title_layer: Control = null
var type_tween: Tween = null
var auto_btn: Button
var skip_btn: Button
var current_portrait_key := ""
var cg_rect: TextureRect
var cg_active := false
var date_id := ""
var touch_layer: Control = null
var touch_left := 0
var touch_bar: ProgressBar


func build() -> void:
	date_id = str(params.get("date", ""))
	if date_id != "":
		scene_data = Data.date(date_id)
	else:
		ch_id = str(params.get("chapter", "ch1"))
		sc_id = str(params.get("scene", "s1"))
		scene_data = Data.scene(ch_id, sc_id)
	lines = Array(scene_data.get("lines", [])).duplicate()

	bg_rect = UIKit.image(Data.texture(str(scene_data.get("bg", "backgrounds/harbor_night"))))
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg_rect)

	portrait = UIKit.image(Data.texture("characters/shen_yan/calm"), false)
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_top = 140
	portrait.offset_bottom = -470
	portrait.visible = false
	add_child(portrait)

	cg_rect = UIKit.image(null)
	cg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cg_rect.visible = false
	add_child(cg_rect)

	var grad := UIKit.gradient_rect(Color(0, 0, 0, 0), Color(0, 0, 0, 0.9))
	grad.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grad.offset_top = -760
	add_child(grad)

	# 点击任意处推进
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_advance())
	add_child(catcher)

	_build_dialog()
	_build_top_buttons()
	Audio.play_bgm(str(scene_data.get("bgm", "daily" if date_id != "" else "story")))
	_next()


func _build_dialog() -> void:
	var m := UIKit.margin(30, 0, 30, 60)
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.offset_top = -470
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_tag = UIKit.panel(UIKit.C_ACCENT, 18, 12)
	name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	name_label = UIKit.label("", 30, UIKit.C_BG, HORIZONTAL_ALIGNMENT_CENTER, false)
	name_tag.add_child(name_label)
	v.add_child(name_tag)
	dialog_panel = UIKit.panel(Color(0.04, 0.05, 0.14, 0.82), 26, 30, Color(1, 1, 1, 0.12), 2)
	dialog_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_panel.custom_minimum_size = Vector2(0, 330)
	var dv := UIKit.vbox(10)
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label = UIKit.label("", 36, UIKit.C_TEXT)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(text_label)
	hint_label = UIKit.label("▼ 点击继续", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	dv.add_child(hint_label)
	dialog_panel.add_child(dv)
	v.add_child(dialog_panel)
	m.add_child(v)
	add_child(m)


func _build_top_buttons() -> void:
	var h := UIKit.hbox(10)
	h.set_anchors_preset(Control.PRESET_TOP_WIDE)
	h.offset_top = 56
	h.offset_left = 24
	h.offset_right = -24
	h.alignment = BoxContainer.ALIGNMENT_END
	var title := UIKit.label(str(scene_data.get("title", "")), 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(title)
	auto_btn = UIKit.button("自动", "dark", 26, 64)
	auto_btn.custom_minimum_size = Vector2(110, 64)
	auto_btn.pressed.connect(func() -> void:
		auto = not auto
		skipping = false
		_refresh_mode_buttons()
		if auto and not typing:
			_advance())
	skip_btn = UIKit.button("跳过", "dark", 26, 64)
	skip_btn.custom_minimum_size = Vector2(110, 64)
	skip_btn.pressed.connect(func() -> void:
		skipping = not skipping
		auto = false
		_refresh_mode_buttons()
		if skipping:
			_advance())
	var log_btn := UIKit.button("记录", "dark", 26, 64)
	log_btn.custom_minimum_size = Vector2(110, 64)
	log_btn.pressed.connect(_show_history)
	var back := UIKit.button("退出", "dark", 26, 64)
	back.custom_minimum_size = Vector2(110, 64)
	back.pressed.connect(func() -> void:
		Router.confirm("退出本节？", "本节进度不会保存。", func() -> void: Router.back()))
	for b in [auto_btn, skip_btn, log_btn, back]:
		h.add_child(b)
	add_child(h)


func _refresh_mode_buttons() -> void:
	auto_btn.add_theme_color_override("font_color", UIKit.C_ACCENT if auto else UIKit.C_TEXT)
	skip_btn.add_theme_color_override("font_color", UIKit.C_ACCENT if skipping else UIKit.C_TEXT)


# ---------------- 推进 ----------------

func _advance() -> void:
	if ended:
		return
	if title_layer != null:
		title_layer.queue_free()
		title_layer = null
		dialog_panel.visible = true
		_next()
		return
	if choice_layer != null:
		return
	if touch_layer != null:
		if typing:
			_finish_typing()
		elif touch_left <= 0:
			touch_layer.queue_free()
			touch_layer = null
			_next()
		return
	if typing:
		_finish_typing()
		return
	_next()


func _next() -> void:
	idx += 1
	if idx >= lines.size():
		_end()
		return
	var line: Dictionary = lines[idx]
	match str(line.get("t", "say")):
		"say":
			_show_say(line)
		"title":
			_show_title(str(line.get("text", "")))
		"bg":
			bg_rect.texture = Data.texture(str(line.get("key", "")))
			UIKit.fade_in(bg_rect, 0.5)
			_next()
		"cg":
			_show_cg(str(line.get("key", "")))
			_next()
		"cg_end":
			_hide_cg()
			_next()
		"choice":
			_show_choice(line)
		"touch":
			_show_touch(line)
		"battle":
			_start_battle(line)
		"aff":
			_gain_affection(str(line.get("who", "")), int(line.get("n", 0)))
			_next()
		_:
			_next()


func _show_say(line: Dictionary) -> void:
	var who := str(line.get("who", "narrator"))
	var text := str(line.get("text", "")).replace("{name}", Game.player_name())
	var speaker := ""
	if Data.characters.has(who) and not skipping:
		Audio.play_voice(who, str(line.get("text", "")))
	else:
		Audio.stop_voice()
	if who == "narrator":
		name_tag.visible = false
		portrait.modulate = Color(0.55, 0.55, 0.65)
		text_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.95))
	elif who == "npc":
		speaker = str(line.get("name", "？？？"))
		name_tag.visible = true
		name_tag.add_theme_stylebox_override("panel", UIKit.sb(Color(0.62, 0.66, 0.78), 18, Color.TRANSPARENT, 0, 12))
		portrait.modulate = Color(0.55, 0.55, 0.65)
		text_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	elif who == "me":
		speaker = Game.player_name()
		name_tag.visible = true
		name_tag.add_theme_stylebox_override("panel", UIKit.sb(UIKit.C_ROSE, 18, Color.TRANSPARENT, 0, 12))
		portrait.modulate = Color(0.7, 0.7, 0.78)
		text_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	else:
		var ch := Data.character(who)
		speaker = str(ch.get("name", who))
		name_tag.visible = true
		name_tag.add_theme_stylebox_override("panel", UIKit.sb(Color(str(ch.get("color", "#4fd1c5"))), 18, Color.TRANSPARENT, 0, 12))
		var key := Data.portrait_key(who, str(line.get("expr", "calm")))
		if key != current_portrait_key:
			current_portrait_key = key
			portrait.texture = Data.texture(key)
			portrait.visible = not cg_active
			if not cg_active:
				UIKit.fade_in(portrait, 0.25)
		portrait.modulate = Color(1, 1, 1)
		text_label.add_theme_color_override("font_color", UIKit.C_TEXT)
	name_label.text = speaker
	if touch_layer == null:
		hint_label.text = "▼ 点击继续"
	history.append({"who": speaker, "text": text})
	_type(text)


func _type(text: String) -> void:
	text_label.text = text
	text_label.visible_ratio = 0.0
	hint_label.visible = false
	typing = true
	if type_tween != null and type_tween.is_valid():
		type_tween.kill()
	var speed := TYPE_SPEED * float(Game.s.settings.get("text_speed", 1.0))
	var dur := maxf(0.05, float(text.length()) / speed)
	if skipping:
		dur = 0.05
	type_tween = create_tween()
	type_tween.tween_property(text_label, "visible_ratio", 1.0, dur)
	type_tween.tween_callback(_on_typed)


func _finish_typing() -> void:
	if type_tween != null and type_tween.is_valid():
		type_tween.kill()
	text_label.visible_ratio = 1.0
	_on_typed()


func _on_typed() -> void:
	typing = false
	hint_label.visible = true
	if skipping:
		await get_tree().create_timer(0.12).timeout
		if skipping and not ended and choice_layer == null:
			_advance()
	elif auto:
		await get_tree().create_timer(1.6).timeout
		if auto and not typing and not ended and choice_layer == null:
			_advance()


func _show_cg(key: String) -> void:
	if key == "":
		return
	Game.unlock_cg(key)
	cg_rect.texture = Data.texture(key)
	cg_rect.visible = true
	cg_active = true
	portrait.visible = false
	UIKit.fade_in(cg_rect, 0.8)


func _hide_cg() -> void:
	if not cg_active:
		return
	cg_active = false
	portrait.visible = current_portrait_key != ""
	var tw := cg_rect.create_tween()
	tw.tween_property(cg_rect, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		cg_rect.visible = false
		cg_rect.modulate.a = 1.0)


# ---------------- 触碰互动（约会） ----------------

func _show_touch(line: Dictionary) -> void:
	var who := str(line.get("who", ""))
	current_portrait_key = Data.portrait_key(who, "calm")
	portrait.texture = Data.texture(current_portrait_key)
	portrait.visible = true
	portrait.modulate = Color(1, 1, 1)
	_hide_cg()
	var spots: Array = line.get("spots", [])
	touch_left = spots.size()
	touch_layer = Control.new()
	touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_layer)

	var top := UIKit.vbox(8)
	top.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	top.offset_top = -560
	top.offset_bottom = -490
	top.offset_left = 120
	top.offset_right = -120
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(UIKit.label("♥ " + str(line.get("hint", "触碰他")), 30, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	touch_bar = UIKit.progress(0, spots.size(), UIKit.C_ROSE, 16)
	top.add_child(touch_bar)
	touch_layer.add_child(top)

	name_tag.visible = false
	text_label.text = "（点击他身上发光的地方）"
	text_label.visible_ratio = 1.0
	hint_label.visible = false
	await get_tree().process_frame
	var area := _portrait_draw_rect()
	for sp in spots:
		var pos: Array = sp.get("pos", [0.5, 0.3])
		var center := area.position + Vector2(float(pos[0]) * area.size.x, float(pos[1]) * area.size.y)
		touch_layer.add_child(_touch_spot(who, sp, center))


## 立绘在屏幕上实际绘制的区域（KEEP_ASPECT_CENTERED）。
func _portrait_draw_rect() -> Rect2:
	var r := portrait.get_rect()
	var tex := portrait.texture
	if tex == null or tex.get_width() == 0:
		return r
	var ts := Vector2(tex.get_width(), tex.get_height())
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var sz := ts * k
	return Rect2(r.position + (r.size - sz) / 2.0, sz)


func _touch_spot(who: String, sp: Dictionary, center: Vector2) -> Control:
	var d := 132.0
	var b := Button.new()
	b.size = Vector2(d, d)
	b.position = center - Vector2(d, d) / 2.0
	var ring := UIKit.sb(Color(1, 0.45, 0.7, 0.35), int(d / 2), Color(1, 0.85, 0.93, 0.95), 5)
	ring.shadow_color = Color(1, 0.5, 0.75, 0.6)
	ring.shadow_size = 18
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, ring)
	b.text = str(sp.get("name", ""))
	b.add_theme_font_size_override("font_size", 24)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(fc, Color(1, 1, 1))
	b.add_theme_color_override("font_outline_color", Color(0.5, 0.1, 0.3))
	b.add_theme_constant_override("outline_size", 6)
	b.pivot_offset = Vector2(d, d) / 2.0
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2(1.12, 1.12), 0.7)
	tw.tween_property(b, "scale", Vector2(1.0, 1.0), 0.7)
	b.pressed.connect(func() -> void:
		if typing:
			_finish_typing()
		tw.kill()
		b.queue_free()
		touch_left -= 1
		touch_bar.value = touch_bar.max_value - touch_left
		_gain_affection(who, int(sp.get("aff", 3)))
		_show_say({"who": who, "expr": str(sp.get("expr", "smile")), "text": str(sp.get("text", ""))})
		if touch_left <= 0:
			hint_label.text = "♥ 心动值已满 · 点击继续")
	return b


func _show_title(text: String) -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_layer.add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(16)
	v.add_child(UIKit.label(text, 48, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("—  点击继续  —", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	c.add_child(v)
	title_layer.add_child(c)
	add_child(title_layer)
	move_child(title_layer, get_child_count() - 2)
	UIKit.fade_in(title_layer, 0.6)
	dialog_panel.visible = false
	name_tag.visible = false
	if skipping or auto:
		await get_tree().create_timer(1.2 if auto else 0.3).timeout
		if title_layer != null and not ended:
			_advance()


func _show_choice(line: Dictionary) -> void:
	hint_label.visible = false
	choice_layer = Control.new()
	choice_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	choice_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := UIKit.margin(70, 0, 70, 520)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label("你会怎么说？", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	for opt in line.get("options", []):
		var b := UIKit.button(str(opt.get("text", "")), "dark", 32, 96)
		b.pressed.connect(func() -> void: _pick(opt))
		v.add_child(b)
	m.add_child(v)
	choice_layer.add_child(m)
	add_child(choice_layer)
	UIKit.fade_in(choice_layer, 0.25)


func _pick(opt: Dictionary) -> void:
	if choice_layer != null:
		choice_layer.queue_free()
		choice_layer = null
	history.append({"who": Game.player_name(), "text": str(opt.get("text", ""))})
	var aff: Dictionary = opt.get("aff", {})
	for who in aff.keys():
		_gain_affection(str(who), int(aff[who]))
	var extra: Array = opt.get("lines", [])
	for i in extra.size():
		lines.insert(idx + 1 + i, extra[i])
	_next()


func _gain_affection(who: String, n: int) -> void:
	if who == "" or n == 0:
		return
	var leveled := Game.add_affection(who, n)
	gained[who] = int(gained.get(who, 0)) + n
	var cname := Data.char_name(who)
	Router.toast("♥ %s 好感 +%d" % [cname, n] + ("   升级为「%s」！" % Game.affection_name(who) if leveled else ""), 1.6)


func on_resume(result: Variant) -> void:
	# 从战斗回来
	Audio.play_bgm(str(scene_data.get("bgm", "story")))
	if typeof(result) == TYPE_DICTIONARY and bool(result.get("win", false)):
		_next()
	else:
		Router.confirm("战斗失败", "再试一次？", func() -> void:
			_start_battle(lines[idx]),
			"再战", "退出")
		# “退出”时停留在本节，玩家可点退出按钮离开


## partner 为 "auto" 时，让战力最高的男主上场（终章 Boss 用）。
func _start_battle(line: Dictionary) -> void:
	var partner := str(line.get("partner", "shen_yan"))
	if partner == "auto":
		var best := -1
		for cid in Data.char_order:
			if Game.power(cid) > best:
				best = Game.power(cid)
				partner = cid
	Router.push("Battle", {"enemy": str(line.get("enemy", "tide_shade")), "partner": partner})


func _show_history() -> void:
	var panel := UIKit.panel(UIKit.C_PANEL, 28, 30, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(940, 1200)
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label("对话记录", 40, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var list := UIKit.vbox(10)
	for h in history:
		var who := str(h.who)
		var t := ("" if who == "" else "【%s】" % who) + str(h.text)
		list.add_child(UIKit.label(t, 28, UIKit.C_TEXT if who != "" else UIKit.C_MUTED))
	var sc := UIKit.scroll(list)
	sc.custom_minimum_size = Vector2(0, 980)
	v.add_child(sc)
	var close := UIKit.button("关闭", "ghost", 30, 84)
	v.add_child(close)
	panel.add_child(v)
	var dim := Router.modal(panel, true)
	close.pressed.connect(func() -> void: dim.queue_free())


# ---------------- 结束 ----------------

func _end() -> void:
	ended = true
	Audio.stop_voice()
	skipping = false
	auto = false
	if date_id != "":
		_end_date()
		return
	var first := Game.mark_scene_done(ch_id, sc_id)
	var reward: Dictionary = scene_data.get("reward", {})
	if first and reward.size() > 0:
		Game.grant(reward)
	# 解锁后续章节
	for ch in Data.chapters:
		if str(ch.get("requires", "")) == ch_id:
			var p := Game.chapter_progress(ch_id)
			if p[0] >= p[1]:
				Game.unlock_chapter(str(ch.id))

	var panel := UIKit.panel(UIKit.C_PANEL, 32, 40, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(900, 0)
	var v := UIKit.vbox(18)
	v.add_child(UIKit.label("本节完成", 46, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(str(scene_data.get("title", "")), 30, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if gained.size() > 0:
		var parts: Array = []
		for who in gained.keys():
			parts.append("%s ♥+%d" % [Data.char_name(str(who)), int(gained[who])])
		v.add_child(UIKit.label("、".join(parts), 30, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	if reward.size() > 0:
		v.add_child(UIKit.label(("首次通关奖励：" if first else "已领取过奖励：") + UIKit.reward_text(reward), 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var next_scene := _next_scene_id()
	var nb: Button = null
	if next_scene != "":
		nb = UIKit.button("下一节", "primary", 34, 96)
		v.add_child(nb)
	var back := UIKit.button("返回", "ghost", 32, 90)
	v.add_child(back)
	panel.add_child(v)
	var dim := Router.modal(panel, false)
	if nb != null:
		nb.pressed.connect(func() -> void:
			dim.queue_free()
			Router.back()
			Router.push("Story", {"chapter": ch_id, "scene": next_scene}))
	back.pressed.connect(func() -> void:
		dim.queue_free()
		Router.back())


func _end_date() -> void:
	var res := Game.finish_date(date_id)
	var cid := str(scene_data.get("char", ""))
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 40, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(900, 0)
	var v := UIKit.vbox(18)
	v.add_child(UIKit.label("约会结束", 46, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("和%s的「%s」" % [Data.char_name(cid), str(scene_data.get("title", ""))], 30, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var total := int(gained.get(cid, 0)) + int(res.get("affection", 0))
	v.add_child(UIKit.label("%s ♥+%d   当前「%s」" % [Data.char_name(cid), total, Game.affection_name(cid)], 30, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	var reward: Dictionary = res.get("reward", {})
	if reward.size() > 0:
		v.add_child(UIKit.label("首次约会奖励：" + UIKit.reward_text(reward) + "，回忆已收进相册", 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var back := UIKit.button("返回", "primary", 32, 90)
	v.add_child(back)
	panel.add_child(v)
	var dim := Router.modal(panel, false)
	back.pressed.connect(func() -> void:
		dim.queue_free()
		Router.back())


func _next_scene_id() -> String:
	var scenes: Array = Data.chapter(ch_id).get("scenes", [])
	for i in scenes.size():
		if str(scenes[i].id) == sc_id and i + 1 < scenes.size():
			return str(scenes[i + 1].id)
	return ""
