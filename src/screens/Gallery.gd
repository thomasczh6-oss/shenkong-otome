extends "res://src/screens/BaseScreen.gd"
## 回忆：剧情 CG 相册。看过的 CG 自动解锁，点开全屏欣赏；未解锁的显示出处。

var filter_char := ""


func build() -> void:
	var all: Array = Data.cg_list()
	var got := 0
	for e in all:
		if Game.cg_unlocked(str(e.key)):
			got += 1
	var page := UIKit.page("回忆", func() -> void: Router.back(), UIKit.pill("已解锁 %d / %d" % [got, all.size()], UIKit.C_ROSE, 22))
	var v: VBoxContainer = page[1]

	var chips := UIKit.hbox(8)
	chips.add_child(_chip("全部", filter_char == "", ""))
	for cid in Data.char_order:
		chips.add_child(_chip(Data.char_name(cid), filter_char == cid, cid))
	v.add_child(chips)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 22)
	for e in all:
		if filter_char != "" and str(e.char) != filter_char:
			continue
		grid.add_child(_tile(e))
	v.add_child(UIKit.scroll(grid))
	add_child(page[0])


func _chip(text: String, active: bool, cid: String) -> Button:
	var b := UIKit.button(text, "primary" if active else "ghost", 24, 60)
	b.pressed.connect(func() -> void:
		filter_char = cid
		rebuild())
	return b


func _tile(e: Dictionary) -> Control:
	var key := str(e.key)
	var open := Game.cg_unlocked(key)
	var cid := str(e.char)
	var border := Color(str(Data.character(cid).get("color", "#f5c26b"))) if cid != "" else UIKit.C_GOLD
	var panel := UIKit.panel(UIKit.C_PANEL, 22, 10, border if open else UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(480, 0)
	var v := UIKit.vbox(8)
	var box: Control
	if open:
		box = UIKit.image_box(Data.texture(key), Vector2(460, 620), 16)
	else:
		box = UIKit.panel(Color(0.06, 0.07, 0.16), 16, 0)
		box.custom_minimum_size = Vector2(460, 620)
		var c := CenterContainer.new()
		var lv := UIKit.vbox(10)
		lv.add_child(UIKit.label("未解锁", 40, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		lv.add_child(UIKit.label("阅读剧情后解锁", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
		c.add_child(lv)
		box.add_child(c)
	v.add_child(box)
	v.add_child(UIKit.label(str(e.scene_title), 24, UIKit.C_TEXT if open else UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
	v.add_child(UIKit.label(str(e.chapter_title), 20, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
	panel.add_child(v)
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if open:
				_view(key)
			else:
				Router.toast("在「%s」中解锁" % str(e.scene_title)))
	return panel


## 全屏查看，点击任意处关闭。
func _view(key: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 1)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var img := UIKit.image(Data.texture(key), false)
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(img)
	var hint := UIKit.label("点击任意处关闭", 22, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER, false)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -80
	dim.add_child(hint)
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			dim.queue_free())
	Router.overlay.add_child(dim)
	UIKit.fade_in(dim, 0.25)
