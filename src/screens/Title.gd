extends "res://src/screens/BaseScreen.gd"
## 标题页：Logo、开始/继续、首次进入时取名。


func build() -> void:
	Audio.play_bgm("title")
	add_child(UIKit.gradient_rect(UIKit.C_BG, UIKit.C_BG2))
	# 主视觉：缓慢推近，营造“镜头在呼吸”的感觉
	var kv_key := "ui/title_kv" if Data.has_real_texture("ui/title_kv") else "backgrounds/title"
	var bg := UIKit.image(Data.texture(kv_key))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.pivot_offset = Vector2(540, 960)
	add_child(bg)
	var zoom := bg.create_tween().set_loops()
	zoom.tween_property(bg, "scale", Vector2(1.06, 1.06), 9.0).set_trans(Tween.TRANS_SINE)
	zoom.tween_property(bg, "scale", Vector2.ONE, 9.0).set_trans(Tween.TRANS_SINE)
	# 上下两层柔光遮罩，让 Logo 和按钮更清晰
	var top_fade := UIKit.gradient_rect(Color(0.07, 0.04, 0.16, 0.55), Color(0.07, 0.04, 0.16, 0.0))
	top_fade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_fade.custom_minimum_size = Vector2(0, 700)
	add_child(top_fade)
	var bottom_fade := UIKit.gradient_rect(Color(0.07, 0.04, 0.16, 0.0), Color(0.09, 0.05, 0.18, 0.94))
	bottom_fade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_fade.offset_top = -820
	add_child(bottom_fade)
	add_child(UIKit.sparkles(Rect2(0, 0, 1080, 1920), 46))
	add_child(UIKit.sparkles(Rect2(0, 1200, 1080, 720), 20, UIKit.C_GOLD))

	# Logo
	var logo := TextureRect.new()
	logo.texture = Data.texture(Data.LOGO_KEY)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(60, 150)
	logo.size = Vector2(960, 640)
	logo.pivot_offset = logo.size / 2
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.92, 0.92)
	var t := logo.create_tween().set_parallel()
	t.tween_property(logo, "modulate:a", 1.0, 1.2)
	t.tween_property(logo, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drift := logo.create_tween().set_loops()
	drift.tween_property(logo, "position:y", 168.0, 3.2).set_trans(Tween.TRANS_SINE)
	drift.tween_property(logo, "position:y", 150.0, 3.2).set_trans(Tween.TRANS_SINE)

	var m := UIKit.safe_margin(110, 0, 110, 120)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(22)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UIKit.label("— 潮汐与星轨之间，有人在等你 —", 34, Color(1, 0.93, 0.97), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(40, false))

	var start := UIKit.button("♡  继续故事" if Game.has_save() else "♡  开始故事", "primary", 42, 120)
	start.pressed.connect(_on_start)
	v.add_child(start)
	start.pivot_offset = Vector2(430, 60)
	var pulse := start.create_tween().set_loops()
	pulse.tween_property(start, "modulate", Color(1.12, 1.05, 1.1), 1.1).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(start, "modulate", Color.WHITE, 1.1).set_trans(Tween.TRANS_SINE)
	if Game.has_save():
		v.add_child(UIKit.label("欢迎回来，%s ✦" % Game.player_name(), 30, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(36, false))
	v.add_child(UIKit.label("v%s · 澜城 2049" % ProjectSettings.get_setting("application/config/version", "0.3"), 22, Color(0.85, 0.78, 0.92, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	m.add_child(v)
	add_child(m)
	UIKit.fade_in(v, 1.0)


func _on_start() -> void:
	if Game.has_save():
		Router.go("Home")
		return
	_ask_name()


func _ask_name() -> void:
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 40, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(880, 0)
	var v := UIKit.vbox(20)
	v.add_child(UIKit.label("你的名字", 44, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("他们会这样称呼你，之后可以在「我的」里修改。", 28, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var edit := UIKit.line_edit("输入 1–10 个字")
	edit.max_length = 10
	v.add_child(edit)
	var ok := UIKit.button("♡  进入澜城", "primary", 36, 100)
	v.add_child(ok)
	panel.add_child(v)
	var dim := Router.modal(panel, false)
	var confirm := func() -> void:
		var n := edit.text.strip_edges()
		if n == "":
			n = "观测员"
		Game.set_player_name(n)
		dim.queue_free()
		Router.go("Story", {"chapter": "ch1", "scene": "s1"})
	ok.pressed.connect(confirm)
	edit.text_submitted.connect(func(_t: String) -> void: confirm.call())
	edit.grab_focus()
