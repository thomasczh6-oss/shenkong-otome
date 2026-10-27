extends "res://src/screens/BaseScreen.gd"
## 主页：当前搭档立绘 + 好感 + 货币 + 各功能入口。

var cid: String = ""


func build() -> void:
	cid = str(Game.s.get("favorite", ""))
	if not Data.characters.has(cid):
		cid = str(Data.char_order[0])
		Game.s.favorite = cid
	var ch := Data.character(cid)

	# 背景与立绘
	var bg := UIKit.image(Data.texture(str(ch.get("home_bg", "backgrounds/harbor_night"))))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.7, 0.74, 0.9)
	add_child(bg)
	var portrait := UIKit.image(Data.texture(Data.portrait_key(cid, "calm")), false)
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_top = 170
	portrait.offset_bottom = -560
	add_child(portrait)
	UIKit.fade_in(portrait, 0.4)
	var grad := UIKit.gradient_rect(Color(0.04, 0.06, 0.15, 0.0), Color(0.04, 0.06, 0.15, 0.97))
	grad.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	grad.offset_top = -900
	add_child(grad)

	# 触摸立绘：他会说一句话
	var touch := Button.new()
	touch.flat = true
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.offset_top = 170
	touch.offset_bottom = -560
	touch.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	touch.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	touch.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	touch.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	touch.pressed.connect(func() -> void:
		Router.toast("%s：%s" % [ch.name, ch.get("greet", "……")], 2.4)
		UIKit.pop(portrait, 0.97, 0.3))
	add_child(touch)

	var m := UIKit.margin(30, 60, 30, 36)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_top_bar())
	v.add_child(_side_buttons())
	v.add_child(UIKit.spacer())
	v.add_child(_char_panel(ch))
	v.add_child(_nav())
	m.add_child(v)
	add_child(m)


func on_resume(_result: Variant) -> void:
	rebuild()


func _top_bar() -> Control:
	var h := UIKit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := UIKit.pill("观测员 · " + Game.player_name(), UIKit.C_ROSE, 26)
	h.add_child(who)
	h.add_child(UIKit.spacer(0, true))
	h.add_child(UIKit.currency("◆", Game.diamonds(), UIKit.C_ACCENT))
	h.add_child(UIKit.currency("✦", Game.tickets("limited") + Game.tickets("standard"), UIKit.C_GOLD))
	var plus := UIKit.button("＋", "gold", 30, 56)
	plus.custom_minimum_size = Vector2(56, 56)
	plus.pressed.connect(func() -> void: Router.push("Shop"))
	h.add_child(plus)
	return h


func _side_buttons() -> Control:
	var row := UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UIKit.spacer(0, true))
	var col := UIKit.vbox(10)
	var items := [
		["签到", func() -> void: Router.push("Daily", {"tab": 3}), Game.can_signin()],
		["任务", func() -> void: Router.push("Daily", {"tab": 3}), false],
		["商店", func() -> void: Router.push("Shop"), false],
		["我的", func() -> void: Router.push("Profile"), false],
	]
	for it in items:
		var b := UIKit.button(str(it[0]) + ("  ●" if it[2] else ""), "dark", 26, 72)
		b.custom_minimum_size = Vector2(150, 72)
		if it[2]:
			b.add_theme_color_override("font_color", UIKit.C_ROSE)
		b.pressed.connect(it[1])
		col.add_child(b)
	row.add_child(col)
	return row


func _char_panel(ch: Dictionary) -> Control:
	var h := UIKit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var prev := UIKit.button("‹", "dark", 44, 110)
	prev.custom_minimum_size = Vector2(80, 110)
	prev.pressed.connect(func() -> void: _switch(-1))
	var next := UIKit.button("›", "dark", 44, 110)
	next.custom_minimum_size = Vector2(80, 110)
	next.pressed.connect(func() -> void: _switch(1))

	var panel := UIKit.panel(Color(0.03, 0.04, 0.1, 0.55), 28, 24, Color(1, 1, 1, 0.1), 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UIKit.vbox(8)
	var name_row := UIKit.hbox(14)
	var n := UIKit.label(str(ch.name), 56, Color(str(ch.get("color", "#ffffff"))), HORIZONTAL_ALIGNMENT_LEFT, false)
	name_row.add_child(n)
	name_row.add_child(UIKit.pill(str(ch.get("element", "")) + " · " + str(ch.get("evol", "")), UIKit.element_color(str(ch.get("element", ""))), 24))
	name_row.add_child(UIKit.spacer(0, true))
	name_row.add_child(UIKit.label("战力 %d" % Game.power(cid), 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
	v.add_child(name_row)
	v.add_child(UIKit.label(str(ch.get("title", "")), 26, UIKit.C_MUTED))
	v.add_child(UIKit.label("「" + str(ch.get("tagline", "")) + "」", 28, UIKit.C_TEXT))
	var aff_row := UIKit.hbox(10)
	aff_row.add_child(UIKit.label("♥ Lv.%d %s" % [Game.affection_level(cid), Game.affection_name(cid)], 26, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_LEFT, false))
	var prog := Game.affection_progress(cid)
	var bar := UIKit.progress(prog[0], prog[1], UIKit.C_ROSE, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	aff_row.add_child(bar)
	aff_row.add_child(UIKit.label("%d/%d" % [prog[0], prog[1]], 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
	v.add_child(aff_row)
	panel.add_child(v)

	h.add_child(prev)
	h.add_child(panel)
	h.add_child(next)
	return h


func _switch(dir: int) -> void:
	var i := Data.char_order.find(cid)
	i = posmod(i + dir, Data.char_order.size())
	Game.s.favorite = Data.char_order[i]
	Game.save()
	rebuild()


func _nav() -> Control:
	var h := UIKit.hbox(10)
	var items := [
		["主线", "剧情", func() -> void: Router.push("Chapters")],
		["日常", "约会", func() -> void: Router.push("Daily")],
		["思念", "卡牌", func() -> void: Router.push("Cards")],
		["许愿", "抽卡", func() -> void: Router.push("Gacha")],
		["我的", "设置", func() -> void: Router.push("Profile")],
	]
	for it in items:
		var b := UIKit.button(str(it[0]), "dark", 32, 118)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[2])
		h.add_child(b)
	return h
