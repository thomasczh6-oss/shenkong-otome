extends Node
## 统一的视觉风格与控件工厂。所有界面都用代码搭建，样式只在这里定义，方便整体换肤。
## 配色：深海夜色底 + 极光青 + 玫瑰粉 + 星光金。

const C_BG := Color("0b1026")
const C_BG2 := Color("111838")
const C_PANEL := Color("1a2250")
const C_PANEL2 := Color("242d66")
const C_LINE := Color("34407f")
const C_ACCENT := Color("4fd1c5")
const C_ROSE := Color("f2a7b5")
const C_GOLD := Color("f4d58d")
const C_TEXT := Color("f5f6fa")
const C_MUTED := Color("9aa3c7")
const C_DANGER := Color("ff6b81")
const C_OK := Color("7ee8a2")

const RARITY := {3: Color("7fa6ff"), 4: Color("c58bff"), 5: Color("f4d58d")}
const ELEMENT_COLORS := {"潮": Color("4fa3ff"), "星": Color("c9b6ff"), "焰": Color("ff8c66")}

var font: Font = null


func _ready() -> void:
	var fpath := "res://assets/fonts/cjk.ttf"
	if ResourceLoader.exists(fpath):
		font = load(fpath)
	elif FileAccess.file_exists(fpath):
		var ff := FontFile.new()
		if ff.load_dynamic_font(fpath) == OK:
			font = ff
	var theme := Theme.new()
	if font != null:
		theme.default_font = font
	theme.default_font_size = 34
	get_tree().root.theme = theme


func rarity_color(rarity: int) -> Color:
	return RARITY.get(rarity, C_MUTED)


func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, C_ACCENT)


func stars(rarity: int) -> String:
	var out := ""
	for i in rarity:
		out += "★"
	return out


# ---------------- 样式 ----------------

