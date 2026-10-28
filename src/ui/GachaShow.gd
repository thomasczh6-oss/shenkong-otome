extends Control
## 许愿演出：许愿聚能 → 流星（颜色暗示本次最高稀有度）→ 逐张翻卡 → 交给结果页。
## 3★ 轻快带过，4★ 紫光，5★ 白闪 + 金色光芒 + 慢放登场 + 角色配音。
## 右上角随时可以「跳过」直接看结果。
##
## 用法：var show := GachaShow.new(); show.setup(results, func(): 显示结果页); Router.overlay.add_child(show)

signal finished

const C_RARITY := {3: Color("8fd3ff"), 4: Color("c7a6ff"), 5: Color("ffd98a")}

var results: Array = []
var on_done: Callable
var auto_advance := false  # 测试 / 截图用：不等点击
var speed := 1.0  # 测试用：>1 加速
var skipped := false
var _tapped := false
var _done := false
var _running := false
var _vp := Vector2(1080, 1920)

var bg_layer: Control
var fx_layer: Control
var card_layer: Control
var hint: Label
var skip_btn: Button
var counter: Label


## 光芒：从中心发出的一圈三角形，转起来像神光。
class Rays extends Control:
	var color := Color(1, 0.9, 0.6, 0.35)
	var count := 18
	var radius := 1400.0

	func _draw() -> void:
		var c := size / 2.0
		for i in count:
			var a := TAU * i / count
			var w := TAU / count * 0.16
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * radius, c + Vector2.from_angle(a + w) * radius])
			var cols := PackedColorArray([color, Color(color, 0.0), Color(color, 0.0)])
			draw_polygon(pts, cols)


## 冲击波光环。
class Ring extends Control:
	var color := Color(1, 1, 1, 0.8)
	var r := 10.0
	var width := 6.0

	func _draw() -> void:
		draw_arc(size / 2.0, r, 0, TAU, 96, color, width, true)


func setup(res: Array, done: Callable) -> void:
	results = res
	on_done = done


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = get_viewport_rect().size
	position = Vector2.ZERO
	size = _vp
	bg_layer = _layer()
	fx_layer = _layer()
	card_layer = _layer()
	_build_bg()
	hint = UIKit.label("", 38, Color(1, 0.96, 0.99, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	hint.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.3, 0.8))
	hint.add_theme_constant_override("outline_size", 8)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -260 - UIKit.safe_insets().y
	hint.offset_bottom = -200 - UIKit.safe_insets().y
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	counter = UIKit.label("", 26, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, false)
	counter.position = Vector2(48, 70 + UIKit.safe_insets().x)
	counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(counter)
	skip_btn = UIKit.button("跳过", "ghost", 26, 68)
	skip_btn.custom_minimum_size = Vector2(150, 68)
	skip_btn.position = Vector2(_vp.x - 190, 56 + UIKit.safe_insets().x)
	skip_btn.pressed.connect(skip)
	add_child(skip_btn)
	gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
			_tapped = true)
	_run()


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _build_bg() -> void:
	var base := ColorRect.new()
	base.color = Color("0d0820")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(base)
	var tex := Data.texture("ui/wish_bg")
	if tex != null:
		var img := UIKit.image(tex)
		img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		img.modulate = Color(1, 1, 1, 0.85)
		bg_layer.add_child(img)
	bg_layer.add_child(UIKit.sparkles(Rect2(Vector2.ZERO, _vp), 60))


func best_rarity() -> int:
	var b := 3
	for r in results:
		b = maxi(b, int(r.rarity))
	return b


func skip() -> void:
	if skipped:
		return
	skipped = true
	Audio.stop_voice()
	_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Audio.play_sfx("result_open", 0.8)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		finished.emit()
		if on_done.is_valid():
			on_done.call()
		# 演出协程还在等帧时不能直接释放，等它自己退出再释放
		if _running:
			visible = false
			mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			queue_free())


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec / speed and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


