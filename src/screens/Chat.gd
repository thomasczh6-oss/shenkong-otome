extends "res://src/screens/BaseScreen.gd"
## 短信聊天：他的消息自动逐条弹出，到选项时由玩家选择回复，回复加好感。

var cid := ""
var steps: Array = []
var list: VBoxContainer
var scroll: ScrollContainer
var bottom: VBoxContainer
var playing := false


func build() -> void:
	cid = str(params.get("char", "shen_yan"))
	steps = Array(Data.chats.get(cid, {}).get("steps", []))
	var ch := Data.character(cid)
	var page := UIKit.page(Data.char_name(cid), func() -> void: Router.back(),
		UIKit.pill("♥ Lv.%d %s" % [Game.affection_level(cid), Game.affection_name(cid)], UIKit.C_ROSE, 22))
	var v: VBoxContainer = page[1]
	v.add_child(UIKit.label(str(ch.get("title", "")), 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	list = UIKit.vbox(14)
	scroll = UIKit.scroll(list)
	v.add_child(scroll)
	bottom = UIKit.vbox(10)
	v.add_child(bottom)
	add_child(page[0])

	var st := Game.chat_state(cid)
	for entry in st.get("log", []):
		_bubble(str(entry.get("from", "him")), str(entry.get("text", "")))
	_play()


func _bubble(from: String, text: String) -> void:
	var h := UIKit.hbox(10)
	var mine := from == "me"
	var w := mini(720, 44 + text.length() * 32)
	var panel := UIKit.panel(UIKit.C_ACCENT if mine else UIKit.C_PANEL2, 22, 18)
	panel.custom_minimum_size = Vector2(w, 0)
	var l := UIKit.label(text, 28, UIKit.C_BG if mine else UIKit.C_TEXT)
	panel.add_child(l)
	if mine:
		h.add_child(UIKit.spacer(0, true))
		h.add_child(panel)
	else:
		h.add_child(UIKit.image_box(Data.texture(Data.portrait_key(cid, "smile")), Vector2(64, 64), 32))
		h.add_child(panel)
		h.add_child(UIKit.spacer(0, true))
	list.add_child(h)
	UIKit.fade_in(h, 0.2)
	_scroll_down()


func _scroll_down() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


func _play() -> void:
	if playing:
		return
	playing = true
	for c in bottom.get_children():
		c.queue_free()
	var st := Game.chat_state(cid)
	while int(st.index) < steps.size() and steps[int(st.index)].has("him"):
		var typing := UIKit.label("%s 正在输入…" % Data.char_name(cid), 22, UIKit.C_MUTED)
		bottom.add_child(typing)
		await get_tree().create_timer(0.8).timeout
		if not is_instance_valid(self):
			return
		typing.queue_free()
		var text := str(steps[int(st.index)].him)
		st.log.append({"from": "him", "text": text})
		st.index = int(st.index) + 1
		Game.save()
		_bubble("him", text)
	playing = false
	if int(st.index) >= steps.size():
		bottom.add_child(UIKit.label("今天的对话到这里啦，明天他还会来找你。", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		var reset := UIKit.button("重看这段对话", "ghost", 24, 64)
		reset.pressed.connect(func() -> void:
			Game.s.chat[cid] = {"index": 0, "log": []}
			Game.save()
			rebuild())
		bottom.add_child(reset)
		return
	var step: Dictionary = steps[int(st.index)]
	bottom.add_child(UIKit.label("选择回复：", 22, UIKit.C_MUTED))
	for opt in step.get("choices", []):
		var b := UIKit.button(str(opt.get("text", "")), "dark", 28, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: _choose(opt))
		bottom.add_child(b)


func _choose(opt: Dictionary) -> void:
	var st := Game.chat_state(cid)
	var text := str(opt.get("text", ""))
	st.log.append({"from": "me", "text": text})
	_bubble("me", text)
	var reply := str(opt.get("reply", ""))
	if reply != "":
		st.log.append({"from": "him", "text": reply})
	st.index = int(st.index) + 1
	var aff := int(opt.get("aff", 0))
	if aff > 0:
		Game.add_affection(cid, aff)
		Router.toast("♥ %s 好感 +%d" % [Data.char_name(cid), aff])
	Game.task_progress("chat")
	Game.save()
	for c in bottom.get_children():
		c.queue_free()
	if reply != "":
		await get_tree().create_timer(0.7).timeout
		if not is_instance_valid(self):
			return
		_bubble("him", reply)
	_play()
