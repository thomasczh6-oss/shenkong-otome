extends "res://src/screens/BaseScreen.gd"
## 委托：派男主去做一件事，现实时间到了回来领奖励、好感和一句委托手记。

var timer_labels: Dictionary = {}


func build() -> void:
	timer_labels.clear()
	var page := UIKit.page("委托", func() -> void: Router.back())
	var v: VBoxContainer = page[1]
	v.add_child(UIKit.label("派他去做一件事。时间到了，他会带着奖励和一句话回来找你。每位男主同时只能接一件委托。", 24, UIKit.C_MUTED))
	var list := UIKit.vbox(20)
	for cid in Data.char_order:
		list.add_child(_slot(str(cid)))
	v.add_child(UIKit.scroll(list))
	add_child(page[0])


func _process(_d: float) -> void:
	for cid in timer_labels.keys():
		var left := Game.commission_left(cid)
		var l: Label = timer_labels[cid]
		if not is_instance_valid(l):
			continue
		if left == 0:
			timer_labels.clear()
			rebuild()
			return
		l.text = "进行中 · 还剩 %s" % _fmt(left)


func _fmt(sec: int) -> String:
	return "%02d:%02d:%02d" % [sec / 3600, (sec / 60) % 60, sec % 60]


func _slot(cid: String) -> Control:
	var ch := Data.character(cid)
	var col := Color(str(ch.get("color", "#ffffff")))
	var panel := UIKit.panel(UIKit.C_PANEL, 28, 24, Color(col, 0.6), 2)
	var v := UIKit.vbox(12)
	var head := UIKit.hbox(16)
	head.add_child(UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(120, 120), 60))
	var hv := UIKit.vbox(4)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.label(str(ch.get("name", "")), 36, col, HORIZONTAL_ALIGNMENT_LEFT, false))
	var c := Game.commission_of(cid)
	if c.is_empty():
		hv.add_child(UIKit.label("空闲中，等你安排", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	else:
		var job := Game.commission_job(cid, str(c.tier))
		hv.add_child(UIKit.label("「%s」" % str(job.get("name", "")), 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	head.add_child(hv)
	v.add_child(head)

	if c.is_empty():
		for t in Data.commissions.get("tiers", []):
			v.add_child(_job_row(cid, t, col))
	elif Game.commission_left(cid) > 0:
		var tl := UIKit.label("", 26, UIKit.C_ROSE)
		timer_labels[cid] = tl
		tl.text = "进行中 · 还剩 %s" % _fmt(Game.commission_left(cid))
		v.add_child(tl)
		var job := Game.commission_job(cid, str(c.tier))
		v.add_child(UIKit.label(str(job.get("desc", "")), 24, UIKit.C_MUTED))
	else:
		var b := UIKit.button("他回来了 · 领取", "gold", 30, 92)
		b.pressed.connect(func() -> void: _collect(cid))
		v.add_child(b)
	panel.add_child(v)
	return panel


func _job_row(cid: String, t: Dictionary, col: Color) -> Control:
	var job := Game.commission_job(cid, str(t.id))
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 112)
	b.add_theme_stylebox_override("normal", UIKit.sb(Color(col, 0.08), 20, Color(col, 0.4), 2))
	b.add_theme_stylebox_override("hover", UIKit.sb(Color(col, 0.16), 20, col, 2))
	b.add_theme_stylebox_override("pressed", UIKit.sb(Color(col, 0.24), 20, col, 2))
	var h := UIKit.hbox(14)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_right = -20
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := UIKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(UIKit.label("%s · %d 小时" % [str(job.get("name", "")), int(t.hours)], 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	tv.add_child(UIKit.label(UIKit.reward_text(t.reward) + "、好感 +%d" % int(t.aff), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	h.add_child(tv)
	for n in h.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var tier_id := str(t.id)
	b.pressed.connect(func() -> void:
		if Game.start_commission(cid, tier_id):
			Router.toast("%s 出发了" % Data.char_name(cid), 1.4)
			rebuild())
	return b


func _collect(cid: String) -> void:
	var r := Game.collect_commission(cid)
	if r.is_empty():
		return
	var ch := Data.character(cid)
	var col := Color(str(ch.get("color", "#ffffff")))
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 30, Color(col, 0.8), 2)
	panel.custom_minimum_size = Vector2(880, 0)
	var v := UIKit.vbox(16)
	v.add_child(UIKit.label("委托手记", 36, col, HORIZONTAL_ALIGNMENT_CENTER))
	var face := UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(180, 180), 90)
	face.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(face)
	v.add_child(UIKit.label("「%s」" % str(r.note), 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("获得：" + UIKit.reward_text(r.reward) + "、%s好感 +%d" % [Data.char_name(cid), int(r.aff)], 24, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	if bool(r.leveled):
		v.add_child(UIKit.label("好感升级为「%s」！" % Game.affection_name(cid), 26, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("好", "primary", 30, 90)
	v.add_child(ok)
	panel.add_child(v)
	var holder := {"dim": null}
	ok.pressed.connect(func() -> void:
		if holder.dim != null and is_instance_valid(holder.dim):
			holder.dim.queue_free()
		rebuild())
	holder.dim = Router.modal(panel, true)


func on_resume(_result: Variant) -> void:
	rebuild()
