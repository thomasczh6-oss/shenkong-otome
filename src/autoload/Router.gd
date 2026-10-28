extends Node
## 界面导航：所有界面都是用代码搭建的 Control，这里负责压栈 / 返回 / 浮层（Toast、确认框）。

const SCREENS := {
	"Title": "res://src/screens/Title.gd",
	"Home": "res://src/screens/Home.gd",
	"Chapters": "res://src/screens/Chapters.gd",
	"Story": "res://src/screens/Story.gd",
	"Battle": "res://src/screens/Battle.gd",
	"Gacha": "res://src/screens/Gacha.gd",
	"Cards": "res://src/screens/Cards.gd",
	"CardDetail": "res://src/screens/CardDetail.gd",
	"Daily": "res://src/screens/Daily.gd",
	"Chat": "res://src/screens/Chat.gd",
	"Call": "res://src/screens/Call.gd",
	"Shop": "res://src/screens/Shop.gd",
	"Profile": "res://src/screens/Profile.gd",
	"Gallery": "res://src/screens/Gallery.gd",
	"Dates": "res://src/screens/Dates.gd",
	"Challenge": "res://src/screens/Challenge.gd",
	"Bestiary": "res://src/screens/Bestiary.gd",
}

var host: Control
var overlay: CanvasLayer
var stack: Array = []


func setup(screen_host: Control, overlay_layer: CanvasLayer) -> void:
	host = screen_host
	overlay = overlay_layer


## 清空栈并打开界面（用于 标题 → 主页 这类切换），同时关掉所有浮层。
func go(screen: String, params: Dictionary = {}) -> void:
	for entry in stack:
		entry.node.queue_free()
	stack.clear()
	clear_overlay()
	_open(screen, params)


func clear_overlay() -> void:
	if overlay == null:
		return
	for c in overlay.get_children():
		c.queue_free()


## 在当前界面之上打开新界面，当前界面隐藏并暂停。
func push(screen: String, params: Dictionary = {}) -> void:
	if stack.size() > 0:
		var top: Dictionary = stack.back()
		top.node.visible = false
		top.node.process_mode = Node.PROCESS_MODE_DISABLED
	_open(screen, params)


## 关闭当前界面，回到上一个；result 会交给上一个界面的 on_resume()。
func back(result: Variant = null) -> void:
	if stack.size() <= 1:
		go("Home")
		return
	var top: Dictionary = stack.pop_back()
	top.node.queue_free()
	var prev: Dictionary = stack.back()
	prev.node.visible = true
	prev.node.process_mode = Node.PROCESS_MODE_INHERIT
	if prev.node.has_method("on_resume"):
		prev.node.on_resume(result)


func current_name() -> String:
	return str(stack.back().name) if stack.size() > 0 else ""


func _open(screen: String, params: Dictionary) -> void:
	assert(SCREENS.has(screen), "未知界面: " + screen)
	var script: GDScript = load(SCREENS[screen])
	var node: Control = script.new()
	node.params = params
	host.add_child(node)
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 转场：淡入 + 轻微上浮
	node.modulate.a = 0.0
	node.position.y = 24.0
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 1.0, 0.22)
	tw.tween_property(node, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	stack.append({"name": screen, "params": params, "node": node})


# ---------------- 浮层 ----------------

func toast(text: String, duration := 1.8) -> void:
	if overlay == null:
		return
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 220)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)
	var panel := UIKit.panel(Color(0.08, 0.1, 0.22, 0.94), 24, 22, UIKit.C_LINE, 2)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(UIKit.label(text, 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false))
	root.add_child(panel)
	overlay.add_child(root)
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tw.tween_interval(duration)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(root.queue_free)


## 通用模态：返回遮罩节点，调用方自行 queue_free() 关闭。
func modal(content: Control, dismiss_on_tap := true) -> Control:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)
	dim.add_child(center)
	if dismiss_on_tap:
		dim.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				dim.queue_free())
	overlay.add_child(dim)
	content.modulate.a = 0.0
	var tw := content.create_tween()
	tw.tween_property(content, "modulate:a", 1.0, 0.18)
	return dim


