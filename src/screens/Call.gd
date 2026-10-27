extends "res://src/screens/BaseScreen.gd"
## 电话：全屏立绘 + 通话计时 + 逐句台词，有配音时播放配音。

var cid := ""
var lines: Array = []
var idx := -1
var seconds := 0.0
var timer_label: Label
var line_label: Label
var next_btn: Button
var finished := false


func build() -> void:
	cid = str(params.get("char", "shen_yan"))
	var call: Dictionary = Data.calls.get(cid, {})
	lines = Array(call.get("lines", []))
	var ch := Data.character(cid)

	var bg := UIKit.image(Data.texture(str(ch.get("home_bg", ""))))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.35, 0.37, 0.5)
	add_child(bg)
	var portrait := UIKit.image(Data.texture(Data.portrait_key(cid, "smile")), false)
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.offset_top = 260
	portrait.offset_bottom = -520
	portrait.material = UIKit.portrait_material()
	add_child(portrait)
	add_child(UIKit.gradient_rect(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.9)))

	var m := UIKit.margin(50, 90, 50, 70)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label(Data.char_name(cid), 60, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label(str(call.get("title", "来电")), 28, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	timer_label = UIKit.label("通话中 00:00", 26, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(timer_label)
	v.add_child(UIKit.spacer())
	var panel := UIKit.panel(Color(0.04, 0.05, 0.14, 0.8), 26, 30, Color(1, 1, 1, 0.12), 2)
	panel.custom_minimum_size = Vector2(0, 220)
	line_label = UIKit.label("……", 34, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(line_label)
	v.add_child(panel)
	var row := UIKit.hbox(14)
	next_btn = UIKit.button("继续听", "primary", 30, 96)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.pressed.connect(_next)
	var hang := UIKit.button("挂断", "danger", 30, 96)
	hang.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hang.pressed.connect(func() -> void:
		Audio.stop_voice()
		Router.back())
	row.add_child(next_btn)
	row.add_child(hang)
	v.add_child(row)
	m.add_child(v)
	add_child(m)
	_next()


func _process(delta: float) -> void:
	if finished:
		return
	seconds += delta
	timer_label.text = "通话中 %02d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _next() -> void:
	idx += 1
	if idx >= lines.size():
		finished = true
		Audio.stop_voice()
		line_label.text = "（通话结束）"
		next_btn.disabled = true
		var key := "call_" + Game.today()
		var st := Game.chat_state(cid)
		if not st.has(key):
			st[key] = true
			Game.add_affection(cid, 3)
			Router.toast("♥ %s 好感 +3" % Data.char_name(cid))
		else:
			Game.save()
		return
	line_label.text = str(lines[idx])
	Audio.play_voice(cid, str(lines[idx]))
	UIKit.fade_in(line_label, 0.3)
	if idx == lines.size() - 1:
		next_btn.text = "结束通话"
