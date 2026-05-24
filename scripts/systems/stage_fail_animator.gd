extends Node
class_name StageFailAnimator

var battle
var active := false
var frozen := false
var phase := "idle"
var timer := 0.0
var spears: Array = []
var impale_angles: Array = []
var death_shake := 0.0
var death_fall := 0.0
var death_alpha := 1.0
var on_complete: Callable
var _impact_spawned := false


func _tuning(key: String, default_value) -> float:
	return float(GameConfig.get_tuning(key, default_value))


func setup(battle_node) -> void:
	battle = battle_node


func is_active() -> bool:
	return active


func is_throwing() -> bool:
	return active and (phase == "windup" or phase == "throw")


func show_fail_pose() -> bool:
	return active or frozen


func reset() -> void:
	active = false
	frozen = false
	phase = "idle"
	timer = 0.0
	spears.clear()
	impale_angles.clear()
	death_shake = 0.0
	death_fall = 0.0
	death_alpha = 1.0
	_impact_spawned = false
	on_complete = Callable()
	if battle and battle.player:
		battle.player.clear_fail_death_visuals()


func start(finish_cb: Callable) -> void:
	reset()
	if battle == null or battle.player == null:
		if finish_cb.is_valid():
			finish_cb.call()
		return
	active = true
	frozen = false
	phase = "windup"
	timer = 0.0
	on_complete = finish_cb
	_impact_spawned = false
	impale_angles.clear()

	var player: BattlePlayer = battle.player
	var px := player.global_position
	var monsters: Array = battle.spawner.get_active_monsters() if battle.spawner else []
	var sources: Array = monsters if not monsters.is_empty() else [null]

	var idx := 0
	for m in sources:
		var from_pos := px + Vector2(randf_range(90.0, 160.0), randf_range(-120.0, -60.0))
		var monster_ref = m
		if m != null and is_instance_valid(m):
			from_pos = m.global_position
			if m is BattleMonster:
				m.fail_throw_timer = _tuning("fail_death_windup", 0.3) + 0.45
		var target := px + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
		var ang := (target - from_pos).angle()
		var dist := maxf(40.0, from_pos.distance_to(target))
		spears.append({
			"from": from_pos,
			"pos": from_pos,
			"target": target,
			"angle": ang,
			"delay": float(idx) * _tuning("fail_death_spear_stagger", 0.065),
			"progress": 0.0,
			"dist": dist,
			"landed": false,
			"monster": monster_ref,
		})
		idx += 1

	player.global_position = px
	player.state = BattlePlayer.State.IDLE
	player.begin_fail_death({"phase": "windup"})


func update(delta: float) -> void:
	if not active:
		return
	timer += delta * _tuning("fail_death_playback_speed", 2.0)
	_update_monster_throw_timers(delta)
	match phase:
		"windup":
			if timer >= _tuning("fail_death_windup", 0.3):
				phase = "throw"
				timer = 0.0
				if battle and battle.player:
					battle.player.set_fail_death_phase("throw")
		"throw":
			var pending := false
			for s in spears:
				if bool(s.landed):
					continue
				pending = true
				if timer < float(s.delay):
					continue
				var elapsed := timer - float(s.delay)
				var t := clampf((elapsed * _tuning("fail_death_spear_speed", 640.0)) / float(s.dist), 0.0, 1.0)
				s.progress = t
				s.pos = s.from.lerp(s.target, t * t)
				if t >= 1.0:
					s.landed = true
					s.pos = s.target
					impale_angles.append(float(s.angle) + PI + randf_range(-0.2, 0.2))
			if not pending:
				_begin_impact()
		"impact":
			var impact_pause := _tuning("fail_death_impact_pause", 0.24)
			death_shake = sin(timer * 48.0) * maxf(0.0, 1.0 - timer / impact_pause) * 8.0
			if timer >= impact_pause:
				phase = "death"
				timer = 0.0
				if battle and battle.player:
					battle.player.set_fail_death_phase("falling")
		"death":
			var death_dur := _tuning("fail_death_duration", 0.9)
			var t := clampf(timer / death_dur, 0.0, 1.0)
			death_fall = t * t
			death_alpha = 1.0 - t * 0.35
			death_shake *= 0.9
			if timer >= death_dur:
				_freeze()
				var cb := on_complete
				on_complete = Callable()
				if cb.is_valid():
					cb.call()
	_apply_player_visuals()


func _begin_impact() -> void:
	phase = "impact"
	timer = 0.0
	if battle and battle.player:
		battle.player.set_fail_death_phase("impaled")
	if _impact_spawned or battle == null or battle.player == null:
		return
	_impact_spawned = true
	var p: BattlePlayer = battle.player
	if battle.blood_stains:
		battle.blood_stains.spawn(p.global_position.x, p.global_position.y + 8.0, 1.5, 0.0)
	if battle.particles:
		battle.particles.death_effect(p.global_position, Color("#6a1818"))
	if battle.has_method("shake_camera"):
		battle.shake_camera(14.0, 0.35)


func _freeze() -> void:
	frozen = true
	active = false
	phase = "done"
	death_fall = 1.0
	death_shake = 0.0
	death_alpha = death_alpha if death_alpha > 0.0 else 0.65
	if battle and battle.player:
		battle.player.begin_fail_death({"phase": "done", "frozen": true})
	_apply_player_visuals()


func _apply_player_visuals() -> void:
	if battle == null or battle.player == null:
		return
	if show_fail_pose():
		battle.player.apply_fail_death_visuals(death_shake, death_fall, death_alpha)


func _update_monster_throw_timers(delta: float) -> void:
	if battle == null or battle.spawner == null:
		return
	for m in battle.spawner.monsters:
		if is_instance_valid(m) and m is BattleMonster and m.fail_throw_timer > 0.0:
			m.fail_throw_timer -= delta


func draw_flying_spears(canvas: Node2D) -> void:
	if not active or phase == "impact" or phase == "death":
		return
	for s in spears:
		if bool(s.landed):
			continue
		if phase == "windup" or timer < float(s.delay):
			continue
		draw_spear(canvas, s.pos - canvas.global_position, float(s.angle), false)


static func draw_spear(canvas: CanvasItem, pos: Vector2, ang: float, stuck: bool) -> void:
	var length := 22.0 if stuck else 18.0
	canvas.draw_set_transform(pos, ang, Vector2.ONE)
	canvas.draw_rect(Rect2(-length * 0.55, -1.5, length * 0.72, 3.0), Color("#5a4030"))
	canvas.draw_rect(Rect2(length * 0.08, -1.0, length * 0.28, 2.0), Color("#8a7060"))
	var tip := PackedVector2Array([
		Vector2(length * 0.38, 0.0),
		Vector2(length * 0.55, -3.0),
		Vector2(length * 0.55, 3.0),
	])
	canvas.draw_colored_polygon(tip, Color("#c8ccd4"))
	if stuck:
		canvas.draw_rect(Rect2(-length * 0.08, -2.5, 5.0, 5.0), Color("#8a1818"))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func draw_monster_throw_spear(canvas: CanvasItem, monster: BattleMonster, player_pos: Vector2) -> void:
	if monster.fail_throw_timer <= 0.0:
		return
	var local := monster.to_local(player_pos)
	var ang := local.angle()
	var reach := monster.get_hitbox_radius() + 10.0
	var spear_pos := Vector2(cos(ang), sin(ang)) * reach
	draw_spear(canvas, spear_pos, ang, false)