func confirm(title: String, body: String, on_ok: Callable, ok_text := "确定", cancel_text := "取消") -> void:
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 36, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(860, 0)
	var v := UIKit.vbox(22)
	v.add_child(UIKit.label(title, 42, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if body != "":
		v.add_child(UIKit.label(body, 30, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.hbox(20)
	var dim: Control = null
	var cancel := UIKit.button(cancel_text, "ghost", 32, 88)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ok := UIKit.button(ok_text, "primary", 32, 88)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(cancel)
	row.add_child(ok)
	v.add_child(row)
	panel.add_child(v)
	dim = modal(panel, false)
	cancel.pressed.connect(func() -> void: dim.queue_free())
	ok.pressed.connect(func() -> void:
		dim.queue_free()
		if on_ok.is_valid():
			on_ok.call())


## 新手引导：依次高亮目标控件并显示说明，点击任意处下一步，结束后调用 on_done。
## steps: [{target: Control 或 null, text: String, who: 角色 id（可选，显示头像）}]
func coach(steps: Array, on_done: Callable = Callable(), i := 0) -> void:
	if overlay == null:
		return
	if i >= steps.size():
		if on_done.is_valid():
			on_done.call()
		return
	var step: Dictionary = steps[i]
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(root)
	var vp := root.get_viewport_rect().size
	# 目标控件可能已经被释放（比如界面切走了），先判有效再转成 Control
	var raw_target: Variant = step.get("target")
	var target: Control = raw_target as Control if is_instance_valid(raw_target) else null
	var hole := Rect2()
	if target != null and target.is_visible_in_tree():
		hole = target.get_global_rect().grow(12)
	var dim_c := Color(0, 0, 0, 0.66)
	if hole.size == Vector2.ZERO:
		var full := ColorRect.new()
		full.color = dim_c
		full.set_anchors_preset(Control.PRESET_FULL_RECT)
		full.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(full)
	else:
		# 四块遮罩围出一个“洞”，再加一圈发光描边
		for r in [Rect2(0, 0, vp.x, hole.position.y), Rect2(0, hole.end.y, vp.x, vp.y - hole.end.y),
				Rect2(0, hole.position.y, hole.position.x, hole.size.y), Rect2(hole.end.x, hole.position.y, vp.x - hole.end.x, hole.size.y)]:
			var cr := ColorRect.new()
			cr.color = dim_c
			cr.position = r.position
			cr.size = r.size
			cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(cr)
		var ring := Panel.new()
		ring.position = hole.position
		ring.size = hole.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", UIKit.sb(Color(0, 0, 0, 0), 20, UIKit.C_GOLD, 5))
		root.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "modulate:a", 0.35, 0.6)
		tw.tween_property(ring, "modulate:a", 1.0, 0.6)

	var bubble := UIKit.panel(Color(0.07, 0.08, 0.2, 0.97), 28, 26, UIKit.C_GOLD, 2)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var who := str(step.get("who", ""))
	if who != "":
		var face := UIKit.image_box(Data.texture(Data.portrait_key(who, "smile")), Vector2(120, 120), 60)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(face)
	var v := UIKit.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if who != "":
		v.add_child(UIKit.label(Data.char_name(who), 28, Color(str(Data.character(who).get("color", "#ffffff"))), HORIZONTAL_ALIGNMENT_LEFT, false))
	v.add_child(UIKit.label(str(step.get("text", "")).replace("{name}", Game.player_name()), 30, UIKit.C_TEXT))
	v.add_child(UIKit.label("点击继续  %d / %d" % [i + 1, steps.size()], 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false))
	h.add_child(v)
	bubble.add_child(h)
	bubble.position = Vector2(50, 0)
	bubble.size = Vector2(vp.x - 100, 0)
	root.add_child(bubble)
	# 目标在下半屏时气泡放上面，反之放下面
	await root.get_tree().process_frame
	var bh := bubble.size.y
	if hole.size == Vector2.ZERO:
		bubble.position.y = (vp.y - bh) / 2.0
	elif hole.get_center().y > vp.y / 2.0:
		bubble.position.y = maxf(40.0, hole.position.y - bh - 40.0)
	else:
		bubble.position.y = minf(vp.y - bh - 40.0, hole.end.y + 40.0)
	UIKit.fade_in(bubble, 0.2)
	root.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			root.queue_free()
			coach(steps, on_done, i + 1))


func alert(title: String, body := "", ok_text := "知道了") -> void:
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 36, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(860, 0)
	var v := UIKit.vbox(22)
	v.add_child(UIKit.label(title, 42, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	if body != "":
		v.add_child(UIKit.label(body, 30, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button(ok_text, "primary", 32, 88)
	v.add_child(ok)
	panel.add_child(v)
	var dim := modal(panel, true)
	ok.pressed.connect(func() -> void: dim.queue_free())
