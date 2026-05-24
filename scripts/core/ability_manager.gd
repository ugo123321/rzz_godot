extends Node
class_name AbilityManager

const EffectHelperScript = preload("res://scripts/utils/effect_helper.gd")
const FX_SCALE := 1.75
const PROJ_DRAW_SCALE := 0.72
const AUTO_FIREBALL_DRAW_SCALE := 0.78
const AUTO_DART_SPAWN_OFFSET := 18.0
const AUTO_DART_FAN_SPREAD := 0.16
const AUTO_HIT_VISUAL_PAD := 10.0
const AUTO_HIT_FX_SCALE := 1.0
const HIT_FX_DRAW_SCALE := 0.62
const SHURIKEN_PIXEL := 5
const SHURIKEN_PIXELS: Array = [
	[null, "#7a8aa8", null, "#7a8aa8", null],
	["#7a8aa8", "#e8f4ff", "#b8cce8", "#e8f4ff", "#7a8aa8"],
	[null, "#b8cce8", "#586878", "#b8cce8", null],
	["#7a8aa8", "#e8f4ff", "#b8cce8", "#e8f4ff", "#7a8aa8"],
	[null, "#7a8aa8", null, "#7a8aa8", null],
]

var battle
var _dart_frames: SpriteFrames
var _auto_fireball_frames: SpriteFrames
var _ice_dart_frames: SpriteFrames
var _spirit_frames: SpriteFrames
var _fireball_frames: SpriteFrames
var _tornado_frames: SpriteFrames
var _black_hole_frames: SpriteFrames
var _whirl_frames: SpriteFrames
var _lightning_frames: SpriteFrames
var _smoke_hit_frames: SpriteFrames
var shurikens: Array = []
var hit_fx: Array = []
var lightning_fx: Array = []
var water_tornados: Array = []
var black_holes: Array = []
var whirls: Array = []
var auto_dart_cooldown := 0.0
var black_hole_spawned_this_resolve := false
var healing_combo_milestone := 0
var combo_fireball_milestone := 0
var bat_swarms: Array = []
var _auto_dart_release_connected := false


func setup(battle_node) -> void:
	battle = battle_node
	_load_projectile_frames()
	_connect_auto_dart_release()


func _connect_auto_dart_release() -> void:
	if battle == null or battle.player == null or _auto_dart_release_connected:
		return
	if not battle.player.auto_dart_released.is_connected(_on_auto_dart_released):
		battle.player.auto_dart_released.connect(_on_auto_dart_released)
	_auto_dart_release_connected = true


func _load_projectile_frames() -> void:
	_dart_frames = EffectHelperScript.build_projectile_frames("dart")
	_auto_fireball_frames = EffectHelperScript.build_projectile_frames("fire_missile")
	_ice_dart_frames = EffectHelperScript.build_projectile_frames("ice")
	_spirit_frames = EffectHelperScript.build_projectile_frames("spirit_bomb")
	_fireball_frames = EffectHelperScript.build_projectile_frames("fireball")
	_tornado_frames = EffectHelperScript.build_projectile_frames("tornado")
	_black_hole_frames = EffectHelperScript.build_projectile_frames("black_hole")
	_whirl_frames = EffectHelperScript.build_projectile_frames("whirl")
	_lightning_frames = EffectHelperScript.build_projectile_frames("lightning")
	_smoke_hit_frames = EffectHelperScript.build_effect_frames("smoke_hit")


func _skill_burst(pos: Vector2, shake_mag: float, shake_dur: float, color: Color, count: int = 14) -> void:
	if battle == null:
		return
	battle.shake_camera(shake_mag * FX_SCALE, shake_dur)
	if battle.particles == null:
		return
	for i in range(count):
		var a := randf() * TAU
		var speed := randf_range(90.0, 240.0) * FX_SCALE
		battle.particles.emit_particle(
			pos.x, pos.y,
			cos(a) * speed, sin(a) * speed,
			randf_range(0.18, 0.42), randf_range(5.0, 11.0) * FX_SCALE,
			color, randf_range(60.0, 120.0), true, true
		)


func _draw_water_tornado(canvas: Node2D, t: Dictionary, life_t: float) -> void:
	if _tornado_frames == null or _tornado_frames.get_frame_count(EffectHelperScript.ANIM_PREVIEW) <= 0:
		return
	var tex := EffectHelperScript.animation_frame_texture(_tornado_frames, float(t.get("anim_t", 0.0)))
	if tex == null:
		return
	var alpha := 0.55 + life_t * 0.45
	var size := tex.get_size()
	var draw_r := 60.0 * FX_SCALE
	var draw_scale := (draw_r * 2.2) / maxf(size.x, size.y)
	var draw_size := size * draw_scale
	var local_pos: Vector2 = Vector2(t.pos) - canvas.global_position
	SpriteHelper.draw_effect_texture_rect(
		canvas,
		tex,
		Rect2(local_pos - draw_size * 0.5, draw_size),
		Color(1.0, 1.0, 1.0, alpha)
	)