func _wait_tap(max_sec := 0.0) -> void:
	_tapped = false
	var t := 0.0
	while not _tapped and not skipped:
		if auto_advance and t > 0.6 / speed:
			return
		if max_sec > 0.0 and t > max_sec:
			return
		await get_tree().process_frame
		t += get_process_delta_time()


func _run() -> void:
	_running = true
	await _sequence()
	_running = false
	if _done:
		if not visible:
			queue_free()
	else:
		_finish()


func _sequence() -> void:
	await _wish()
	if skipped:
		return
	await _meteor()
	for i in results.size():
		if skipped:
			return
		counter.text = "%d / %d" % [i + 1, results.size()] if results.size() > 1 else ""
		await _reveal(results[i], i == results.size() - 1)


# ---------- 1. 许愿聚能 ----------
func _wish() -> void:
	var c := _vp / 2.0 + Vector2(0, -80)
	var orb := UIKit.glow_blob(c, 460, Color(1, 0.86, 0.95, 1.0))
	fx_layer.add_child(orb)
	var core := UIKit.glow_blob(c, 170, Color(1, 1, 1, 1))
	fx_layer.add_child(core)
	var breathe := orb.create_tween().set_loops()
	breathe.tween_property(orb, "modulate:a", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(orb, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	hint.text = "轻触星光，许下心愿"
	await _wait_tap()
	breathe.kill()
	if skipped:
		return
	hint.text = ""
	Audio.play_sfx("wish_charge")
	# 四周的光点向中心汇聚
	var pt := CPUParticles2D.new()
	pt.position = c
	pt.amount = 90
	pt.lifetime = 1.1
	pt.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	pt.emission_sphere_radius = 520
	pt.radial_accel_min = -900
	pt.radial_accel_max = -700
	pt.gravity = Vector2.ZERO
	pt.scale_amount_min = 4
	pt.scale_amount_max = 9
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.9, 0.97, 0.0))
	ramp.add_point(0.3, Color(1, 0.9, 0.97, 1.0))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0.0))
	pt.color_ramp = ramp
	fx_layer.add_child(pt)
	var hue: Color = C_RARITY[best_rarity()]
	var tw := create_tween().set_parallel()
	tw.tween_method(func(v: float) -> void: _resize_blob(orb, c, v), 460.0, 980.0, 1.9 / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(orb, "modulate", Color(hue, 1.0), 1.9 / speed)
	tw.tween_method(func(v: float) -> void: _resize_blob(core, c, v), 170.0, 420.0, 1.9 / speed).set_ease(Tween.EASE_IN)
	for k in 3:
		_ring(c, Color(hue, 0.9), 0.5 + k * 0.5)
	await _wait(1.9)
	pt.emitting = false
	_flash(Color(1, 1, 1, 1), 0.35)
	orb.queue_free()
	core.queue_free()


func _resize_blob(b: Control, c: Vector2, d: float) -> void:
	b.size = Vector2(d, d)
	b.position = c - b.size / 2.0


func _ring(c: Vector2, col: Color, delay: float) -> void:
	var ring := Ring.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.color = col
	ring.position = c - _vp / 2.0
	fx_layer.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_interval(delay / speed)
	tw.set_parallel()
	tw.tween_method(func(v: float) -> void:
		ring.r = v
		ring.queue_redraw(), 30.0, 620.0, 0.9 / speed).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "modulate:a", 0.0, 0.9 / speed)
	tw.chain().tween_callback(ring.queue_free)


func _flash(col: Color, dur: float) -> void:
	var f := ColorRect.new()
	f.color = col
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "modulate:a", 0.0, dur / speed)
	tw.tween_callback(f.queue_free)


