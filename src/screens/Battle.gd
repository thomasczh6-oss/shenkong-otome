extends "res://src/screens/BaseScreen.gd"
## 轻量实时战斗：点击「攻击」出手，技能有冷却，敌人攻击前会预警、可「闪避」，
## 攻击积攒共鸣槽，满了可以和搭档释放「共鸣技」。参考《恋与深空》把战斗做轻、做爽的思路。

var enemy_id := ""
var partner_id := ""
var enemy: Dictionary = {}
var partner: Dictionary = {}
var stats: Dictionary = {}

var ehp := 0.0
var ehp_max := 1.0
var php := 0.0
var php_max := 1.0
var meter := 0.0
var attack_cd := 0.0
var skill_cd := 0.0
var dodge_cd := 0.0
var invuln := 0.0
var enemy_timer := 0.0
var telegraphing := false
var partner_timer := 0.0
var over := false
var elapsed := 0.0
var paused := false

var enemy_img: TextureRect
var enemy_box: Control
var enemy_bar: ProgressBar
var enemy_hp_label: Label
var player_bar: ProgressBar
var player_hp_label: Label
var meter_bar: ProgressBar
var warn_label: Label
var log_label: Label
var attack_btn: Button
var skill_btn: Button
var dodge_btn: Button
var res_btn: Button
var partner_img: TextureRect