func _draw_sprite_fx(
	canvas: Node2D,
	world_pos: Vector2,
	rot: float,
	spin: float,
	frames: SpriteFrames,
	scale_mul: float,
	alpha: float = 1.0
) -> void:
	if frames == null or frames.get_frame_count(EffectHelperScript.ANIM_PREVIEW) <= 0:
		return
	var tex := EffectHelperScript.projectile_frame_texture(frames, spin)
	if tex == null:
		return
	var draw_scale := PROJ_DRAW_SCALE * scale_mul * FX_SCALE
	var local_pos: Vector2 = world_pos - canvas.global_position
	SpriteHelper.draw_effect_texture(
		canvas,
		tex,
		local_pos,
		rot,
		Vector2.ONE * draw_scale,
		Color(1.0, 1.0, 1.0, alpha)
	)


func reset() -> void:
	shurikens.clear()
	hit_fx.clear()
	lightning_fx.clear()
	water_tornados.clear()
	black_holes.clear()
	whirls.clear()
	auto_dart_cooldown = 0.0
	black_hole_spawned_this_resolve = false
	healing_combo_milestone = 0
	combo_fireball_milestone = 0
	bat_swarms.clear()


func on_resolve_started() -> void:
	black_hole_spawned_this_resolve = false
	healing_combo_milestone = 0
	combo_fireball_milestone = 0
	if battle and battle.player:
		battle.player.water_tornado_charge = 0
		battle.player.whirl_charge = 0


func has_active_fx() -> bool:
	return not shurikens.is_empty() or not hit_fx.is_empty() or not water_tornados.is_empty() or not black_holes.is_empty() or not whirls.is_empty() or not bat_swarms.is_empty()


func update(delta: float, player: BattlePlayer, monsters: Array) -> void:
	if player == null:
		return
	_update_auto_darts(delta, player, monsters)
	_update_shurikens(delta, player, monsters)
	_update_hit_fx(delta)
	_update_water_tornados(delta, player, monsters)
	_update_black_holes(delta, player, monsters)
	_update_whirls(delta, player, monsters)
	_update_lightning_fx(delta)
	_update_bat_swarms(delta, player)


func spawn_vampire_bat_swarm(from_pos: Vector2, player: BattlePlayer) -> void:
	var lv := player.get_upgrade_level("vampire_bat")
	if lv <= 0 or battle == null or battle.spawner == null:
		return
	var radius := 130.0 + float(lv) * 12.0
	var monsters: Array = []
	for m in battle.spawner.get_active_monsters():
		if not is_instance_valid(m) or m.get("alive") == false:
			continue
		var hit_r := 13.0
		if m.has_method("get_hitbox_radius"):
			hit_r = m.get_hitbox_radius()
		if from_pos.distance_to(m.global_position) <= radius + hit_r:
			monsters.append(m)
	monsters.sort_custom(func(a, b): return from_pos.distance_to(a.global_position) < from_pos.distance_to(b.global_position))
	var max_targets := mini(monsters.size(), 4 + lv * 2)
	var targets: Array = monsters.slice(0, max_targets)
	bat_swarms.append({
		"origin": from_pos,
		"targets": targets,
		"idx": 0,
		"phase": "orbit",
		"timer": 0.0,
		"orbit_elapsed": 0.0,
		"orbit_duration": 0.95,
		"return_elapsed": 0.0,
		"return_duration": 0.55,
		"step_delay": 0.06,
		"damage": player.get_ability_damage(0.14),
		"heal_amount": int(round(float(player.max_hp) * 0.02 * float(lv))),
		"bat_count": 10 + lv * 2,
	})
	_skill_burst(from_pos, 7.0, 0.18, Color("#8060c8"), 22)


func _update_bat_swarms(delta: float, player: BattlePlayer) -> void:
	if player == null or battle == null:
		return
	for i in range(bat_swarms.size() - 1, -1, -1):
		var swarm = bat_swarms[i]
		match str(swarm.phase):
			"orbit":
				swarm.orbit_elapsed = float(swarm.orbit_elapsed) + delta
				if float(swarm.orbit_elapsed) < float(swarm.orbit_duration):
					continue
				var targets: Array = swarm.targets
				if targets.is_empty():
					swarm.phase = "return"
					swarm.return_elapsed = 0.0
				else:
					swarm.phase = "attack"
					swarm.idx = 0
					swarm.timer = 0.0
			"return":
				swarm.return_elapsed = float(swarm.return_elapsed) + delta
				if float(swarm.return_elapsed) < float(swarm.return_duration):
					continue
				var healed := mini(int(swarm.heal_amount), player.max_hp - player.hp)
				if healed > 0:
					player.hp += healed
					EventBus.player_healed.emit(healed, player.hp)
					if battle.combat:
						battle.combat.spawn_damage_number(
							player.global_position + Vector2(0, -player.get_effective_radius() - 12),
							healed, false, true
						)
				swarm.phase = "done"
			"attack":
				swarm["timer"] = float(swarm.get("timer", 0.0)) - delta
				if float(swarm.get("timer", 0.0)) > 0.0:
					continue
				var targets_arr: Array = swarm.targets
				if int(swarm.idx) >= targets_arr.size():
					swarm.phase = "return"
					swarm.return_elapsed = 0.0
					continue
				var m = targets_arr[int(swarm.idx)]
				if is_instance_valid(m) and m.get("alive") != false:
					var from_pos := player.global_position
					if battle.particles:
						battle.particles.emit_particle(
							from_pos.x, from_pos.y,
							(m.global_position.x - from_pos.x) * 3.0,
							(m.global_position.y - from_pos.y) * 3.0,
							0.1, 4.0, Color("#503070"), 0.0, true, false
						)
					if m.has_method("take_damage"):
						var result: Dictionary = m.take_damage(int(swarm.get("damage", 0)), from_pos)
						if battle.combat and int(result.get("damage", 0)) > 0:
							battle.combat.spawn_damage_number(m.global_position, int(result.get("damage", 0)), false)
							if battle.particles:
								battle.particles.hit_spark(m.global_position, false)
						if bool(result.get("started_dying", false)):
							EventBus.monster_killed.emit(m)
				swarm.idx = int(swarm.idx) + 1
				swarm.timer = float(swarm.step_delay)
		if str(swarm.phase) == "done":
			bat_swarms.remove_at(i)