# ---------- 2. 流星 ----------
func _meteor() -> void:
	var hue: Color = C_RARITY[best_rarity()]
	Audio.play_sfx("star_fall")
	var line := Line2D.new()
	line.width = 26
	var wc := Curve.new()
	wc.add_point(Vector2(0, 0))
	wc.add_point(Vector2(1, 1))
	line.width_curve = wc
	var g := Gradient.new()
	g.set_color(0, Color(hue, 0.0))
	g.set_color(1, Color(1, 1, 1, 1))
	line.gradient = g
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	fx_layer.add_child(line)
	var head := UIKit.glow_blob(Vector2.ZERO, 160, Color(hue, 1.0))
	fx_layer.add_child(head)
	var a := Vector2(_vp.x + 120, _vp.y * 0.12)
	var b := Vector2(_vp.x * 0.5, _vp.y * 0.45)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := a.lerp(b, t)
		var tail := a.lerp(b, maxf(0.0, t - 0.35))
		line.points = PackedVector2Array([tail, p])
		head.position = p - head.size / 2.0, 0.0, 1.0, 0.85 / speed).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await _wait(0.9)
	_flash(Color(hue, 0.9), 0.5)
	line.queue_free()
	head.queue_free()
	# 翻卡阶段把背景压暗一些，让卡面更突出
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.02, 0.12, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.45, 0.4 / speed)
	if best_rarity() == 5:
		# 5★：流星炸开后留一圈金光
		for k in 2:
			_ring(b, Color(hue, 1.0), k * 0.25)
	await _wait(0.4)


