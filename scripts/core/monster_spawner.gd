extends Node2D
class_name MonsterSpawner

var monsters: Array = []
var spawn_clusters: Array = []
var boss: CentipedeBoss = null


func reset() -> void:
	for m in monsters:
		if is_instance_valid(m):
			m.queue_free()
	monsters.clear()
	spawn_clusters.clear()
	if is_instance_valid(boss):
		boss.queue_free()
	boss = null


func spawn_stage(stage_index: int, battle: Node) -> void:
	reset()
	var stage := GameConfig.get_stage(stage_index)
	if stage.is_empty():
		return
	var boss_id := str(stage.get("boss_id", ""))
	if boss_id == "centipede":
		_spawn_centipede_boss(battle, stage_index)
		return
	var counts := {
		"NORMAL": _scaled_count(int(stage.get("normal", 0)), stage_index, false),
		"ELITE": _scaled_count(int(stage.get("elite", 0)), stage_index, false),
		"SHIELD": _scaled_count(int(stage.get("shield", 0)), stage_index, true),
		"BERSERKER": _scaled_count(int(stage.get("berserker", 0)), stage_index, false),
		"SPLITTER": _scaled_count(int(stage.get("splitter", 0)), stage_index, false),
		"ARCHER": _scaled_count(int(stage.get("archer", 0)), stage_index, false),
		"FIRE_MAGE": _scaled_count(int(stage.get("fire_mage", 0)), stage_index, false),
	}
	_init_clusters(battle)
	for kind_id in counts.keys():
		for i in range(counts[kind_id]):
			_spawn_monster(kind_id, stage_index, battle)


func get_active_monsters() -> Array:
	if boss and is_instance_valid(boss) and boss.phase == CentipedeBoss.Phase.ACTIVE:
		return boss.get_active_segments()
	var result: Array = []
	for m in monsters:
		if _is_combat_targetable(m):
			result.append(m)
	return result


func unregister_monster(monster: Node) -> void:
	var idx := monsters.find(monster)
	if idx >= 0:
		monsters.remove_at(idx)


func _is_combat_targetable(m: Node) -> bool:
	if not is_instance_valid(m):
		return false
	if m.has_method("is_combat_targetable"):
		return m.is_combat_targetable()
	if m.get("alive") == false:
		return false
	if m.get("dying") == true:
		return false
	return true


func all_dead() -> bool:
	if boss and is_instance_valid(boss):
		return boss.is_defeated()
	return get_active_monsters().is_empty()


func _scaled_count(raw: int, stage_index: int, is_shield: bool) -> int:
	if raw <= 0:
		return 0
	var scale := float(GameConfig.get_tuning("stage_monster_scale", 1.3))
	var count_mul := float(GameConfig.get_tuning("stage_count_mul", 2.0 / 3.0))
	var shield_mul := float(GameConfig.get_tuning("shield_count_mul", 1.0 / 3.0))
	var value := float(raw) * pow(scale, stage_index) * count_mul
	if is_shield:
		value *= shield_mul
	return maxi(0, int(round(value)))


func _init_clusters(battle: Node) -> void:
	spawn_clusters.clear()
	var w := float(GameConfig.get_tuning("logical_width", 390))
	var h := float(GameConfig.get_tuning("logical_height", 700))
	var safe: Vector2 = battle.player.global_position if battle.player else Vector2(w * 0.5, h * 0.62)
	var min_player_dist := 140.0
	var cluster_count := randi_range(5, 9)
	for i in range(cluster_count):
		for attempt in range(80):
			var x := MathUtils.rand_range(26.0, w - 26.0)
			var y := MathUtils.rand_range(88.0, h - 120.0)
			if MathUtils.dist(Vector2(x, y), safe) < min_player_dist:
				continue
			var density := MathUtils.rand_range(0.3, 1.0)
			spawn_clusters.append({
				"x": x,
				"y": y,
				"radius": MathUtils.lerp_f(48.0, 92.0, density),
				"weight": 0.25 + density * density * 1.4,
			})
			break
	if spawn_clusters.is_empty():
		spawn_clusters.append({"x": w * 0.72, "y": h * 0.45, "radius": 80.0, "weight": 1.0})


func _pick_spawn_pos(battle: Node) -> Vector2:
	var w := float(GameConfig.get_tuning("logical_width", 390))
	var h := float(GameConfig.get_tuning("logical_height", 700))
	var safe: Vector2 = battle.player.global_position if battle.player else Vector2(w * 0.5, h * 0.62)
	for i in range(140):
		var pos := Vector2.ZERO
		if randf() < 0.74 and not spawn_clusters.is_empty():
			var cluster = _pick_weighted_cluster()
			var ang := MathUtils.rand_range(0.0, TAU)
			var rad := float(cluster.radius) * sqrt(randf())
			pos = Vector2(float(cluster.x), float(cluster.y)) + Vector2(cos(ang), sin(ang)) * rad
		else:
			pos = Vector2(MathUtils.rand_range(26.0, w - 26.0), MathUtils.rand_range(88.0, h - 120.0))
		if MathUtils.dist(pos, safe) < 140.0:
			continue
		var ok := true
		for m in get_active_monsters():
			if MathUtils.dist(pos, m.global_position) < 20.0:
				ok = false
				break
		if ok:
			return pos
	return Vector2(w * 0.72, h * 0.45)


func _pick_weighted_cluster() -> Dictionary:
	var total := 0.0
	for c in spawn_clusters:
		total += float(c.weight)
	var roll := randf() * total
	for c in spawn_clusters:
		roll -= float(c.weight)
		if roll <= 0.0:
			return c
	return spawn_clusters.back()


func _spawn_monster(kind_id: String, stage_index: int, battle: Node) -> void:
	var scene: PackedScene = load("res://scenes/entities/monster.tscn")
	var monster = scene.instantiate()
	battle.monster_container.add_child(monster)
	monster.setup(kind_id, stage_index, _pick_spawn_pos(battle))
	monster.begin_spawn()
	monsters.append(monster)


func spawn_split_children(parent: BattleMonster) -> Array:
	if parent == null or not parent.can_split():
		return []
	var battle_node = get_parent()
	if battle_node == null:
		return []
	parent.spawned_children = true
	var children: Array = []
	var scene: PackedScene = load("res://scenes/entities/monster.tscn")
	for i in range(parent.split_count):
		var ang := (float(i) / float(parent.split_count)) * TAU + MathUtils.rand_range(-0.25, 0.25)
		var dist := MathUtils.rand_range(12.0, 20.0)
		var pos := parent.global_position + Vector2(cos(ang), sin(ang)) * dist
		var child = scene.instantiate()
		battle_node.monster_container.add_child(child)
		child.setup("SPLITTER", parent.stage_index_cached, pos)
		child.split_tier = parent.split_tier + 1
		var child_scale := Vector2.ONE * maxf(0.55, 1.0 - child.split_tier * 0.12)
		child.scale = child_scale
		child.begin_spawn(-1.0, child_scale)
		monsters.append(child)
		children.append(child)
	return children


func _spawn_centipede_boss(battle: Node, stage_index: int) -> void:
	boss = CentipedeBoss.new()
	boss.setup(battle, stage_index)
	battle.monster_container.add_child(boss)


func update_boss(delta: float, player: BattlePlayer) -> void:
	if boss and is_instance_valid(boss):
		boss.update_boss(delta, player)