func build() -> void:
	enemy_id = str(params.get("enemy", "tide_shade"))
	partner_id = str(params.get("partner", "shen_yan"))
	enemy = Data.enemy(enemy_id)
	partner = Data.character(partner_id)
	stats = Game.team_stats(partner_id)
	ehp_max = float(enemy.get("hp", 900))
	ehp = ehp_max
	php_max = float(stats.hp)
	php = php_max

	var bg := UIKit.image(Data.texture("backgrounds/battle_rift"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.6, 0.62, 0.8)
	add_child(bg)
	add_child(UIKit.gradient_rect(Color(0.02, 0.03, 0.1, 0.2), Color(0.02, 0.03, 0.1, 0.9)))

	var m := UIKit.safe_margin(36, 70, 36, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 敌人
	var top := UIKit.hbox(12)
	top.add_child(UIKit.label(str(enemy.get("name", "潮影")) + ("  BOSS" if bool(enemy.get("boss", false)) else ""), 40, UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_LEFT, false))
	top.add_child(UIKit.spacer(0, true))
	enemy_hp_label = UIKit.label("", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	top.add_child(enemy_hp_label)
	v.add_child(top)
	enemy_bar = UIKit.progress(ehp, ehp_max, UIKit.C_DANGER, 20)
	v.add_child(enemy_bar)

	enemy_box = CenterContainer.new()
	enemy_box.custom_minimum_size = Vector2(0, 780)
	enemy_box.size_flags_vertical = Control.SIZE_EXPAND_FILL  # 长屏手机上怪物居中，不留大片空白
	enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_box.add_child(_build_enemy_stage())
	v.add_child(enemy_box)
	warn_label = UIKit.label("", 30, UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER, false)
	warn_label.custom_minimum_size = Vector2(0, 44)
	v.add_child(warn_label)
	v.add_child(UIKit.label(str(enemy.get("desc", "")), 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))

	# 我方
	var me := UIKit.hbox(16)
	var pbox := UIKit.image_box(Data.texture(Data.portrait_key(partner_id, "serious")), Vector2(150, 190), 22, Color(str(partner.get("color", "#4fd1c5"))), 3)
	partner_img = pbox.get_child(0)
	me.add_child(pbox)
	var mv := UIKit.vbox(8)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := UIKit.hbox(10)
	row.add_child(UIKit.label("%s × %s" % [Game.player_name(), str(partner.get("name", ""))], 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	row.add_child(UIKit.spacer(0, true))
	player_hp_label = UIKit.label("", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	row.add_child(player_hp_label)
	mv.add_child(row)
	player_bar = UIKit.progress(php, php_max, UIKit.C_OK, 20)
	mv.add_child(player_bar)
	mv.add_child(UIKit.label("共鸣槽", 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	meter_bar = UIKit.progress(0, 100, UIKit.C_ROSE, 16)
	mv.add_child(meter_bar)
	mv.add_child(UIKit.label("攻击 %d · 防御 %d · 战力 %d" % [stats.atk, stats.def, Game.power(partner_id)], 22, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false))
	me.add_child(mv)
	v.add_child(me)

	log_label = UIKit.label("潮影出现了！点击「攻击」出手，看到预警就「闪避」。", 24, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	log_label.custom_minimum_size = Vector2(0, 70)
	v.add_child(log_label)

	# 操作
	var grid := UIKit.hbox(10)
	attack_btn = UIKit.button("攻击", "primary", 32, 120)
	attack_btn.pressed.connect(_attack)
	var skill: Dictionary = partner.get("skill", {})
	skill_btn = UIKit.button(str(skill.get("name", "技能")), "dark", 30, 120)
	skill_btn.pressed.connect(_skill)
	dodge_btn = UIKit.button("闪避", "dark", 30, 120)
	dodge_btn.pressed.connect(_dodge)
	var res: Dictionary = partner.get("resonance", {})
	res_btn = UIKit.button(str(res.get("name", "共鸣")), "rose", 28, 120)
	res_btn.pressed.connect(_resonance)
	for b in [attack_btn, skill_btn, dodge_btn, res_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	v.add_child(grid)
	m.add_child(v)
	add_child(m)
	_refresh()
	Audio.play_bgm("battle")
	if not Game.tutorial_done("battle"):
		_run_tutorial()


## 第一次战斗时暂停，讲解四个按钮。
func _run_tutorial() -> void:
	paused = true
	await get_tree().create_timer(0.35).timeout  # 等转场动画结束再量控件位置
	var steps := [
		{"who": partner_id, "target": attack_btn, "text": "点「攻击」出手。每次攻击都会攒一点共鸣槽。"},
		{"who": partner_id, "target": skill_btn, "text": "这是我的技能，伤害更高，用完要等一会儿冷却。"},
		{"who": partner_id, "target": dodge_btn, "text": "它攻击前会亮起红色预警——那时候点「闪避」，就不会受伤。"},
		{"who": partner_id, "target": res_btn, "text": "共鸣槽满了，就和我一起放共鸣技。……别怕，我在。"},
	]
	Router.coach(steps, func() -> void:
		Game.mark_tutorial("battle")
		paused = false)


func _process(delta: float) -> void:
	if over or paused:
		return
	elapsed += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	invuln = maxf(0.0, invuln - delta)

	# 敌人攻击节奏：预警 → 出手
	enemy_timer += delta
	var interval := float(enemy.get("attack_interval", 2.4))
	var tele := float(enemy.get("telegraph", 0.9))
	if not telegraphing and enemy_timer >= interval - tele:
		telegraphing = true
		warn_label.text = "⚠ %s 准备攻击！" % str(enemy.get("name", ""))
		_telegraph_fx(tele)
	if enemy_timer >= interval:
		enemy_timer = 0.0
		telegraphing = false
		warn_label.text = ""
		_lunge_fx()
		_enemy_attack()

	# 搭档自动助攻
	partner_timer += delta
	if partner_timer >= 3.0:
		partner_timer = 0.0
		var dmg := _damage(float(stats.atk) * 0.55, float(enemy.get("def", 10)))
		_hit_enemy(dmg, "%s 助攻" % str(partner.get("name", "")), UIKit.C_ACCENT)

	_refresh_buttons()


func _damage(atk: float, def: float) -> int:
	var base := atk * randf_range(0.9, 1.12) - def * 0.5
	return maxi(5, int(base))


func _attack() -> void:
	if over or attack_cd > 0.0:
		return
	attack_cd = 0.42
	var dmg := _damage(float(stats.atk), float(enemy.get("def", 10)))
	meter = minf(100.0, meter + 12.0)
	_hit_enemy(dmg, "普攻", UIKit.C_TEXT)


func _skill() -> void:
	if over or skill_cd > 0.0:
		return
	var skill: Dictionary = partner.get("skill", {})
	skill_cd = float(skill.get("cooldown", 6.0))
	var dmg := _damage(float(stats.atk) * float(skill.get("mult", 1.8)), float(enemy.get("def", 10)))
	meter = minf(100.0, meter + 20.0)
	_hit_enemy(dmg, str(skill.get("name", "技能")), UIKit.element_color(str(partner.get("element", ""))))


func _dodge() -> void:
	if over or dodge_cd > 0.0:
		return
	dodge_cd = 2.4
	invuln = 0.75
	log_label.text = "闪避！0.75 秒内无敌"
	var tw := create_tween()
	tw.tween_property(partner_img, "modulate", Color(1, 1, 1, 0.4), 0.1)
	tw.tween_property(partner_img, "modulate", Color(1, 1, 1, 1.0), 0.5)


func _resonance() -> void:
	if over or meter < 100.0:
		Router.toast("共鸣槽未满")
		return
	meter = 0.0
	var res: Dictionary = partner.get("resonance", {})
	var dmg := _damage(float(stats.atk) * float(res.get("mult", 3.0)), float(enemy.get("def", 10)) * 0.5)
	_flash(Color(str(partner.get("color", "#f2a7b5"))))
	_hit_enemy(dmg, "共鸣技 · " + str(res.get("name", "")), UIKit.C_ROSE)


func _hit_enemy(dmg: int, label: String, color: Color) -> void:
	ehp = maxf(0.0, ehp - dmg)
	log_label.text = "%s 造成 %d 伤害" % [label, dmg]
	_popup("-%d" % dmg, color, enemy_box)
	_hit_fx(dmg)
	_refresh()
	if ehp <= 0.0:
		_finish(true)


# ---------------- 敌人表现 ----------------

var enemy_mat: ShaderMaterial
var enemy_aura: TextureRect
var enemy_body: Control
var idle_tw: Tween


## 敌人舞台：背后的光晕、地面阴影、上飘的粒子、带描边发光着色器的本体，整体缓慢呼吸浮动。
func _build_enemy_stage() -> Control:
	var boss := bool(enemy.get("boss", false))
	var side := 780.0 if boss else 720.0
	var aura_c := Color(str(enemy.get("aura", "#4fa3ff")))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(side, side)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var g := Gradient.new()
	g.set_color(0, Color(aura_c, 0.55 if boss else 0.4))
	g.set_color(1, Color(aura_c, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	gt.width = 256
	gt.height = 256
	enemy_aura = TextureRect.new()
	enemy_aura.texture = gt
	enemy_aura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_aura.size = Vector2(side, side) * 1.15
	enemy_aura.position = -Vector2(side, side) * 0.075
	enemy_aura.pivot_offset = enemy_aura.size / 2.0
	enemy_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(enemy_aura)
	var at := enemy_aura.create_tween().set_loops()
	at.tween_property(enemy_aura, "modulate:a", 0.55, 1.6).set_trans(Tween.TRANS_SINE)
	at.tween_property(enemy_aura, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)

	var sg := Gradient.new()
	sg.set_color(0, Color(0, 0, 0, 0.6))
	sg.set_color(1, Color(0, 0, 0, 0))
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill = GradientTexture2D.FILL_RADIAL
	st.fill_from = Vector2(0.5, 0.5)
	st.fill_to = Vector2(0.5, 0.0)
	var shadow := TextureRect.new()
	shadow.texture = st
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.size = Vector2(side * 0.7, side * 0.12)
	shadow.position = Vector2(side * 0.15, side * 0.88)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(shadow)

	var motes := CPUParticles2D.new()
	motes.position = Vector2(side / 2.0, side * 0.75)
	motes.amount = 60 if boss else 36
	motes.lifetime = 3.2
	motes.preprocess = 3.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = side * 0.38
	motes.direction = Vector2(0, -1)
	motes.spread = 25.0
	motes.gravity = Vector2(0, -30)
	motes.initial_velocity_min = 20.0
	motes.initial_velocity_max = 70.0
	motes.scale_amount_min = 3.0
	motes.scale_amount_max = 8.0
	var cr := Gradient.new()
	cr.set_color(0, Color(aura_c.lightened(0.4), 0.0))
	cr.add_point(0.25, Color(aura_c.lightened(0.4), 0.9))
	cr.set_color(cr.get_point_count() - 1, Color(aura_c, 0.0))
	motes.color_ramp = cr
	stage.add_child(motes)

	enemy_body = Control.new()
	enemy_body.size = Vector2(side, side)
	enemy_body.pivot_offset = Vector2(side / 2.0, side * 0.9)
	enemy_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(enemy_body)
	enemy_img = UIKit.image(Data.texture(str(enemy.get("img", "enemies/tide_shade"))), false)
	enemy_img.size = Vector2(side, side) * 0.92
	enemy_img.position = Vector2(side, side) * 0.04
	enemy_mat = ShaderMaterial.new()
	enemy_mat.shader = preload("res://src/fx/enemy.gdshader")
	enemy_mat.set_shader_parameter("rim_color", Color(aura_c, 0.9))
	enemy_img.material = enemy_mat
	enemy_body.add_child(enemy_img)

	# 呼吸 + 漂浮
	idle_tw = enemy_body.create_tween().set_loops().set_parallel(true)
	idle_tw.tween_property(enemy_body, "position:y", -18.0, 1.8).set_trans(Tween.TRANS_SINE)
	idle_tw.tween_property(enemy_body, "scale", Vector2(1.02, 1.035), 1.8).set_trans(Tween.TRANS_SINE)
	idle_tw.chain().tween_property(enemy_body, "position:y", 0.0, 1.8).set_trans(Tween.TRANS_SINE)
	idle_tw.parallel().tween_property(enemy_body, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	# 出场
	enemy_body.modulate.a = 0.0
	create_tween().tween_property(enemy_body, "modulate:a", 1.0, 0.6)
	return stage


func _hit_fx(dmg: int) -> void:
	if enemy_mat == null:
		return
	var big := dmg > int(stats.atk) * 2
	enemy_mat.set_shader_parameter("flash", 0.85)
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: enemy_mat.set_shader_parameter("flash", x), 0.85, 0.0, 0.18)
	var amp := 26.0 if big else 14.0
	var sh := create_tween()
	for i in 4:
		sh.tween_property(enemy_img, "position:x", enemy_img.size.x * 0.0435 + randf_range(-amp, amp), 0.035)
	sh.tween_property(enemy_img, "position:x", enemy_img.size.x * 0.0435, 0.05)
	var pt := create_tween()
	enemy_img.pivot_offset = enemy_img.size / 2.0
	pt.tween_property(enemy_img, "scale", Vector2(0.93, 0.93) if big else Vector2(0.97, 0.97), 0.05)
	pt.tween_property(enemy_img, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)
	if big:
		_flash(Color(1, 1, 1, 0.35))


func _telegraph_fx(dur: float) -> void:
	if enemy_mat == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(x: float) -> void: enemy_mat.set_shader_parameter("warn", x), 0.0, 1.0, dur * 0.8)
	tw.tween_property(enemy_aura, "scale", Vector2(1.18, 1.18), dur * 0.8)
	tw.tween_property(enemy_img, "scale", Vector2(1.06, 1.06), dur * 0.8)
	enemy_img.pivot_offset = enemy_img.size / 2.0


func _lunge_fx() -> void:
	if enemy_mat == null:
		return
	var tw := create_tween()
	tw.tween_property(enemy_img, "scale", Vector2(1.16, 1.16), 0.08)
	tw.tween_property(enemy_img, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	var t2 := create_tween().set_parallel(true)
	t2.tween_method(func(x: float) -> void: enemy_mat.set_shader_parameter("warn", x), 1.0, 0.0, 0.3)
	t2.tween_property(enemy_aura, "scale", Vector2.ONE, 0.3)


func _death_fx() -> void:
	if enemy_mat == null:
		return
	if idle_tw != null:
		idle_tw.kill()
	var tw := create_tween()
	tw.tween_method(func(x: float) -> void: enemy_mat.set_shader_parameter("dissolve", x), 0.0, 1.05, 0.85)
	create_tween().tween_property(enemy_aura, "modulate:a", 0.0, 0.85)
	_flash(Color(1, 1, 1, 0.5))


func _enemy_attack() -> void:
	if invuln > 0.0:
		log_label.text = "闪避成功！"
		_popup("MISS", UIKit.C_OK, partner_img)
		return
	var dmg := _damage(float(enemy.get("atk", 60)), float(stats.def))
	php = maxf(0.0, php - dmg)
	log_label.text = "%s 攻击，你受到 %d 伤害" % [str(enemy.get("name", "")), dmg]
	_popup("-%d" % dmg, UIKit.C_DANGER, partner_img)
	_flash(Color(1, 0.3, 0.3, 0.35))
	_refresh()
	if php <= 0.0:
		_finish(false)


func _popup(text: String, color: Color, anchor: Control) -> void:
	var l := UIKit.label(text, 44, color, HORIZONTAL_ALIGNMENT_CENTER, false)
	add_child(l)
	var base := anchor.global_position + anchor.size / 2.0 + Vector2(randf_range(-60, 60), -40)
	l.global_position = base
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", base.y - 120, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tw.chain().tween_callback(l.queue_free)


func _flash(color: Color) -> void:
	var f := ColorRect.new()
	f.color = color
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "modulate:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _refresh() -> void:
	enemy_bar.value = ehp
	enemy_hp_label.text = "%d / %d" % [int(ehp), int(ehp_max)]
	player_bar.value = php
	player_hp_label.text = "%d / %d" % [int(php), int(php_max)]
	meter_bar.value = meter


func _refresh_buttons() -> void:
	meter_bar.value = meter
	attack_btn.disabled = attack_cd > 0.0
	skill_btn.disabled = skill_cd > 0.0
	var skill: Dictionary = partner.get("skill", {})
	skill_btn.text = str(skill.get("name", "技能")) + ("" if skill_cd <= 0.0 else " %.1f" % skill_cd)
	dodge_btn.disabled = dodge_cd > 0.0
	dodge_btn.text = "闪避" + ("" if dodge_cd <= 0.0 else " %.1f" % dodge_cd)
	res_btn.disabled = meter < 100.0


func _finish(win: bool) -> void:
	if over:
		return
	over = true
	if win:
		_death_fx()
		await get_tree().create_timer(0.9).timeout
	Game.s.stats.battles = int(Game.s.stats.battles) + 1
	var reward: Dictionary = enemy.get("reward", {})
	if win:
		Game.s.stats.wins = int(Game.s.stats.wins) + 1
		Game.task_progress("battle")
		Game.grant(reward)
	else:
		Game.save()
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 40, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(880, 0)
	var v := UIKit.vbox(16)
	v.add_child(UIKit.label("胜利" if win else "失败", 56, UIKit.C_GOLD if win else UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("用时 %.1f 秒" % elapsed, 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if win:
		v.add_child(UIKit.label("获得：" + UIKit.reward_text(reward), 30, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("%s：「%s」" % [str(partner.get("name", "")), _win_line()], 28, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(UIKit.label("提升思念卡等级或好感度可以变强。", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("继续", "primary", 34, 96)
	v.add_child(ok)
	panel.add_child(v)
	var dim := Router.modal(panel, false)
	ok.pressed.connect(func() -> void:
		dim.queue_free()
		Router.back({"win": win}))


func _win_line() -> String:
	match partner_id:
		"shen_yan":
			return "……没受伤吧。下次离我近一点。"
		"gu_ci":
			return "配合得很好。我就知道，你可以的。"
		"lu_zhuo":
			return "爽！下次还跟我组队，说定了。"
	return "干得漂亮。"