func sb(bg: Color, radius := 24, border: Color = Color.TRANSPARENT, border_w := 0, margin := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border_w > 0:
		s.set_border_width_all(border_w)
		s.border_color = border
	if margin > 0:
		s.set_content_margin_all(margin)
	return s


# ---------------- 基础控件 ----------------

func label(text: String, size := 34, color := C_TEXT, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func button(text: String, kind := "primary", size := 36, min_h := 96) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.add_theme_font_size_override("font_size", size)
	var bg := C_PANEL2
	var fg := C_TEXT
	var border := Color.TRANSPARENT
	var bw := 0
	match kind:
		"primary":
			bg = C_ACCENT
			fg = C_BG
		"gold":
			bg = C_GOLD
			fg = C_BG
		"rose":
			bg = C_ROSE
			fg = C_BG
		"ghost":
			bg = Color(1, 1, 1, 0.06)
			border = C_LINE
			bw = 2
		"danger":
			bg = C_DANGER
		"dark":
			bg = Color(0.03, 0.04, 0.1, 0.7)
			border = Color(1, 1, 1, 0.12)
			bw = 2
	b.add_theme_stylebox_override("normal", sb(bg, 28, border, bw))
	b.add_theme_stylebox_override("hover", sb(bg.lightened(0.08), 28, border, bw))
	b.add_theme_stylebox_override("pressed", sb(bg.darkened(0.18), 28, border, bw))
	b.add_theme_stylebox_override("disabled", sb(Color(0.3, 0.32, 0.45, 0.45), 28))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	return b


func panel(bg := C_PANEL, radius := 28, pad := 24, border: Color = Color.TRANSPARENT, border_w := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, radius, border, border_w, pad))
	return p


func vbox(sep := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


func hbox(sep := 16) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func margin(left := 40, top := 40, right := 40, bottom := 40) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	return m


func spacer(min_size := 0.0, expand := true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(min_size, min_size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


## 顶部栏：返回按钮 + 标题 + 可选右侧控件。
func header(title_text: String, on_back: Callable = Callable(), right: Control = null) -> Control:
	var h := hbox(16)
	h.custom_minimum_size = Vector2(0, 100)
	if on_back.is_valid():
		var b := button("← 返回", "dark", 30, 76)
		b.custom_minimum_size = Vector2(170, 76)
		b.pressed.connect(on_back)
		h.add_child(b)
	var t := label(title_text, 44, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(t)
	if right != null:
		h.add_child(right)
	return h


## 全屏页面骨架：背景渐变 + 带安全边距的纵向容器。返回 [root, vbox]。
func page(title_text := "", on_back: Callable = Callable(), right: Control = null) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gradient_rect(C_BG, C_BG2))
	var m := margin(36, 70, 36, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := vbox(20)
	if title_text != "":
		v.add_child(header(title_text, on_back, right))
	m.add_child(v)
	root.add_child(m)
	return [root, v]


func gradient_rect(c1: Color, c2: Color, vertical := true) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 32
	gt.height = 32
	if vertical:
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func image(tex: Texture2D, cover := true) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## 带圆角裁切的图片块（用 clip_contents 裁切）。
func image_box(tex: Texture2D, size: Vector2, radius := 24, border: Color = Color.TRANSPARENT, border_w := 0) -> PanelContainer:
	var p := panel(Color(1, 1, 1, 0.04), radius, 0, border, border_w)
	p.custom_minimum_size = size
	p.clip_contents = true
	var img := image(tex, true)
	img.custom_minimum_size = size
	p.add_child(img)
	return p


func progress(value: float, max_value: float, color := C_ACCENT, h := 22) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = maxf(max_value, 1.0)
	p.value = value
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	p.add_theme_stylebox_override("background", sb(Color(1, 1, 1, 0.08), int(h / 2.0)))
	p.add_theme_stylebox_override("fill", sb(color, int(h / 2.0)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func pill(text: String, color := C_ACCENT, size := 26) -> PanelContainer:
	var p := panel(Color(color, 0.16), 999, 10, color, 2)
	var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER, false)
	p.add_child(l)
	return p


## 货币胶囊：图标 + 数值。
func currency(icon_text: String, value: int, color := C_GOLD) -> PanelContainer:
	var p := panel(Color(0.03, 0.04, 0.1, 0.7), 999, 8, Color(1, 1, 1, 0.1), 2)
	var h := hbox(8)
	h.add_child(label(icon_text, 28, color, HORIZONTAL_ALIGNMENT_CENTER, false))
	var v := label(str(value), 28, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	v.name = "Value"
	h.add_child(v)
	p.add_child(h)
	return p


func line_edit(placeholder := "", text := "") -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = text
	e.custom_minimum_size = Vector2(0, 96)
	e.add_theme_font_size_override("font_size", 34)
	e.add_theme_stylebox_override("normal", sb(Color(1, 1, 1, 0.06), 20, C_LINE, 2, 20))
	e.add_theme_stylebox_override("focus", sb(Color(1, 1, 1, 0.08), 20, C_ACCENT, 2, 20))
	e.add_theme_color_override("font_color", C_TEXT)
	e.add_theme_color_override("font_placeholder_color", C_MUTED)
	return e


func divider() -> Control:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.08)
	c.custom_minimum_size = Vector2(0, 2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## 弹出动画（缩放回弹）。
func pop(node: Control, from := 0.7, duration := 0.35) -> void:
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2(from, from)
	var tw := node.create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, duration)


func fade_in(node: CanvasItem, duration := 0.3) -> void:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, duration)


func reward_text(reward: Dictionary) -> String:
	var names := {
		"diamonds": "钻石", "gold": "金币", "stardust": "星屑",
		"tickets_standard": "回响许愿券", "tickets_limited": "潮汐许愿券", "xp": "通行证经验",
	}
	var parts: Array = []
	for k in reward.keys():
		parts.append("%s×%d" % [names.get(k, k), int(reward[k])])
	return "、".join(parts)
