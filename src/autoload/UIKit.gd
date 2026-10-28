extends Node
## 统一的视觉风格与控件工厂。所有界面都用代码搭建，样式只在这里定义，方便整体换肤。
## 配色（v0.3 面向女性玩家重做）：暮紫夜色底 + 樱粉主色 + 香槟金点缀 + 月白文字。
## 字体：霞鹜文楷（主字体，OFL）+ 文泉驿正黑（缺字回退）。

const C_BG := Color("130e2a")
const C_BG2 := Color("2a1a45")
const C_PANEL := Color(0.19, 0.13, 0.33, 0.92)
const C_PANEL2 := Color("3a2a63")
const C_LINE := Color(1.0, 0.78, 0.9, 0.22)
const C_ACCENT := Color("ff9ec7")
const C_ROSE := Color("ff7eaa")
const C_GOLD := Color("f6d79a")
const C_TEXT := Color("fff7fb")
const C_MUTED := Color("c3b5dc")
const C_DANGER := Color("ff6b8a")
const C_OK := Color("9fe8c4")
const C_INK := Color("3a1636")  # 浅色按钮上的文字

const RARITY := {3: Color("7fa6ff"), 4: Color("c58bff"), 5: Color("f4d58d")}
const ELEMENT_COLORS := {"潮": Color("4fa3ff"), "星": Color("c9b6ff"), "焰": Color("ff8c66")}

var font: Font = null


func _ready() -> void:
	var main := _load_font("res://assets/fonts/wenkai.ttf")
	var fallback := _load_font("res://assets/fonts/cjk.ttf")
	if main != null:
		if fallback != null:
			main.fallbacks = [fallback]
		font = main
	else:
		font = fallback
	var theme := Theme.new()
	if font != null:
		theme.default_font = font
	theme.default_font_size = 34
	get_tree().root.theme = theme
	# CanvasLayer 下的控件（弹窗、提示、新手引导）拿不到 root 的主题，
	# 会回退到引擎默认字体；默认字体没有中文，真机上就成了方块。这里把全局兜底字体也换掉。
	if font != null:
		ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 34


func _load_font(path: String) -> Font:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(path) == OK:
			return ff
	return null


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
	var glow := Color.TRANSPARENT
	match kind:
		"primary":
			bg = C_ACCENT
			fg = C_INK
			border = Color(1, 0.92, 0.96, 0.9)
			bw = 2
			glow = Color(C_ACCENT, 0.45)
		"gold":
			bg = C_GOLD
			fg = C_INK
			border = Color(1, 0.97, 0.88, 0.9)
			bw = 2
			glow = Color(C_GOLD, 0.4)
		"rose":
			bg = C_ROSE
			fg = Color.WHITE
			border = Color(1, 0.85, 0.92, 0.8)
			bw = 2
			glow = Color(C_ROSE, 0.45)
		"ghost":
			bg = Color(1, 0.9, 0.97, 0.07)
			border = C_LINE
			bw = 2
		"danger":
			bg = C_DANGER
			border = Color(1, 0.85, 0.9, 0.6)
			bw = 2
		"dark":
			bg = Color(0.1, 0.06, 0.18, 0.62)
			border = Color(1, 0.85, 0.95, 0.18)
			bw = 2
	var r := mini(36, int(min_h / 2))
	b.add_theme_stylebox_override("normal", _glow_sb(sb(bg, r, border, bw), glow))
	b.add_theme_stylebox_override("hover", _glow_sb(sb(bg.lightened(0.08), r, border, bw), glow))
	b.add_theme_stylebox_override("pressed", sb(bg.darkened(0.15), r, border, bw))
	b.add_theme_stylebox_override("disabled", sb(Color(0.35, 0.3, 0.45, 0.4), r, Color(1, 1, 1, 0.08), 2))
	b.pivot_offset = Vector2(0, 0)
	b.button_down.connect(func() -> void:
		b.pivot_offset = b.size / 2.0
		b.create_tween().tween_property(b, "scale", Vector2(0.96, 0.96), 0.06))
	b.button_up.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	return b


func _glow_sb(s: StyleBoxFlat, glow: Color) -> StyleBoxFlat:
	if glow.a > 0.0:
		s.shadow_color = glow
		s.shadow_size = 14
	return s


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


## 刘海 / 挖孔 / 底部手势条占掉的高度（视口像素）：x = 顶部，y = 底部。电脑上为 0。
func safe_insets() -> Vector2:
	# 调试：--safe=顶部,底部（视口像素），在电脑上模拟刘海屏
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--safe="):
			var p := a.trim_prefix("--safe=").split(",")
			return Vector2(float(p[0]), float(p[1]) if p.size() > 1 else 0.0)
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.y <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var vp := get_tree().root.get_visible_rect().size
	var k := vp.y / float(screen.y)
	return Vector2(maxf(0.0, safe.position.y) * k, maxf(0.0, float(screen.y - safe.end.y)) * k)


