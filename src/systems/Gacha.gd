extends RefCounted
## 许愿（抽卡）规则。数值参考《恋与深空》公开的概率：
## 5★ 基础 1%，4★ 7%；60 抽后每抽 +10% 软保底，70 抽硬保底；10 抽必出 4★；限定池歪了则下次必中 UP（大保底）。


static func pool(pool_id: String) -> Dictionary:
	return Data.gacha.get("pools", {}).get(pool_id, {})


static func pity(pool_id: String) -> Dictionary:
	if not Game.s.pity.has(pool_id):
		Game.s.pity[pool_id] = {"since5": 0, "since4": 0, "guaranteed": false, "total": 0}
	return Game.s.pity[pool_id]


## 当前这一抽的 5★ 概率（给界面展示）。
static func current_rate5(pool_id: String) -> float:
	var p := pool(pool_id)
	var pt := pity(pool_id)
	var next := int(pt.since5) + 1
	var rate := float(p.get("rate5", 0.01))
	var soft := int(p.get("soft_pity_start", 60))
	if next > soft:
		rate += float(p.get("soft_pity_step", 0.1)) * float(next - soft)
	if next >= int(p.get("hard_pity", 70)):
		rate = 1.0
	return minf(rate, 1.0)


static func pulls_to_hard_pity(pool_id: String) -> int:
	return int(pool(pool_id).get("hard_pity", 70)) - int(pity(pool_id).since5)


## 某稀有度在该池可抽到的卡：限定卡只在它 UP 的池里出现。
static func candidates(pool_id: String, rarity: int, featured_only := false, exclude_featured := false) -> Array:
	var p := pool(pool_id)
	var featured: Array = p.get("featured", [])
	var out: Array = []
	for id in Data.card_order:
		var c: Dictionary = Data.cards[id]
		if int(c.get("rarity", 3)) != rarity:
			continue
		var is_featured := featured.has(id)
		if featured_only and not is_featured:
			continue
		if exclude_featured and is_featured:
			continue
		if not is_featured and bool(c.get("limited", false)):
			continue
		out.append(id)
	return out


static func pull_one(pool_id: String) -> Dictionary:
	var p := pool(pool_id)
	var pt := pity(pool_id)
	pt.since5 = int(pt.since5) + 1
	pt.since4 = int(pt.since4) + 1
	pt.total = int(pt.total) + 1

	var rate5 := float(p.get("rate5", 0.01))
	var soft := int(p.get("soft_pity_start", 60))
	if int(pt.since5) > soft:
		rate5 += float(p.get("soft_pity_step", 0.1)) * float(int(pt.since5) - soft)
	if int(pt.since5) >= int(p.get("hard_pity", 70)):
		rate5 = 1.0
	var rate4 := float(p.get("rate4", 0.07))

	var r := randf()
	var rarity := 3
	if r < rate5:
		rarity = 5
	elif r < rate5 + rate4 or int(pt.since4) >= int(p.get("pity4", 10)):
		rarity = 4

	var card_id := ""
	if rarity == 5:
		pt.since5 = 0
		pt.since4 = 0
		var featured: Array = p.get("featured", [])
		if featured.size() > 0:
			var win: bool = bool(pt.guaranteed) or randf() < float(p.get("up_rate", 0.5))
			if win:
				card_id = str(featured.pick_random())
				pt.guaranteed = false
			else:
				card_id = str(candidates(pool_id, 5, false, true).pick_random())
				pt.guaranteed = true
		else:
			card_id = str(candidates(pool_id, 5).pick_random())
	elif rarity == 4:
		pt.since4 = 0
		card_id = str(candidates(pool_id, 4).pick_random())
	else:
		card_id = str(candidates(pool_id, 3).pick_random())

	var is_new := Game.add_card(card_id)
	return {"card": card_id, "rarity": rarity, "new": is_new}


## 扣费并连抽 n 次。优先用许愿券，不够的部分用钻石。
static func pull(pool_id: String, n: int) -> Dictionary:
	var p := pool(pool_id)
	var ticket_kind := str(p.get("ticket", "standard"))
	var have := Game.tickets(ticket_kind)
	var use_tickets := mini(have, n)
	var cost := int(p.get("cost_diamonds", 150))
	var need_diamonds := (n - use_tickets) * cost
	if Game.diamonds() < need_diamonds:
		return {"ok": false, "error": "钻石不足，还差 %d" % (need_diamonds - Game.diamonds())}
	Game.s.tickets[ticket_kind] = have - use_tickets
	Game.s.diamonds = Game.diamonds() - need_diamonds
	var results: Array = []
	for i in n:
		results.append(pull_one(pool_id))
	Game.s.stats.pulls = int(Game.s.stats.pulls) + n
	Game.task_progress("pull", n)
	Game.changed.emit("currency")
	Game.save()
	return {"ok": true, "results": results, "tickets_used": use_tickets, "diamonds_used": need_diamonds}


## 一次十连的费用描述。
static func cost_text(pool_id: String, n: int) -> String:
	var p := pool(pool_id)
	var ticket_kind := str(p.get("ticket", "standard"))
	var have := Game.tickets(ticket_kind)
	var use_tickets := mini(have, n)
	var need_diamonds := (n - use_tickets) * int(p.get("cost_diamonds", 150))
	var parts: Array = []
	if use_tickets > 0:
		parts.append("许愿券×%d" % use_tickets)
	if need_diamonds > 0:
		parts.append("钻石×%d" % need_diamonds)
	return " + ".join(parts)