func _draw_bat(canvas: Node2D, pos: Vector2, wing_phase: float) -> void:
	var offset := -canvas.global_position
	var s := FX_SCALE
	var bx: float = floor(pos.x)
	var by: float = floor(pos.y)
	var flap := sin(wing_phase) > 0.0
	canvas.draw_rect(Rect2(Vector2(bx - 4 * s, by) + offset, Vector2(8 * s, 3 * s)), Color("#281838"))
	if flap:
		canvas.draw_rect(Rect2(Vector2(bx - 6 * s, by - 4 * s) + offset, Vector2(4 * s, 3 * s)), Color("#6040a0"))
		canvas.draw_rect(Rect2(Vector2(bx + 2 * s, by - 4 * s) + offset, Vector2(4 * s, 3 * s)), Color("#6040a0"))
	else:
		canvas.draw_rect(Rect2(Vector2(bx - 7 * s, by - 1 * s) + offset, Vector2(3 * s, 2 * s)), Color("#6040a0"))
		canvas.draw_rect(Rect2(Vector2(bx + 4 * s, by - 1 * s) + offset, Vector2(3 * s, 2 * s)), Color("#6040a0"))
	canvas.draw_rect(Rect2(Vector2(bx - 1 * s, by - 1 * s) + offset, Vector2(2 * s, 2 * s)), Color("#c8a8e8"))


func _draw_bats_around_player(canvas: Node2D, swarm: Dictionary, player: BattlePlayer) -> void:
	var t := Time.get_ticks_msec() * 0.014
	var count := int(swarm.get("bat_count", 10))
	var base_r := (player.get_effective_radius() + 22.0) * FX_SCALE
	var cx := player.global_position.x
	var cy := player.global_position.y
	for i in range(count):
		var a := t * 1.35 + (float(i) / float(count)) * TAU
		var wobble := sin(t * 2.2 + float(i) * 0.7) * 8.0
		var layer := (i % 3) * 4
		var r := base_r + wobble + float(layer)
		_draw_bat(canvas, Vector2(cx + cos(a) * r, cy + sin(a) * r * 0.82), t * 3.0 + float(i))


func _draw_bat_swarm(canvas: Node2D, swarm: Dictionary, player: BattlePlayer) -> void:
	if player == null:
		return
	var phase := str(swarm.phase)
	if phase in ["orbit", "return"]:
		_draw_bats_around_player(canvas, swarm, player)
		return
	if phase == "attack":
		var t := Time.get_ticks_msec() * 0.018
		var count := mini(int(swarm.get("bat_count", 8)), 8)
		var targets: Array = swarm.targets
		if targets.is_empty():
			_draw_bats_around_player(canvas, swarm, player)
			return
		var target_idx := clampi(int(swarm.idx), 0, targets.size() - 1)
		var target = targets[target_idx]
		if not is_instance_valid(target):
			_draw_bats_around_player(canvas, swarm, player)
			return
		for i in range(count):
			var prog := (float(swarm.idx) + float(i) * 0.08) / maxf(1.0, float(targets.size()))
			var a := t + (float(i) / float(count)) * TAU
			var cx := lerpf(player.global_position.x, target.global_position.x, 0.35 + prog * 0.5) + cos(a) * 12.0
			var cy := lerpf(player.global_position.y, target.global_position.y, 0.35 + prog * 0.5) + sin(a) * 10.0
			_draw_bat(canvas, Vector2(cx, cy), t * 2.0 + float(i))
		_draw_bats_around_player(canvas, swarm, player)


