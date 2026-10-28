extends Node
## 手指拖动滚动：挂在 ScrollContainer 下面。
## Godot 自带的拖动滚动只在“检测到触摸屏”时启用，而且手指按在按钮、卡片上时事件会被子控件吃掉，
## 真机上表现为列表滑不动。这里在 _input 里自己处理：按下记录位置，移动超过阈值就开始滚动，
## 松手后带一点惯性；一旦判定为拖动，松手时不会再触发手指下面的按钮。

const THRESHOLD := 14.0  # 视口像素，超过才算拖动，避免轻点被误判
const FRICTION := 5.0

var sc: ScrollContainer
var pressing := false
var dragging := false
var start := Vector2.ZERO
var last_y := 0.0
var velocity := 0.0
var _last_time := 0


func _ready() -> void:
	sc = get_parent() as ScrollContainer
	set_process(false)


func _input(event: InputEvent) -> void:
	if sc == null or not sc.is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _owns_point(event.position):
				pressing = true
				dragging = false
				start = event.position
				last_y = event.position.y
				velocity = 0.0
				_last_time = Time.get_ticks_msec()
				set_process(false)
		elif pressing:
			pressing = false
			if dragging:
				dragging = false
				# 吃掉这次松手；先把“手指”移到屏幕外再松开，按钮会恢复原状但不触发点击
				get_viewport().set_input_as_handled()
				var away := InputEventMouseMotion.new()
				away.button_mask = MOUSE_BUTTON_MASK_LEFT
				away.position = Vector2(-10000, -10000)
				away.global_position = away.position
				get_viewport().push_input(away, true)
				var fake := InputEventMouseButton.new()
				fake.button_index = MOUSE_BUTTON_LEFT
				fake.pressed = false
				fake.position = Vector2(-10000, -10000)
				fake.global_position = fake.position
				get_viewport().push_input(fake, true)
				set_process(absf(velocity) > 30.0)
	elif event is InputEventMouseMotion and pressing:
		var dy: float = event.position.y - last_y
		if not dragging and absf(event.position.y - start.y) > THRESHOLD:
			dragging = true
			dy = event.position.y - start.y
		if dragging:
			sc.scroll_vertical -= int(round(dy))
			var now := Time.get_ticks_msec()
			var dt := maxf(float(now - _last_time) / 1000.0, 0.001)
			velocity = lerpf(velocity, -dy / dt, 0.5)
			_last_time = now
			get_viewport().set_input_as_handled()
		last_y = event.position.y


func _process(delta: float) -> void:
	sc.scroll_vertical += int(round(velocity * delta))
	velocity = lerpf(velocity, 0.0, clampf(FRICTION * delta, 0.0, 1.0))
	if absf(velocity) < 20.0:
		set_process(false)


## 按下的位置在这个列表里，而且没有被弹窗之类的东西挡住。
func _owns_point(p: Vector2) -> bool:
	if not sc.get_global_rect().has_point(p):
		return false
	var vbar := sc.get_v_scroll_bar()
	if vbar == null or vbar.max_value <= sc.size.y + 1:
		return false  # 内容不够长，不需要滚
	# 弹窗 / 新手引导盖在上面时不滚（除非列表本身就在弹窗里）
	var ov: CanvasLayer = Router.overlay
	if ov != null and not ov.is_ancestor_of(sc):
		for c in ov.get_children():
			if c is Control and c.visible and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				return false
	return true
