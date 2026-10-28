extends "res://src/screens/BaseScreen.gd"
## 实时战斗。玩法要点（规则在 src/systems/Combat.gd）：
## · 属性克制：潮克焰、焰克星、星克潮，克制时伤害 ×1.5。
## · 敌人按固定招式循环出招（可以记住套路）：普攻 / 重击 / 连击 / 护盾 / 蓄力 / 回复。
## · 预警最后 0.4 秒内闪避 = 完美闪避：无敌、自动反击、共鸣槽 +25。
## · 护盾只扣盾，技能和共鸣对盾 ×2，破盾后敌人眩晕；蓄力期间打出足够伤害可以打断。
## · 连击不中断时伤害递增；共鸣技有一个点击时机判定。
## · Boss 血量过半进入第二形态；结算按表现给 1–3 星。

const Combat := preload("res://src/systems/Combat.gd")

var enemy_id := ""
var partner_id := ""
var enemy: Dictionary = {}
var partner: Dictionary = {}
var stats: Dictionary = {}
var battle_key := ""
var mode := "story"

var ehp := 0.0
var ehp_max := 1.0
var e_atk := 60.0
var e_def := 10.0
var php := 0.0
var php_max := 1.0
var meter := 0.0
var attack_cd := 0.0
var skill_cd := 0.0
var dodge_cd := 0.0
var invuln := 0.0
var partner_timer := 0.0
var over := false
var elapsed := 0.0
var paused := false

# 敌人状态机
var phase := 1
var pattern: Array = []
var pat_i := 0
var state := "idle"  # idle / tele / combo / stun
var st_timer := 0.0
var cur_move := ""
var tele_len := 0.0
var speed_mult := 1.0
var hits_left := 0
var shield := 0.0
var shield_max := 1.0
var charge_dealt := 0.0
var charge_need := 0.0
var elem_p := ""
var elem_e := ""

# 表现统计
var combo := 0
var best_combo := 0
var perfect := 0