func on_combo_hit(combo: float, hit_pos: Vector2, seg_ang: float, player: BattlePlayer) -> void:
	if player == null or battle == null or not battle.combat.is_resolving():
		return
	var combo_floor := int(floor(combo))

	if player.get_upgrade_level("shuriken") > 0 and combo_floor > 0:
		_spawn_combo_shurikens(hit_pos, seg_ang)

	var fire_milestone := int(floor(combo_floor / 10.0)) * 10
	if player.get_upgrade_level("great_fireball") > 0 and fire_milestone >= 10 and fire_milestone > combo_fireball_milestone:
		combo_fireball_milestone = fire_milestone
		_spawn_combo_fireballs(hit_pos, seg_ang, player)

	var heal_milestone := int(floor(combo_floor / 15.0)) * 15
	if player.get_upgrade_level("healing_combo") > 0 and heal_milestone >= 15 and heal_milestone > healing_combo_milestone:
		healing_combo_milestone = heal_milestone
		player.heal_percent(0.05)
		_skill_burst(hit_pos, 5.0, 0.14, Color("#68e878"), 16)

	if player.get_upgrade_level("lightning_chain") > 0 and combo_floor > 0 and combo_floor % 5 == 0:
		var monsters: Array = battle.spawner.get_active_monsters() if battle and battle.spawner else []
		_spawn_lightning_chain(hit_pos, player, monsters)

	if player.get_upgrade_level("water_tornado") > 0:
		player.water_tornado_charge += 1
		while player.water_tornado_charge >= 3:
			player.water_tornado_charge -= 3
			var cnt := player.get_upgrade_level("water_tornado")
			for i in range(cnt):
				_spawn_water_tornado(hit_pos, seg_ang, player, i, cnt)

	if player.get_upgrade_level("black_hole") > 0 and combo_floor == 8 and not black_hole_spawned_this_resolve:
		_spawn_black_hole(hit_pos, player)
		black_hole_spawned_this_resolve = true

	if player.get_upgrade_level("blade_whirl") > 0:
		player.whirl_charge += 1
		while player.whirl_charge >= 5:
			player.whirl_charge -= 5
			_spawn_whirl(hit_pos, player)


