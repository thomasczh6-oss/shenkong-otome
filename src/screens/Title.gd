extends "res://src/screens/BaseScreen.gd"
## 标题页：Logo、开始/继续、首次进入时取名。


func build() -> void:
	Audio.play_bgm("title")
	add_child(UIKit.gradient_rect(Color("0b1026"), Color("1d1b4b")))
	var bg := UIKit.image(Data.texture("backgrounds/title"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(1, 1, 1, 0.65)
	add_child(bg)
	add_child(UIKit.gradient_rect(Color(0.04, 0.06, 0.15, 0.0), Color(0.04, 0.06, 0.15, 0.96)))

	var m := UIKit.margin(80, 0, 80, 150)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := UIKit.vbox(18)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(UIKit.label("深与空恋", 150, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("D E E P  &  S K Y  L O V E", 30, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("潮汐与星轨之间，有人在等你。", 36, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(70, false))

	var start := UIKit.button("继续故事" if Game.has_save() else "开始故事", "primary", 40, 112)
	start.pressed.connect(_on_start)
	v.add_child(start)
	if Game.has_save():
		v.add_child(UIKit.label("欢迎回来，%s。" % Game.player_name(), 28, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.spacer(30, false))
	v.add_child(UIKit.label("原型版本 0.1 · Godot 4.4", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	m.add_child(v)
	add_child(m)
	UIKit.fade_in(v, 0.6)


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
	var ok := UIKit.button("进入澜城", "primary", 36, 100)
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
