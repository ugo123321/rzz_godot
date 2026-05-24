extends Node
class_name UpgradeManager

var active := false
var choices: Array = []
var rolled_rarity := "blue"
var popup_timer := 0.0
var popup_duration := 0.45


func generate_choices(player: Node) -> void:
	active = true
	popup_timer = 0.0
	choices.clear()
	rolled_rarity = _roll_rarity()
	var pool: Array = []
	for u in GameConfig.upgrades:
		if str(u.get("rarity", "")) == rolled_rarity:
			pool.append(u)
	if pool.is_empty():
		pool = GameConfig.upgrades.duplicate()
	var available := pool.duplicate()
	for i in range(3):
		if available.is_empty():
			choices.append(MathUtils.pick_random(pool))
		else:
			var idx := randi() % available.size()
			choices.append(available[idx])
			available.remove_at(idx)


func update(delta: float) -> void:
	if active and popup_timer < popup_duration:
		popup_timer += delta


func can_interact() -> bool:
	return active and popup_timer / popup_duration >= 0.55


func select_upgrade(index: int, player: Node) -> Dictionary:
	if not can_interact() or index < 0 or index >= choices.size():
		return {}
	var upgrade: Dictionary = choices[index]
	player.apply_upgrade(upgrade)
	active = false
	choices.clear()
	EventBus.upgrade_selected.emit(str(upgrade.get("id", "")))
	return upgrade


func _roll_rarity() -> String:
	var r := randf()
	var acc := 0.0
	for key in ["blue", "purple", "orange"]:
		var fx := GameConfig.get_upgrade_fx(key)
		acc += float(fx.get("chance", 0.0))
		if r <= acc:
			return key
	return "blue"