func _find_nearest_monster(from_pos: Vector2, monsters: Array):
	var nearest = null
	var nearest_dist := INF
	for m in monsters:
		if not is_instance_valid(m) or m.get("alive") == false:
			continue
		var d := from_pos.distance_to(m.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = m
	return nearest


func _nearest_monster_angle(from_pos: Vector2, fallback_ang: float, monsters: Array) -> float:
	var nearest = _find_nearest_monster(from_pos, monsters)
	if nearest == null:
		return fallback_ang
	var to_monster: Vector2 = nearest.global_position - from_pos
	if to_monster.length_squared() < 4.0:
		return fallback_ang
	return to_monster.angle()


func fire_auto_darts(player: BattlePlayer, monsters: Array) -> void:
	_spawn_auto_dart_volley(player, monsters)


func _spawn_auto_dart_volley(player: BattlePlayer, monsters: Array) -> void:
	if player == null or monsters.is_empty():
		return
	var base_ang := _nearest_monster_angle(player.global_position, -PI * 0.5, monsters)
	var dmg := player.get_auto_dart_damage()
	var is_spirit := player.has_spirit_bomb()
	var count := maxi(1, player.dart_count)
	for i in range(count):
		var ang := base_ang
		if count > 1:
			ang = base_ang + (float(i) - (count - 1) * 0.5) * AUTO_DART_FAN_SPREAD
		_spawn_dart_from_angle(player, ang, dmg, is_spirit, 1.0, false)
	_try_spawn_giant_darts(player, base_ang, dmg)


func _on_auto_dart_released() -> void:
	if battle == null or battle.player == null or battle.spawner == null:
		return
	_spawn_auto_dart_volley(battle.player, battle.spawner.get_active_monsters())


func _try_spawn_giant_darts(player: BattlePlayer, base_ang: float, normal_dmg: int) -> void:
	var lv := player.get_upgrade_level("giant_dart")
	if lv <= 0 or randf() >= 0.20:
		return
	var giant_dmg := maxi(1, normal_dmg * 2)
	for i in range(lv):
		var ang := base_ang + (float(i) - (lv - 1) * 0.5) * 0.14 if lv > 1 else base_ang
		_spawn_dart_from_angle(player, ang, giant_dmg, false, 2.0, true)


func _get_ice_dart_proc_chance(player: BattlePlayer) -> float:
	var lv := player.get_upgrade_level("ice_dart")
	if lv <= 0:
		return 0.0
	return minf(0.95, 0.05 + 0.04 * float(maxi(0, lv - 1)))


func _try_spawn_ice_dart(player: BattlePlayer, pos: Vector2, dart_damage: int, fly_ang: float) -> void:
	if player.get_upgrade_level("ice_dart") <= 0:
		return
	if randf() >= _get_ice_dart_proc_chance(player):
		return
	shurikens.append({
		"kind": "ice",
		"pos": pos,
		"vel": Vector2(cos(fly_ang), sin(fly_ang)) * 340.0,
		"life": 0.9,
		"damage": dart_damage,
		"hit": {},
		"rot": fly_ang,
		"spin": 16.0,
		"dmg_mul": 1.0,
		"freeze_dur": 2.0,
	})


func _update_auto_darts(delta: float, player: BattlePlayer, monsters: Array) -> void:
	if player.state != BattlePlayer.State.IDLE:
		return
	if player.dart_count <= 0:
		return
	if monsters.is_empty():
		return
	_connect_auto_dart_release()
	auto_dart_cooldown -= delta
	if auto_dart_cooldown > 0.0:
		return
	if not player.begin_auto_dart_cycle():
		return
	auto_dart_cooldown = player.get_auto_dart_cycle_interval()


func _spawn_dart_from_angle(player: BattlePlayer, ang: float, damage: int, is_spirit: bool, visual_scale: float, is_giant: bool) -> void:
	var dir := Vector2(cos(ang), sin(ang))
	var spawn_pos := player.global_position + dir * (player.get_effective_radius() + AUTO_DART_SPAWN_OFFSET)
	shurikens.append({
		"kind": "auto",
		"pos": spawn_pos,
		"vel": dir * float(GameConfig.get_player_value("auto_dart_speed", 420)),
		"life": float(GameConfig.get_player_value("auto_dart_life", 0.9)),
		"max_life": float(GameConfig.get_player_value("auto_dart_life", 0.9)),
		"damage": damage,
		"hit": {},
		"rot": ang,
		"anim_t": 0.0,
		"visual_scale": visual_scale,
		"is_spirit": is_spirit,
		"is_giant": is_giant,
	})
	_finalize_spawned_projectile(shurikens.back(), player)


func _spawn_combo_shurikens(pos: Vector2, seg_ang: float) -> void:
	for i in range(2):
		var spread := seg_ang + MathUtils.rand_range(-0.55, 0.55)
		var spd := MathUtils.rand_range(340.0, 500.0)
		shurikens.append({
			"kind": "skill",
			"pos": pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"vel": Vector2(cos(spread), sin(spread)) * spd,
			"life": MathUtils.rand_range(0.42, 0.62),
			"damage": 0,
			"hit": {},
			"rot": randf() * TAU,
			"spin": MathUtils.rand_range(10.0, 18.0),
			"dmg_mul": 0.10,
			"visual_scale": 1.35,
		})
	_skill_burst(pos, 4.5, 0.1, Color("#b8cce8"), 8)


func _spawn_combo_fireballs(pos: Vector2, seg_ang: float, player: BattlePlayer) -> void:
	var lv := player.get_upgrade_level("great_fireball")
	var cnt := 3 + maxi(0, lv - 1)
	for i in range(cnt):
		var a := seg_ang + MathUtils.rand_range(-0.9, 0.9)
		shurikens.append({
			"kind": "fireball",
			"pos": pos,
			"vel": Vector2(cos(a), sin(a)) * 280.0,
			"life": 0.95,
			"damage": 0,
			"hit": {},
			"rot": a,
			"spin": 0.0,
			"dmg_mul": 1.0,
			"visual_scale": 1.5,
		})
	_skill_burst(pos, 6.5, 0.16, Color("#ff7020"), 18)


func _spawn_water_tornado(pos: Vector2, seg_ang: float, player: BattlePlayer, idx: int, total: int) -> void:
	var lv := player.get_upgrade_level("water_tornado")
	var spread := 0.0 if total <= 1 else (float(idx) - (total - 1) * 0.5) * 0.22
	var monsters: Array = battle.spawner.get_active_monsters() if battle and battle.spawner else []
	var ang := _nearest_monster_angle(pos, seg_ang, monsters) + spread
	water_tornados.append({
		"kind": "water_tornado",
		"pos": pos,
		"vel": Vector2(cos(ang), sin(ang)) * 360.0,
		"life": 1.85,
		"max_life": 1.85,
		"anim_t": 0.0,
		"hit": {},
		"dmg_mul": 0.55 + 0.1 * float(lv),
	})
	_skill_burst(pos, 5.5, 0.14, Color("#58d8ff"), 14)


func _spawn_black_hole(pos: Vector2, player: BattlePlayer) -> void:
	var lv := player.get_upgrade_level("black_hole")
	black_holes.append({
		"kind": "black_hole",
		"pos": pos,
		"radius": (82.0 + float(lv) * 24.0) * FX_SCALE,
		"life": 1.9,
		"max_life": 1.9,
		"pull": 220.0 + float(lv) * 65.0,
		"dmg_timer": 0.0,
		"hit": {},
		"dmg_mul": 0.45 + 0.08 * float(lv),
	})
	_skill_burst(pos, 8.0, 0.2, Color("#9040d8"), 20)


func _spawn_whirl(pos: Vector2, player: BattlePlayer) -> void:
	var lv := player.get_upgrade_level("blade_whirl")
	var base_r := (68.0 + float(lv) * 8.0) * 1.12 * FX_SCALE
	whirls.append({
		"kind": "whirl",
		"pos": pos,
		"radius": base_r * 0.55,
		"max_radius": base_r,
		"life": 0.9,
		"max_life": 0.9,
		"spin": randf() * TAU,
		"spin_speed": 16.0 + float(lv) * 2.5,
		"hit": {},
		"dmg_mul": 0.35 + float(lv) * 0.12,
	})
	_skill_burst(pos, 6.0, 0.15, Color("#ffe060"), 16)


func _spawn_lightning_chain(from_pos: Vector2, player: BattlePlayer, monsters: Array) -> void:
	_skill_burst(from_pos, 7.5, 0.17, Color("#a8e8ff"), 12)
	var targets: Array = []
	for m in monsters:
		if is_instance_valid(m) and m.get("alive") != false:
			targets.append(m)
	targets.sort_custom(func(a, b): return from_pos.distance_to(a.global_position) < from_pos.distance_to(b.global_position))
	var chain_count := mini(3 + player.get_upgrade_level("lightning_chain"), targets.size())
	var dmg := int(max(1, round(player.base_attack * player.attack_power_scale * 0.6)))
	for i in range(chain_count):
		var m = targets[i]
		if m.has_method("take_damage"):
			var result: Dictionary = m.take_damage(dmg, from_pos)
			if battle and battle.combat:
				battle.combat.spawn_damage_number(m.global_position, int(result.get("damage", 0)), false)
			if bool(result.get("started_dying", false)):
				EventBus.monster_killed.emit(m)
		lightning_fx.append({
			"from": from_pos if i == 0 else targets[i - 1].global_position,
			"to": m.global_position,
			"life": 0.5,
		})
		from_pos = m.global_position


func _projectile_kind(s: Dictionary) -> String:
	return str(s.get("kind", ""))


func _projectile_hit_distance(s: Dictionary, m) -> float:
	var hit_r := 16.0
	if m.has_method("get_hitbox_radius"):
		hit_r = m.get_hitbox_radius()
	var pad := 8.0
	if _projectile_kind(s) == "auto":
		pad = AUTO_HIT_VISUAL_PAD
	return hit_r + pad


func _try_projectile_collision(s: Dictionary, player: BattlePlayer, monsters: Array) -> bool:
	for m in monsters:
		if not is_instance_valid(m) or m.get("alive") == false:
			continue
		_apply_projectile_hit(s, m, player)
		if s.get("hit", {}).has(str(m.get_instance_id())) and _projectile_kind(s) in ["auto", "ice", "skill", "fireball"]:
			return true
	return false


func _finalize_spawned_projectile(s: Dictionary, player: BattlePlayer) -> void:
	if battle == null or battle.spawner == null:
		return
	# 普攻火球从主角前方飞出后再参与碰撞，避免出生即必中。
	if _projectile_kind(s) == "auto":
		return
	var monsters: Array = battle.spawner.get_active_monsters()
	if _try_projectile_collision(s, player, monsters):
		var idx := shurikens.size() - 1
		if idx >= 0 and shurikens[idx] == s:
			shurikens.remove_at(idx)
	else:
		shurikens[shurikens.size() - 1] = s


func _apply_projectile_hit(s: Dictionary, m, player: BattlePlayer) -> void:
	var key := str(m.get_instance_id())
	var hit: Dictionary = s.get("hit", {})
	if hit.has(key):
		return
	var pos: Vector2 = s.get("pos", Vector2.ZERO)
	if pos.distance_to(m.global_position) > _projectile_hit_distance(s, m):
		return
	hit[key] = true
	s["hit"] = hit
	var dmg := int(s.get("damage", 0))
	if dmg <= 0:
		var mul := float(s.get("dmg_mul", 0.35))
		dmg = int(max(1, round(player.base_attack * player.attack_power_scale * mul)))
	var kind := _projectile_kind(s)
	if m.has_method("take_damage"):
		var result: Dictionary = m.take_damage(dmg, pos)
		if battle and battle.combat:
			battle.combat.spawn_damage_number(m.global_position, int(result.get("damage", 0)), false)
		if kind == "auto" and player.get_upgrade_level("ice_dart") > 0:
			_try_spawn_ice_dart(player, pos, dmg, float(s.get("rot", 0.0)))
		if kind == "auto":
			var fx_scale := float(s.get("visual_scale", 1.0))
			if bool(s.get("is_giant", false)):
				fx_scale *= 1.35
			_spawn_auto_hit_fx(m, fx_scale)
		if kind == "ice" and m is BattleMonster:
			m.freeze(float(s.get("freeze_dur", 2.0)))
		if bool(result.get("started_dying", false)):
			EventBus.monster_killed.emit(m)


func _update_shurikens(delta: float, player: BattlePlayer, monsters: Array) -> void:
	var i := shurikens.size() - 1
	while i >= 0:
		var s: Dictionary = shurikens[i]
		var remove: bool = float(s.life) <= 0.0 or battle == null or not battle.is_in_bounds(s.get("pos", Vector2.ZERO))
		if not remove and _try_projectile_collision(s, player, monsters):
			remove = true
		if not remove:
			s["pos"] = s.pos + s.vel * delta
			s["life"] = float(s.life) - delta
			if _projectile_kind(s) == "auto":
				s["anim_t"] = float(s.get("anim_t", 0.0)) + delta
			else:
				s["rot"] = float(s.rot) + float(s.get("spin", 0.0)) * delta
			remove = float(s.life) <= 0.0 or battle == null or not battle.is_in_bounds(s.get("pos", Vector2.ZERO))
			if not remove and _try_projectile_collision(s, player, monsters):
				remove = true
		if remove:
			shurikens.remove_at(i)
		else:
			shurikens[i] = s
		i -= 1


func _spawn_auto_hit_fx(target: Node2D, scale_mul: float = 1.0) -> void:
	if _smoke_hit_frames == null or _smoke_hit_frames.get_frame_count(EffectHelperScript.ANIM_PREVIEW) <= 0:
		return
	if target == null or not is_instance_valid(target):
		return
	hit_fx.append({
		"target": target,
		"pos": _hit_fx_center_pos(target),
		"anim_t": 0.0,
		"duration": EffectHelperScript.one_shot_anim_duration(_smoke_hit_frames),
		"scale": AUTO_HIT_FX_SCALE * scale_mul,
	})


func _hit_fx_center_pos(target: Variant) -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	if target is Node2D:
		return target.global_position
	return Vector2.ZERO


func _update_hit_fx(delta: float) -> void:
	for i in range(hit_fx.size() - 1, -1, -1):
		var fx: Dictionary = hit_fx[i]
		fx["anim_t"] = float(fx.anim_t) + delta
		var target = fx.get("target")
		if target != null and is_instance_valid(target):
			fx["pos"] = _hit_fx_center_pos(target)
		if float(fx.anim_t) >= float(fx.duration):
			hit_fx.remove_at(i)
		else:
			hit_fx[i] = fx


func draw_hit_fx(canvas: Node2D) -> void:
	if _smoke_hit_frames == null:
		return
	for fx in hit_fx:
		var tex := EffectHelperScript.animation_frame_texture_once(_smoke_hit_frames, float(fx.anim_t))
		if tex == null:
			continue
		var life_t := clampf(float(fx.anim_t) / maxf(0.001, float(fx.duration)), 0.0, 1.0)
		var alpha := 0.95 - life_t * 0.35
		var draw_scale := HIT_FX_DRAW_SCALE * float(fx.scale)
		var center_global: Vector2 = fx.get("pos", Vector2.ZERO)
		var target = fx.get("target")
		if target != null and is_instance_valid(target):
			center_global = _hit_fx_center_pos(target)
		var local_center: Vector2 = center_global - canvas.global_position
		SpriteHelper.draw_effect_texture(
			canvas,
			tex,
			local_center,
			0.0,
			Vector2.ONE * draw_scale,
			Color(1.0, 0.92, 0.82, alpha)
		)


func _update_water_tornados(delta: float, player: BattlePlayer, monsters: Array) -> void:
	for i in range(water_tornados.size() - 1, -1, -1):
		var t = water_tornados[i]
		t["pos"] = Vector2(t.pos) + Vector2(t.vel) * delta
		t["life"] = float(t.life) - delta
		t["anim_t"] = float(t.get("anim_t", 0.0)) + delta
		if float(t.life) <= 0.0:
			water_tornados.remove_at(i)
			continue
		for m in monsters:
			if not is_instance_valid(m) or m.get("alive") == false:
				continue
			_apply_projectile_hit(t, m, player)


func _update_black_holes(delta: float, player: BattlePlayer, monsters: Array) -> void:
	for i in range(black_holes.size() - 1, -1, -1):
		var bh = black_holes[i]
		bh.life -= delta
		bh.dmg_timer -= delta
		if bh.life <= 0.0:
			black_holes.remove_at(i)
			continue
		for m in monsters:
			if not is_instance_valid(m) or m.get("alive") == false:
				continue
			var to_center: Vector2 = bh.pos - m.global_position
			var dist := to_center.length()
			if dist > float(bh.radius) + 20.0:
				continue
			if dist > 4.0:
				m.global_position += to_center.normalized() * minf(float(bh.pull) * delta, dist * 0.35)
			if bh.dmg_timer <= 0.0:
				_apply_projectile_hit(bh, m, player)
		if bh.dmg_timer <= 0.0:
			bh.dmg_timer = 0.12


func _update_whirls(delta: float, player: BattlePlayer, monsters: Array) -> void:
	for i in range(whirls.size() - 1, -1, -1):
		var w = whirls[i]
		w.life -= delta
		w.spin += float(w.spin_speed) * delta
		var life_t := clampf(float(w.life) / float(w.max_life), 0.0, 1.0)
		w.radius = lerpf(float(w.max_radius) * 0.55, float(w.max_radius), 1.0 - life_t)
		if w.life <= 0.0:
			whirls.remove_at(i)
			continue
		for m in monsters:
			if not is_instance_valid(m) or m.get("alive") == false:
				continue
			if m.global_position.distance_to(w.pos) > float(w.radius) + m.get_hitbox_radius():
				continue
			_apply_projectile_hit(w, m, player)


func _draw_animated_projectile(
	canvas: Node2D,
	world_pos: Vector2,
	rot: float,
	frames: SpriteFrames,
	scale_mul: float,
	anim_t: float,
	alpha: float = 1.0
) -> void:
	if frames == null or frames.get_frame_count(EffectHelperScript.ANIM_PREVIEW) <= 0:
		return
	var tex := EffectHelperScript.animation_frame_texture(frames, anim_t)
	if tex == null:
		return
	var draw_scale := PROJ_DRAW_SCALE * scale_mul * FX_SCALE
	var local_pos: Vector2 = world_pos - canvas.global_position
	SpriteHelper.draw_effect_texture(
		canvas,
		tex,
		local_pos,
		rot,
		Vector2.ONE * draw_scale,
		Color(1.0, 1.0, 1.0, alpha)
	)


func _draw_auto_fireball(canvas: Node2D, s: Dictionary) -> void:
	var frames: SpriteFrames = _auto_fireball_frames
	if bool(s.get("is_spirit", false)):
		frames = _spirit_frames
	var draw_scale := float(s.get("visual_scale", 1.0)) * AUTO_FIREBALL_DRAW_SCALE
	if bool(s.get("is_giant", false)):
		draw_scale *= 1.45
	elif bool(s.get("is_spirit", false)):
		draw_scale *= 1.15
	var max_life := float(s.get("max_life", GameConfig.get_player_value("auto_dart_life", 0.9)))
	var life_t := clampf(float(s.life) / maxf(0.001, max_life), 0.0, 1.0)
	_draw_animated_projectile(
		canvas,
		Vector2(s.pos),
		float(s.rot),
		frames,
		draw_scale,
		float(s.get("anim_t", 0.0)),
		0.82 + life_t * 0.18
	)
	var glow_r := 12.0 * FX_SCALE * draw_scale * PROJ_DRAW_SCALE
	var local: Vector2 = Vector2(s.pos) - canvas.global_position
	canvas.draw_circle(local, glow_r, Color(1.0, 0.42, 0.1, 0.22 * life_t))


func _draw_shuriken_projectile(canvas: Node2D, s: Dictionary) -> void:
	var frames: SpriteFrames = _dart_frames
	var draw_scale := float(s.get("visual_scale", 1.0)) * PROJ_DRAW_SCALE * FX_SCALE
	match _projectile_kind(s):
		"ice":
			frames = _ice_dart_frames
		"skill":
			frames = _dart_frames
	var local_pos: Vector2 = Vector2(s.pos) - canvas.global_position
	var tex := EffectHelperScript.projectile_frame_texture(frames, float(s.rot) + float(s.get("spin", 0.0)))
	if tex != null:
		SpriteHelper.draw_effect_texture(
			canvas,
			tex,
			local_pos,
			float(s.rot),
			Vector2.ONE * draw_scale
		)
	else:
		_draw_pixel_shuriken(canvas, local_pos, float(s.rot), SHURIKEN_PIXEL)


func _draw_pixel_shuriken(canvas: CanvasItem, center: Vector2, rot: float, px: float) -> void:
	var rows := SHURIKEN_PIXELS.size()
	var cols: int = SHURIKEN_PIXELS[0].size()
	var ox: float = -floor((cols * px) * 0.5)
	var oy: float = -floor((rows * px) * 0.5)
	canvas.draw_set_transform(center, rot, Vector2.ONE)
	for r in range(rows):
		for c in range(cols):
			var hex: Variant = SHURIKEN_PIXELS[r][c]
			if hex == null:
				continue
			canvas.draw_rect(Rect2(ox + c * px, oy + r * px, px, px), Color(hex))


func _update_lightning_fx(delta: float) -> void:
	for i in range(lightning_fx.size() - 1, -1, -1):
		lightning_fx[i].life -= delta
		if lightning_fx[i].life <= 0.0:
			lightning_fx.remove_at(i)


func draw_fx(canvas: Node2D) -> void:
	for s in shurikens:
		var kind := _projectile_kind(s)
		if kind == "auto":
			_draw_auto_fireball(canvas, s)
			continue
		if kind == "fireball":
			var life_t := clampf(float(s.life) / 0.95, 0.0, 1.0)
			_draw_sprite_fx(
				canvas, s.pos, float(s.rot), float(s.get("spin", 0.0)) + Time.get_ticks_msec() * 0.02,
				_fireball_frames, float(s.get("visual_scale", 1.5)), 0.55 + life_t * 0.45
			)
			var glow_r := 14.0 * FX_SCALE * float(s.get("visual_scale", 1.5))
			var local: Vector2 = Vector2(s.pos) - canvas.global_position
			canvas.draw_circle(local, glow_r, Color(1.0, 0.45, 0.12, 0.28 * life_t))
			continue
		_draw_shuriken_projectile(canvas, s)
	for t in water_tornados:
		var life_t := clampf(float(t.life) / float(t.max_life), 0.0, 1.0)
		_draw_water_tornado(canvas, t, life_t)
	for bh in black_holes:
		var life_t := clampf(float(bh.life) / float(bh.max_life), 0.0, 1.0)
		var local_bh: Vector2 = Vector2(bh.pos) - canvas.global_position
		var br := float(bh.radius)
		canvas.draw_circle(local_bh, br, Color(0.15, 0.05, 0.2, 0.45 * life_t))
		canvas.draw_arc(local_bh, br, 0.0, TAU, 56, Color(0.55, 0.2, 0.85, 0.85 * life_t), 7.0)
		canvas.draw_arc(local_bh, br * 0.55, float(Time.get_ticks_msec()) * 0.004, TAU, 40, Color(0.85, 0.5, 1.0, 0.5 * life_t), 4.0)
		_draw_sprite_fx(canvas, bh.pos, 0.0, Time.get_ticks_msec() * 0.012, _black_hole_frames, 1.6, 0.7 * life_t)
	for w in whirls:
		var life_t := clampf(float(w.life) / float(w.max_life), 0.0, 1.0)
		_draw_sprite_fx(canvas, w.pos, float(w.spin), float(w.spin_speed), _whirl_frames, 1.4, 0.75 + life_t * 0.25)
	for fx in lightning_fx:
		var alpha := clampf(float(fx.life) / 0.5, 0.0, 1.0)
		var from_p: Vector2 = fx.from - canvas.global_position
		var to_p: Vector2 = fx.to - canvas.global_position
		canvas.draw_line(from_p, to_p, Color(0.35, 0.55, 1.0, alpha * 0.55), 12.0)
		canvas.draw_line(from_p, to_p, Color(0.75, 0.92, 1.0, alpha), 7.0)
		canvas.draw_line(from_p, to_p, Color(1.0, 1.0, 1.0, alpha * 0.85), 3.0)
		var mid := (from_p + to_p) * 0.5
		_draw_sprite_fx(canvas, mid + canvas.global_position, from_p.angle_to_point(to_p), Time.get_ticks_msec() * 0.03, _lightning_frames, 1.1, alpha)
	if battle and battle.player:
		for swarm in bat_swarms:
			_draw_bat_swarm(canvas, swarm, battle.player)