## 和 margin() 一样，但上下额外让出安全区。
func safe_margin(left := 40, top := 40, right := 40, bottom := 40) -> MarginContainer:
	var ins := safe_insets()
	return margin(left, top + int(ins.x), right, bottom + int(ins.y))


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
	var drag := preload("res://src/ui/DragScroll.gd").new()
	drag.name = "DragScroll"
	s.add_child(drag)
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
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 2)
	var t := label("❀ " + title_text, 46, C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false)
	tv.add_child(t)
	var line := gradient_rect(Color(C_GOLD, 0.9), Color(C_GOLD, 0.0), false)
	line.custom_minimum_size = Vector2(260, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tv.add_child(line)
	h.add_child(tv)
	if right != null:
		h.add_child(right)
	return h


## 全屏页面骨架：背景渐变 + 带安全边距的纵向容器。返回 [root, vbox]。
func page(title_text := "", on_back: Callable = Callable(), right: Control = null) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dreamy_bg())
	var m := safe_margin(36, 70, 36, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := vbox(20)
	if title_text != "":
		v.add_child(header(title_text, on_back, right))
	m.add_child(v)
	root.add_child(m)
	return [root, v]


## 页面背景：暮紫渐变 + 两团柔光 + 缓慢闪烁的星点。
func dreamy_bg() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gradient_rect(C_BG, C_BG2))
	for spec in [[Vector2(0.85, 0.08), Color(1.0, 0.55, 0.78, 0.22), 900.0], [Vector2(0.1, 0.75), Color(0.6, 0.55, 1.0, 0.16), 1000.0]]:
		var g := Gradient.new()
		g.set_color(0, spec[1])
		g.set_color(1, Color(spec[1], 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		var tr := TextureRect.new()
		tr.texture = gt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d: float = spec[2]
		tr.size = Vector2(d, d)
		tr.position = Vector2(1080.0 * spec[0].x, 1920.0 * spec[0].y) - Vector2(d, d) / 2.0
		root.add_child(tr)
	root.add_child(sparkles(Rect2(0, 0, 1080, 1920), 40))
	return root


## 闪烁星点粒子，铺在 area 内。
func sparkles(area: Rect2, amount := 30, color := Color(1, 0.92, 0.97)) -> CPUParticles2D:
	var pt := CPUParticles2D.new()
	pt.position = area.get_center()
	pt.amount = amount
	pt.lifetime = 4.0
	pt.preprocess = 4.0
	pt.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pt.emission_rect_extents = area.size / 2.0
	pt.gravity = Vector2(0, -6)
	pt.initial_velocity_min = 0.0
	pt.initial_velocity_max = 8.0
	pt.scale_amount_min = 2.0
	pt.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.add_point(0.5, Color(color, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
	pt.color_ramp = ramp
	return pt


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


## 循环播放的视频块：按 3:4 等比铺满（裁掉多余部分），圆角裁切。
func video_box(stream: VideoStream, size: Vector2, radius := 24, border: Color = Color.TRANSPARENT, border_w := 0, ratio := 0.75) -> PanelContainer:
	var p := panel(Color(0, 0, 0, 1), radius, 0, border, border_w)
	p.custom_minimum_size = size
	p.clip_contents = true
	var arc := AspectRatioContainer.new()
	arc.ratio = ratio
	arc.stretch_mode = AspectRatioContainer.STRETCH_COVER
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := VideoStreamPlayer.new()
	vp.stream = stream
	vp.expand = true
	vp.loop = true
	vp.autoplay = true
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.add_child(vp)
	p.add_child(arc)
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


## 立绘材质：底部/两侧淡出 + 场景色调 + 轮廓光，让人物和背景像在同一个画面里。
func portrait_material(tint := Color(0.96, 0.94, 1.0), rim_color := Color(1.0, 0.78, 0.9), rim := 0.8, fade_start := 0.78) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/fx/portrait.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("rim_color", rim_color)
	mat.set_shader_parameter("rim", rim)
	mat.set_shader_parameter("fade_start", fade_start)
	return mat


## 人物身后的一团柔光（角色色），中心在 center，直径 d。
func glow_blob(center: Vector2, d: float, color: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = Vector2(d, d)
	tr.position = center - Vector2(d, d) / 2.0
	return tr


## 让一整块控件（卡片、列表行）可以点：整块接收点击，里面的子控件都不拦截；
## 松手时才触发，按下后手指移动超过阈值（被当成滚动）就不算点击。
func on_tap(ctrl: Control, callback: Callable) -> void:
	ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	for n in ctrl.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := {"down": false, "pos": Vector2.ZERO}
	ctrl.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				st.down = true
				st.pos = ev.global_position
			elif st.down:
				st.down = false
				if ev.global_position.distance_to(st.pos) <= 40.0 and ctrl.get_global_rect().has_point(ev.global_position):
					callback.call()
		elif ev is InputEventMouseMotion and st.down and ev.global_position.distance_to(st.pos) > 40.0:
			st.down = false)