# ---------- 3. 翻卡 ----------
func _reveal(r: Dictionary, last: bool) -> void:
	var rarity := int(r.rarity)
	var cid := str(r.card)
	var card: Dictionary = Data.cards.get(cid, {})
	var hue: Color = C_RARITY.get(rarity, Color.WHITE)
	var quick := rarity == 3 and results.size() > 1
	var w := 640.0 if rarity < 5 else 700.0
	var sz := Vector2(w, w * 1.333)
	var centre := _vp / 2.0 + Vector2(0, -90)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = sz
	holder.position = centre - sz / 2.0
	holder.pivot_offset = sz / 2.0
	card_layer.add_child(holder)

	var glow := UIKit.glow_blob(sz / 2.0, w * (1.5 if rarity >= 4 else 1.1), Color(hue, 0.55 if rarity >= 4 else 0.3))
	holder.add_child(glow)
	var rays: Rays = null
	if rarity >= 4:
		rays = Rays.new()
		rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rays.size = Vector2(2800, 2800)
		rays.position = sz / 2.0 - rays.size / 2.0
		rays.pivot_offset = rays.size / 2.0
		rays.color = Color(hue, 0.0)
		rays.count = 14 if rarity == 4 else 22
		var add_mat := CanvasItemMaterial.new()
		add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rays.material = add_mat
		holder.add_child(rays)
		holder.move_child(rays, 0)

	var back_tex := Data.texture("ui/card_back")
	var back := UIKit.image_box(back_tex, sz, 28, Color(hue, 0.9), 4)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	var face := UIKit.image_box(Data.texture("cards/" + cid), sz, 28, UIKit.rarity_color(rarity), 6 if rarity == 5 else 3)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.visible = false
	holder.add_child(face)

	# 卡背飞入
	holder.scale = Vector2(0.6, 0.6)
	holder.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(holder, "scale", Vector2.ONE, (0.18 if quick else 0.35) / speed).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate:a", 1.0, 0.2 / speed)
	await _wait(0.2 if quick else 0.45)
	if skipped:
		return

	if rarity == 5:
		# 5★ 前奏：暗下来，卡背发抖、越来越亮
		hint.text = ""
		var shake := create_tween().set_loops(8)
		shake.tween_property(holder, "rotation", 0.03, 0.05 / speed)
		shake.tween_property(holder, "rotation", -0.03, 0.05 / speed)
		create_tween().tween_property(glow, "modulate", Color(1.6, 1.4, 1.0, 1.0), 0.8 / speed)
		await _wait(0.85)
		shake.kill()
		holder.rotation = 0.0
		_flash(Color(1, 1, 1, 1), 0.7)
		Audio.play_sfx("reveal5")
	else:
		Audio.play_sfx("card_flip", 0.8)

	# 翻面
	var flip_t := (0.12 if quick else 0.2) / speed
	var ft := create_tween()
	ft.tween_property(holder, "scale:x", 0.0, flip_t).set_ease(Tween.EASE_IN)
	ft.tween_callback(func() -> void:
		back.visible = false
		face.visible = true)
	ft.tween_property(holder, "scale:x", 1.0, flip_t).set_ease(Tween.EASE_OUT)
	await _wait(flip_t * 2.0 * speed)
	if skipped:
		return
	if rarity == 4:
		Audio.play_sfx("reveal4")
	elif rarity == 3 and not quick:
		Audio.play_sfx("reveal3")

	if rays != null:
		var rt := rays.create_tween().set_parallel()
		rt.tween_method(func(v: float) -> void:
			rays.color = Color(hue, v)
			rays.queue_redraw(), 0.0, 0.32 if rarity == 5 else 0.2, 0.5 / speed)
		var spin := rays.create_tween().set_loops()
		spin.tween_property(rays, "rotation", TAU, 24.0 if rarity == 5 else 30.0).as_relative()
	if rarity >= 4:
		var sp := UIKit.sparkles(Rect2(Vector2(-w * 0.2, -w * 0.2), sz + Vector2(w * 0.4, w * 0.4)), 40 if rarity == 5 else 24, hue.lightened(0.4))
		holder.add_child(sp)

	# 文字：星级、名字、角色
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 6)
	info.position = Vector2(0, sz.y + 26)
	info.size = Vector2(sz.x, 200)
	var stars := UIKit.label("", 46 if rarity == 5 else 38, UIKit.rarity_color(rarity), HORIZONTAL_ALIGNMENT_CENTER, false)
	info.add_child(stars)
	var name_l := UIKit.label(str(card.get("name", "")), 48 if rarity == 5 else 40, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	info.add_child(name_l)
	var who := UIKit.label("%s%s" % [Data.char_name(str(card.get("char", ""))), "  ·  NEW" if bool(r.get("new", false)) else ""], 30, UIKit.C_ACCENT if bool(r.get("new", false)) else UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
	info.add_child(who)
	for l in [stars, name_l, who]:
		l.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.22, 0.85))
		l.add_theme_constant_override("outline_size", 8)
	holder.add_child(info)
	if quick:
		stars.text = UIKit.stars(rarity)
	else:
		# 星星一颗一颗亮起
		for k in rarity:
			stars.text = UIKit.stars(k + 1)
			await _wait(0.12 if rarity < 5 else 0.22)
			if skipped:
				return

	if rarity == 5:
		# 慢慢推近 + 角色登场台词
		var zoom := create_tween()
		zoom.tween_property(holder, "scale", Vector2(1.06, 1.06), 3.0 / speed).set_trans(Tween.TRANS_SINE)
		var line := str(card.get("obtain", card.get("whisper", "")))
		if line != "":
			var sub := UIKit.label("「%s」" % line, 32, Color(1, 0.96, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
			sub.custom_minimum_size = Vector2(sz.x + 160, 0)
			sub.position = Vector2(-80, sz.y + 230)
			sub.size = Vector2(sz.x + 160, 120)
			sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(sub)
			UIKit.fade_in(sub, 0.6)
			Audio.play_voice(str(card.get("char", "")), line)
		hint.text = "轻触继续"
		await _wait_tap()
	elif rarity == 4:
		hint.text = "轻触继续"
		await _wait_tap(2.2)
	else:
		await _wait_tap(0.35 if quick else 1.2)
	hint.text = ""
	if skipped:
		return
	# 退场（最后一张直接进结果页）
	if not last:
		var out := create_tween().set_parallel()
		out.tween_property(holder, "modulate:a", 0.0, 0.18 / speed)
		out.tween_property(holder, "position:x", holder.position.x - 260, 0.18 / speed)
		await _wait(0.18)
	holder.queue_free()