var enemy_img: TextureRect
var enemy_box: Control
var enemy_bar: ProgressBar
var shield_bar: ProgressBar
var enemy_hp_label: Label
var enemy_name_label: Label
var enemy_elem_pill: PanelContainer
var weak_label: Label
var combo_label: Label
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
	battle_key = str(params.get("key", ""))
	mode = str(params.get("mode", "story"))
	enemy = Data.enemy(enemy_id).duplicate(true)
	partner = Data.character(partner_id)
	stats = Game.team_stats(partner_id)
	ehp_max = float(enemy.get("hp", 900)) * float(params.get("hp_mult", 1.0))
	ehp = ehp_max
	e_atk = float(enemy.get("atk", 60)) * float(params.get("atk_mult", 1.0))
	e_def = float(enemy.get("def", 10))
	php_max = float(stats.hp)
	php = php_max
	elem_p = str(partner.get("element", ""))
	elem_e = str(enemy.get("element", ""))
	pattern = Array(enemy.get("pattern", ["hit"]))

	var bg := UIKit.image(Data.texture("backgrounds/battle_rift"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.modulate = Color(0.6, 0.62, 0.8)
	add_child(bg)
	add_child(UIKit.gradient_rect(Color(0.02, 0.03, 0.1, 0.2), Color(0.02, 0.03, 0.1, 0.9)))

	var m := UIKit.safe_margin(36, 70, 36, 40)
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 敌人信息
	var top := UIKit.hbox(12)
	enemy_name_label = UIKit.label(str(enemy.get("name", "潮影")), 40, UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_LEFT, false)
	top.add_child(enemy_name_label)
	enemy_elem_pill = UIKit.pill(elem_e if elem_e != "" else "无", UIKit.element_color(elem_e), 24)
	top.add_child(enemy_elem_pill)
	if bool(enemy.get("boss", false)):
		top.add_child(UIKit.pill("BOSS", UIKit.C_GOLD, 24))
	top.add_child(UIKit.spacer(0, true))
	enemy_hp_label = UIKit.label("", 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_RIGHT, false)
	top.add_child(enemy_hp_label)
	v.add_child(top)
	var bars := UIKit.vbox(4)
	enemy_bar = UIKit.progress(ehp, ehp_max, UIKit.C_DANGER, 20)
	bars.add_child(enemy_bar)
	shield_bar = UIKit.progress(0, 1, UIKit.C_GOLD, 10)
	shield_bar.visible = false
	bars.add_child(shield_bar)
	v.add_child(bars)
	var info := UIKit.hbox(10)
	weak_label = UIKit.label("", 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_LEFT, false)
	weak_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(weak_label)
	combo_label = UIKit.label("", 30, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_RIGHT, false)
	info.add_child(combo_label)
	v.add_child(info)
	_update_weak_label()

	enemy_box = CenterContainer.new()
	enemy_box.custom_minimum_size = Vector2(0, 720)
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
	row.add_child(UIKit.pill(elem_p, UIKit.element_color(elem_p), 22))
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

	log_label = UIKit.label("%s出现了！记住它的出招顺序，预警快结束时闪避能反击。" % str(enemy.get("name", "")), 24, UIKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
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
	elif not Game.tutorial_done("battle2"):
		_run_tutorial2()


func _update_weak_label() -> void:
	var weak := Combat.weakness(elem_e)
	var m := Combat.element_mult(elem_p, elem_e)
	var t := "弱点：%s" % weak if weak != "" else ""
	if m > 1.0:
		t += "  ·  %s 属性克制 ×1.5" % str(partner.get("name", ""))
		weak_label.add_theme_color_override("font_color", UIKit.C_OK)
	elif m < 1.0:
		t += "  ·  被克制，伤害 ×0.75，要小心"
		weak_label.add_theme_color_override("font_color", UIKit.C_DANGER)
	else:
		weak_label.add_theme_color_override("font_color", UIKit.C_MUTED)
	weak_label.text = t


## 第一次战斗时暂停，讲解四个按钮。
func _run_tutorial() -> void:
	paused = true
	await get_tree().create_timer(0.35).timeout  # 等转场动画结束再量控件位置
	var steps := [
		{"who": partner_id, "target": attack_btn, "text": "点「攻击」出手。连续命中会叠连击，伤害越来越高。"},
		{"who": partner_id, "target": skill_btn, "text": "这是我的技能，伤害更高，打护盾也更快，用完要等冷却。"},
		{"who": partner_id, "target": dodge_btn, "text": "它出手前会亮红光预警。等到预警快结束再「闪避」，就是完美闪避，我会顺势反击。"},
		{"who": partner_id, "target": res_btn, "text": "共鸣槽满了，就和我一起放共鸣技。光圈缩到最小时点一下，威力最大。"},
		{"who": partner_id, "target": weak_label, "text": "看这里：潮克焰、焰克星、星克潮。带克制属性的搭档，伤害 ×1.5。"},
	]
	Router.coach(steps, func() -> void:
		Game.mark_tutorial("battle")
		Game.mark_tutorial("battle2")
		paused = false)


## 老存档：已经看过旧版教学的玩家，补讲新机制。
func _run_tutorial2() -> void:
	paused = true
	await get_tree().create_timer(0.35).timeout
	var steps := [
		{"who": partner_id, "target": weak_label, "text": "新规矩：潮克焰、焰克星、星克潮，克制时伤害 ×1.5。"},
		{"who": partner_id, "target": dodge_btn, "text": "预警快结束时闪避是「完美闪避」，我会反击。护盾要用技能破，蓄力要在倒计时内打断。"},
	]
	Router.coach(steps, func() -> void:
		Game.mark_tutorial("battle2")
		paused = false)


func _process(delta: float) -> void:
	if over or paused:
		return
	elapsed += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	skill_cd = maxf(0.0, skill_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	_enemy_tick(delta)

	# 搭档自动助攻
	partner_timer += delta
	if partner_timer >= 3.0:
		partner_timer = 0.0
		_deal(0.55, 1.0, "%s 助攻" % str(partner.get("name", "")), UIKit.C_ACCENT, false, false)

	_refresh_buttons()


# ---------------- 敌人出招 ----------------

func _gap() -> float:
	return maxf(0.5, float(enemy.get("attack_interval", 2.0)) - 0.8) * speed_mult


func _enemy_tick(delta: float) -> void:
	st_timer += delta
	match state:
		"idle":
			if st_timer >= _gap():
				_start_move()
		"tele":
			if cur_move == "charge":
				var left := maxf(0.0, tele_len - st_timer)
				warn_label.text = "⚠ %s！%.1f 秒内再打 %d 伤害可打断" % [Combat.move_name(enemy, "charge"), left, maxi(0, int(charge_need - charge_dealt))]
				if charge_dealt >= charge_need:
					_interrupt()
					return
			if st_timer >= tele_len:
				_resolve_move()
		"combo":
			if st_timer >= float(Combat.move("combo").gap):
				st_timer = 0.0
				_lunge_fx()
				_enemy_strike(float(Combat.move("combo").mult))
				hits_left -= 1
				if hits_left <= 0:
					_to_idle()
		"stun":
			if st_timer >= tele_len:
				enemy_img.modulate = Color.WHITE
				_to_idle()


func _start_move() -> void:
	cur_move = str(pattern[pat_i % pattern.size()])
	pat_i += 1
	var mv := Combat.move(cur_move)
	tele_len = float(mv.tele) * (1.0 if cur_move == "charge" else speed_mult)
	state = "tele"
	st_timer = 0.0
	var nm := Combat.move_name(enemy, cur_move)
	match cur_move:
		"charge":
			charge_dealt = 0.0
			charge_need = ehp_max * float(mv.get("break", 0.09))
		"shield":
			warn_label.text = "❖ %s 正在架起护盾" % nm
		"heal":
			warn_label.text = "❖ %s 准备回复" % nm
		"heavy":
			warn_label.text = "⚠⚠ %s！伤害很高，找准时机闪避" % nm
		"combo":
			warn_label.text = "⚠ %s（三连击）" % nm
		_:
			warn_label.text = "⚠ %s" % nm
	if cur_move in ["hit", "heavy", "combo", "charge"]:
		_telegraph_fx(tele_len)


func _resolve_move() -> void:
	warn_label.text = ""
	var mv := Combat.move(cur_move)
	match cur_move:
		"hit", "heavy", "charge":
			_lunge_fx()
			_enemy_strike(float(mv.mult))
			_to_idle()
		"combo":
			_lunge_fx()
			_enemy_strike(float(mv.mult))
			hits_left = int(mv.hits) - 1
			state = "combo"
			st_timer = 0.0
		"shield":
			shield_max = ehp_max * float(mv.shield)
			shield = shield_max
			shield_bar.visible = true
			log_label.text = "%s：护盾 %d。技能和共鸣对护盾伤害 ×2！" % [Combat.move_name(enemy, "shield"), int(shield)]
			_popup("护盾", UIKit.C_GOLD, enemy_box)
			_refresh()
			_to_idle()
		"heal":
			var h := ehp_max * float(mv.heal)
			ehp = minf(ehp_max, ehp + h)
			log_label.text = "%s：回复了 %d" % [Combat.move_name(enemy, "heal"), int(h)]
			_popup("+%d" % int(h), UIKit.C_OK, enemy_box)
			_refresh()
			_to_idle()
		_:
			_to_idle()


func _to_idle() -> void:
	state = "idle"
	st_timer = 0.0
	cur_move = ""


func _stun(sec: float, text: String) -> void:
	state = "stun"
	st_timer = 0.0
	tele_len = sec
	warn_label.text = ""
	enemy_img.modulate = Color(0.6, 0.6, 0.75)
	_popup(text, UIKit.C_GOLD, enemy_box)
	_lunge_fx()  # 收回蓄力姿态


func _interrupt() -> void:
	meter = minf(100.0, meter + 20.0)
	log_label.text = "打断成功！%s 陷入眩晕" % str(enemy.get("name", ""))
	_stun(2.2, "破招！")


func _enemy_strike(mult: float) -> void:
	if invuln > 0.0:
		log_label.text = "闪避成功！"
		_popup("MISS", UIKit.C_OK, partner_img)
		return
	var em := Combat.element_mult(elem_e, elem_p)
	var dmg := int(_damage(e_atk * mult, float(stats.def)) * em)
	php = maxf(0.0, php - dmg)
	combo = 0
	combo_label.text = ""
	log_label.text = "%s 命中，你受到 %d 伤害" % [str(enemy.get("name", "")), dmg]
	_popup("-%d" % dmg, UIKit.C_DANGER, partner_img)
	_flash(Color(1, 0.3, 0.3, 0.35))
	_refresh()
	if php <= 0.0:
		_finish(false)


# ---------------- 我方行动 ----------------

func _damage(atk: float, def: float) -> int:
	var base := atk * randf_range(0.9, 1.12) - def * 0.5
	return maxi(5, int(base))


## 我方造成伤害：属性克制、连击加成、护盾、蓄力打断、Boss 变身都在这里处理。
func _deal(mult: float, def_scale: float, label: String, color: Color, is_skill: bool, count_combo := true) -> void:
	if over:
		return
	var em := Combat.element_mult(elem_p, elem_e)
	var bonus := 1.0 + minf(0.3, combo * 0.015)
	var dmg := int(_damage(float(stats.atk) * mult, e_def * def_scale) * em * bonus)
	if count_combo:
		combo += 1
		best_combo = maxi(best_combo, combo)
		combo_label.text = "%d 连击" % combo if combo >= 3 else ""
	if state == "tele" and cur_move == "charge":
		charge_dealt += dmg
	if shield > 0.0:
		var sd := dmg * (2.0 if is_skill else 1.0)
		shield -= sd
		_popup("-%d" % int(sd), UIKit.C_GOLD, enemy_box)
		_hit_fx(dmg)
		if shield <= 0.0:
			shield = 0.0
			shield_bar.visible = false
			log_label.text = "护盾破碎！敌人眩晕"
			_stun(1.6, "破盾！")
		else:
			log_label.text = "%s 打在护盾上（%d）" % [label, int(sd)]
		_refresh()
		return
	ehp = maxf(0.0, ehp - dmg)
	var tag := ""
	if em > 1.0:
		tag = " 克制！"
	elif em < 1.0:
		tag = " 被抵抗"
	log_label.text = "%s 造成 %d 伤害%s" % [label, dmg, tag]
	_popup("-%d%s" % [dmg, "!" if em > 1.0 else ""], color, enemy_box)
	_hit_fx(dmg)
	_refresh()
	if ehp <= 0.0:
		_finish(true)
	elif phase == 1 and enemy.has("phase2") and ehp <= ehp_max * 0.5:
		_enter_phase2()


func _attack() -> void:
	if over or paused or attack_cd > 0.0:
		return
	attack_cd = 0.42
	meter = minf(100.0, meter + 10.0)
	_deal(1.0, 1.0, "普攻", UIKit.C_TEXT, false)


func _skill() -> void:
	if over or paused or skill_cd > 0.0:
		return
	var skill: Dictionary = partner.get("skill", {})
	skill_cd = float(skill.get("cooldown", 6.0))
	meter = minf(100.0, meter + 18.0)
	_deal(float(skill.get("mult", 1.8)), 1.0, str(skill.get("name", "技能")), UIKit.element_color(elem_p), true)


func _dodge() -> void:
	if over or paused or dodge_cd > 0.0:
		return
	var left := tele_len - st_timer
	if state == "tele" and cur_move in ["hit", "heavy", "combo", "charge"] and left <= Combat.PERFECT_WINDOW:
		_perfect_dodge()
		return
	dodge_cd = 2.0
	invuln = 0.75
	log_label.text = "闪避！0.75 秒内无敌（预警快结束时闪避更好）"
	var tw := create_tween()
	tw.tween_property(partner_img, "modulate", Color(1, 1, 1, 0.4), 0.1)
	tw.tween_property(partner_img, "modulate", Color(1, 1, 1, 1.0), 0.5)


func _perfect_dodge() -> void:
	perfect += 1
	dodge_cd = 0.6
	invuln = 1.4  # 连击也能全部躲开
	meter = minf(100.0, meter + 25.0)
	_flash(Color(0.7, 0.85, 1.0, 0.45))
	_popup("完美闪避", UIKit.C_OK, partner_img)
	# 短暂慢动作
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)
	_deal(1.3, 0.5, "完美闪避 · 反击", UIKit.C_OK, true)


## 共鸣技：光圈从大缩小，缩到和内圈重合时点击 = 完美（×1.5）。
func _resonance() -> void:
	if over or paused or meter < 100.0:
		if meter < 100.0:
			Router.toast("共鸣槽未满")
		return
	meter = 0.0
	paused = true
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	var center := enemy_box.get_global_rect().get_center()
	var col := Color(str(partner.get("color", "#f2a7b5")))
	var target := _ring(center, 220.0, Color(1, 1, 1, 0.9), 6)
	layer.add_child(target)
	var ring := _ring(center, 220.0, col, 10)
	ring.scale = Vector2(2.4, 2.4)
	layer.add_child(ring)
	var hint := UIKit.label("光圈重合时点击！", 40, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER, false)
	hint.position = Vector2(0, center.y + 280)
	hint.size = Vector2(get_viewport_rect().size.x, 60)
	layer.add_child(hint)
	var t0 := Time.get_ticks_msec()
	var done := {"v": false}
	var finish_qte := func(t: float) -> void:
		if done.v:
			return
		done.v = true
		var diff := absf(t - 0.8)
		var mult := 1.0
		var grade := "共鸣"
		if diff <= 0.1:
			mult = 1.5
			grade = "完美共鸣！"
		elif diff <= 0.22:
			mult = 1.2
			grade = "共鸣成功"
		layer.queue_free()
		paused = false
		var res: Dictionary = partner.get("resonance", {})
		_flash(col)
		_popup(grade, UIKit.C_ROSE, partner_img)
		_deal(float(res.get("mult", 3.0)) * mult, 0.5, "共鸣技 · " + str(res.get("name", "")), UIKit.C_ROSE, true)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.8)
	tw.tween_property(ring, "scale", Vector2(0.7, 0.7), 0.3)
	tw.tween_callback(func() -> void: finish_qte.call(1.1))
	layer.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			finish_qte.call(float(Time.get_ticks_msec() - t0) / 1000.0))


func _ring(center: Vector2, d: float, color: Color, w: int) -> Panel:
	var p := Panel.new()
	var sbx := StyleBoxFlat.new()
	sbx.bg_color = Color(color, 0.08)
	sbx.border_color = color
	sbx.set_border_width_all(w)
	sbx.set_corner_radius_all(int(d))
	sbx.shadow_color = Color(color, 0.5)
	sbx.shadow_size = 16
	p.add_theme_stylebox_override("panel", sbx)
	p.size = Vector2(d, d)
	p.position = center - Vector2(d, d) / 2.0
	p.pivot_offset = Vector2(d, d) / 2.0
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Boss 第二形态：闪光、换形象、换配色、出招更快更狠。
func _enter_phase2() -> void:
	phase = 2
	var p2: Dictionary = enemy.phase2
	paused = true
	_to_idle()
	warn_label.text = ""
	shield = 0.0
	shield_bar.visible = false
	_flash(Color(1, 1, 1, 0.9))
	log_label.text = str(p2.get("line", "它的样子变了！"))
	enemy.name = str(p2.get("name", enemy.name))
	enemy_name_label.text = str(enemy.name)
	if p2.has("element"):
		elem_e = str(p2.element)
		enemy_elem_pill.get_child(0).text = elem_e
		_update_weak_label()
	e_atk *= float(p2.get("atk_mult", 1.2))
	speed_mult = float(p2.get("speed_mult", 0.85))
	pattern = Array(p2.get("pattern", pattern))
	pat_i = 0
	if p2.has("skill_names"):
		var names: Dictionary = enemy.get("skill_names", {}).duplicate()
		names.merge(p2.skill_names, true)
		enemy.skill_names = names
	var aura_c := Color(str(p2.get("aura", enemy.get("aura", "#ffffff"))))
	var tw := create_tween()
	tw.tween_property(enemy_body, "scale", Vector2(0.2, 1.4), 0.25)
	tw.tween_callback(func() -> void:
		enemy_img.texture = Data.texture(str(p2.get("img", enemy.get("img", ""))))
		enemy_mat.set_shader_parameter("rim_color", Color(aura_c, 0.9))
		var g: Gradient = (enemy_aura.texture as GradientTexture2D).gradient
		g.set_color(0, Color(aura_c, 0.6))
		g.set_color(1, Color(aura_c, 0.0)))
	tw.tween_property(enemy_body, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK)
	tw.tween_property(enemy_body, "scale", Vector2.ONE, 0.3)
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void: paused = false)
	_popup("第二形态", UIKit.C_GOLD, enemy_box)


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
	enemy_bar.max_value = ehp_max
	enemy_hp_label.text = "%d / %d" % [int(ehp), int(ehp_max)]
	shield_bar.max_value = shield_max
	shield_bar.value = shield
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
	Engine.time_scale = 1.0
	if win:
		_death_fx()
		await get_tree().create_timer(0.9).timeout
	Game.s.stats.battles = int(Game.s.stats.battles) + 1
	var reward: Dictionary = params.get("reward", enemy.get("reward", {}))
	var first_note := ""
	var n_stars := Combat.stars(win, php / php_max, perfect)
	var bonus := {}
	if win:
		Game.s.stats.wins = int(Game.s.stats.wins) + 1
		Game.mark_seen(enemy_id)
		Game.task_progress("battle")
		match mode:
			"tower":
				if Game.clear_tower(int(params.get("floor", 0))):
					first_note = "首次通关奖励"
				else:
					reward = {"gold": int(reward.get("gold", 0)) / 4}
			"hunt":
				if Game.hunt_done_today():
					reward = {}
				else:
					Game.mark_hunt_done()
					first_note = "今日讨伐奖励"
		Game.grant(reward)
		bonus = Game.record_stars(battle_key, n_stars)
	else:
		Game.save()
	var panel := UIKit.panel(UIKit.C_PANEL, 32, 40, UIKit.C_LINE, 2)
	panel.custom_minimum_size = Vector2(880, 0)
	var v := UIKit.vbox(14)
	v.add_child(UIKit.label("胜利" if win else "失败", 56, UIKit.C_GOLD if win else UIKit.C_DANGER, HORIZONTAL_ALIGNMENT_CENTER))
	if win:
		var star_txt := ""
		for i in 3:
			star_txt += "★" if i < n_stars else "☆"
		var sl := UIKit.label(star_txt, 72, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
		v.add_child(sl)
		UIKit.pop(sl, 0.5, 0.5)
		var conds := [["击败敌人", true], ["剩余血量 ≥ 50%", php / php_max >= 0.5], ["至少 1 次完美闪避", perfect >= 1]]
		for c in conds:
			v.add_child(UIKit.label(("✓ " if c[1] else "· ") + str(c[0]), 26, UIKit.C_OK if c[1] else UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("用时 %.1f 秒 · 最高 %d 连击 · 完美闪避 %d 次" % [elapsed, best_combo, perfect], 24, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	if win:
		if not reward.is_empty():
			v.add_child(UIKit.label(("%s：" % first_note if first_note != "" else "获得：") + UIKit.reward_text(reward), 28, UIKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		if not bonus.is_empty():
			v.add_child(UIKit.label("首次三星：" + UIKit.reward_text(bonus), 28, UIKit.C_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UIKit.label("%s：「%s」" % [str(partner.get("name", "")), _win_line()], 28, UIKit.C_ROSE, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var tip := "试试克制属性的搭档，或者提升思念卡等级。" if Combat.element_mult(elem_p, elem_e) < 1.0 else "记住它的出招顺序，在预警最后一刻闪避就能反击。"
		v.add_child(UIKit.label(tip, 26, UIKit.C_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UIKit.button("继续", "primary", 34, 96)
	v.add_child(ok)
	panel.add_child(v)
	var dim := Router.modal(panel, false)
	ok.pressed.connect(func() -> void:
		dim.queue_free()
		Router.back({"win": win, "stars": n_stars}))


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _win_line() -> String:
	match partner_id:
		"shen_yan":
			return "……没受伤吧。下次离我近一点。"
		"gu_ci":
			return "配合得很好。我就知道，你可以的。"
		"lu_zhuo":
			return "爽！下次还跟我组队，说定了。"
	return "干得漂亮。"
