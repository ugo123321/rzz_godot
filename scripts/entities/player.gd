extends Node2D
class_name BattlePlayer

signal auto_dart_released

enum State { IDLE, BULLET_TIME, ATTACKING }

const AUTO_DART_RELEASE_RATIO := 0.42
const PATH_LINE_WIDTH := 6.0
const PATH_LINE_COLOR := Color(1.0, 0.85, 0.2, 0.9)
const PATH_LINE_COLOR_ATTACK := Color(1.0, 0.85, 0.2, 0.35)
const PATH_HIT_PAD_RATIO := 0.68
const DRAW_START_FX_SCALE := 1.3

var home_position: Vector2
var state := State.IDLE

var base_attack := 95.0
var attack_power_scale := 1.0
var crit_rate := 0.08
var crit_damage := 1.6
var size_scale := 1.0

var max_hp := 100
var hp := 100
var invincible_timer := 0.0
var damage_flash_timer := 0.0

var base_ki := 234.0
var ki_max := 234.0
var ki := 234.0
var next_turn_ki_bonus := 0.0

var combo_count := 0.0
var combo_hit_count := 0
var combo_display_peak := 0
var combo_display_weight := 0.0
var combo_display_timer := 0.0
var combo_damage_bonus := 0.01

var attack_path: Array[Vector2] = []
var path_index := 0
var path_progress := 0.0
var _path_hit_inside: Dictionary = {}
var _last_attack_pos := Vector2.ZERO
var _attack_hits_primmed := false
var hit_projectiles_this_attack: Dictionary = {}

var upgrade_stacks: Dictionary = {}
var turn_buff_attack_mult := 1.0
var turn_buff_combo_mult := 1.0
var ice_ready := false
var draw_session_snapshot = null
var collected_orb_buffs: Array = []
var ki_at_draw_start := 0.0

var dart_count := 1
var water_tornado_charge := 0
var whirl_charge := 0
var shadow_clones: Array = []
var holy_shield_timer := 0.0
var holy_shield_charges := 0
var kill_count_for_vampire := 0
var heal_bonus := 0.0
var _trigger_ring_fade_t := 0.0
var death_anim: Dictionary = {}
var _fail_visual_base_rotation := 0.0
var _fail_visual_base_position := Vector2.ZERO
var _auto_dart_cycle_active := false
var _auto_dart_released := false
var _draw_start_fx_frames: SpriteFrames
var _draw_start_fx_t := -1.0
var _draw_start_fx_duration := 0.0
var _draw_start_fx_sprite: Sprite2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var trigger_area: Area2D = $TriggerArea
@onready var path_line: Line2D = $PathLine


func _ready() -> void:
	_load_base_stats()
	_draw_start_fx_frames = EffectHelper.build_effect_frames("air_slash")
	if _draw_start_fx_frames != null:
		_draw_start_fx_duration = EffectHelper.one_shot_anim_duration(_draw_start_fx_frames)
	home_position = global_position
	_setup_sprite()
	_update_trigger_radius()
	path_line.width = PATH_LINE_WIDTH
	path_line.default_color = PATH_LINE_COLOR
	path_line.top_level = true


func _load_base_stats() -> void:
	base_attack = float(GameConfig.get_player_value("base_attack", 95))
	max_hp = int(GameConfig.get_player_value("base_hp", 100))
	hp = max_hp
	base_ki = float(GameConfig.get_player_value("base_ki", 234))
	ki_max = base_ki
	ki = ki_max
	crit_rate = float(GameConfig.get_player_value("base_crit_rate", 0.08))
	crit_damage = float(GameConfig.get_player_value("base_crit_damage", 1.6))
	combo_damage_bonus = float(GameConfig.get_player_value("combo_damage_bonus", 0.01))
	size_scale = 1.0
	dart_count = 1


func _apply_sprite_scale() -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite == null:
		return
	SpriteHelper.apply_pixel_art(anim_sprite)
	var scale_val := float(GameConfig.get_player_value("sprite_scale", 1.0))
	var final_scale := SpriteHelper.pixel_scale(scale_val, size_scale)
	anim_sprite.scale = Vector2.ONE * final_scale


func _get_sprite() -> AnimatedSprite2D:
	if sprite != null:
		return sprite
	return get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func get_sprite_node() -> AnimatedSprite2D:
	return _get_sprite()


func _setup_sprite() -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite == null:
		push_warning("BattlePlayer: AnimatedSprite2D not ready")
		return
	var folder := str(GameConfig.get_player_value("character_folder", "Swordsman"))
	var prefix := str(GameConfig.get_player_value("sprite_prefix", "Swordsman"))
	anim_sprite.sprite_frames = SpriteHelper.build_character_frames(folder, prefix)
	SpriteHelper.apply_pixel_art(anim_sprite)
	SpriteHelper.sync_attack01_speed(
		anim_sprite.sprite_frames,
		get_auto_dart_cycle_interval()
	)
	if anim_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_IDLE):
		anim_sprite.play(SpriteHelper.ANIM_IDLE)
	if not anim_sprite.animation_finished.is_connected(_on_animation_finished):
		anim_sprite.animation_finished.connect(_on_animation_finished)
	if not anim_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		anim_sprite.frame_changed.connect(_on_sprite_frame_changed)
	_apply_sprite_scale()


func apply_config() -> void:
	_load_base_stats()
	_setup_sprite()
	_update_trigger_radius()
	queue_redraw()


func _update_trigger_radius() -> void:
	var ref_w := float(GameConfig.get_tuning("logical_width", 390))
	var min_r := float(GameConfig.get_player_value("trigger_radius_min", 30))
	var ratio := float(GameConfig.get_player_value("trigger_radius_ratio", 0.06))
	var radius := maxf(min_r, ratio * ref_w) * size_scale
	if trigger_area.get_child_count() > 0:
		var shape := trigger_area.get_child(0) as CollisionShape2D
		if shape and shape.shape is CircleShape2D:
			(shape.shape as CircleShape2D).radius = radius


func get_effective_radius() -> float:
	return float(GameConfig.get_player_value("hitbox_radius", 12)) * size_scale


func get_path_hit_pad() -> float:
	return get_effective_radius() * PATH_HIT_PAD_RATIO


func get_trigger_radius() -> float:
	var ref_w := float(GameConfig.get_tuning("logical_width", 390))
	var min_r := float(GameConfig.get_player_value("trigger_radius_min", 30))
	var ratio := float(GameConfig.get_player_value("trigger_radius_ratio", 0.06))
	return maxf(min_r, ratio * ref_w) * size_scale


func _get_trigger_ring_fade_duration() -> float:
	return maxf(0.001, float(GameConfig.get_player_value("trigger_ring_fade_in", 0.35)))


func _get_trigger_ring_alpha() -> float:
	var t := clampf(_trigger_ring_fade_t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _update_trigger_ring_fade(delta: float) -> void:
	var should_show := state == State.IDLE and is_ki_full()
	if should_show:
		if _trigger_ring_fade_t >= 1.0:
			return
		_trigger_ring_fade_t = minf(1.0, _trigger_ring_fade_t + delta / _get_trigger_ring_fade_duration())
		queue_redraw()
	elif _trigger_ring_fade_t > 0.0:
		_trigger_ring_fade_t = 0.0
		queue_redraw()


func is_ki_full() -> bool:
	return ki >= ki_max - 0.01


func is_in_attack_mode() -> bool:
	return state == State.ATTACKING


func is_attack_invincible() -> bool:
	return state == State.ATTACKING


func get_auto_dart_cycle_interval() -> float:
	return float(GameConfig.get_player_value("auto_dart_interval", 0.5))


func sync_auto_dart_anim_speed() -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	SpriteHelper.sync_attack01_speed(anim_sprite.sprite_frames, get_auto_dart_cycle_interval())


func begin_auto_dart_cycle() -> bool:
	if state != State.IDLE:
		return false
	var anim_sprite := _get_sprite()
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return false
	if not anim_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_ATTACK01):
		return false
	sync_auto_dart_anim_speed()
	_auto_dart_cycle_active = true
	_auto_dart_released = false
	_play_anim(SpriteHelper.ANIM_ATTACK01, true)
	if _get_auto_dart_release_frame() <= 0:
		_auto_dart_released = true
		auto_dart_released.emit()
	return true


func _get_auto_dart_release_frame() -> int:
	var anim_sprite := _get_sprite()
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return 0
	if not anim_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_ATTACK01):
		return 0
	var count := anim_sprite.sprite_frames.get_frame_count(SpriteHelper.ANIM_ATTACK01)
	return clampi(int(floor(float(count) * AUTO_DART_RELEASE_RATIO)), 0, maxi(0, count - 1))


func _on_sprite_frame_changed() -> void:
	if not _auto_dart_cycle_active or _auto_dart_released:
		return
	var anim_sprite := _get_sprite()
	if anim_sprite == null or anim_sprite.animation != SpriteHelper.ANIM_ATTACK01:
		return
	if anim_sprite.frame >= _get_auto_dart_release_frame():
		_auto_dart_released = true
		auto_dart_released.emit()


func begin_stage() -> void:
	state = State.IDLE
	damage_flash_timer = 0.0
	_reset_sprite_pose()
	attack_path.clear()
	path_index = 0
	path_progress = 0.0
	combo_count = 0.0
	combo_hit_count = 0
	combo_display_peak = 0
	combo_display_weight = 0.0
	water_tornado_charge = 0
	whirl_charge = 0
	_auto_dart_cycle_active = false
	_auto_dart_released = false
	turn_buff_attack_mult = 1.0
	turn_buff_combo_mult = 1.0
	ice_ready = false
	draw_session_snapshot = null
	collected_orb_buffs.clear()
	ki_max = round(base_ki * (1.0 + next_turn_ki_bonus))
	ki = ki_max
	next_turn_ki_bonus = 0.0
	_trigger_ring_fade_t = 0.0
	queue_redraw()
	_update_path_line()


func start_bullet_time() -> void:
	state = State.BULLET_TIME
	attack_path.clear()
	path_index = 0
	path_progress = 0.0
	hit_projectiles_this_attack.clear()
	_play_draw_start_fx()
	add_path_point(home_position)


func _play_draw_start_fx() -> void:
	if _draw_start_fx_frames == null or _draw_start_fx_duration <= 0.0:
		return
	var fx_sprite := _ensure_draw_start_fx_sprite()
	_draw_start_fx_t = 0.0
	fx_sprite.visible = true
	_update_draw_start_fx_sprite()


func _ensure_draw_start_fx_sprite() -> Sprite2D:
	if _draw_start_fx_sprite == null:
		_draw_start_fx_sprite = Sprite2D.new()
		_draw_start_fx_sprite.centered = true
		_draw_start_fx_sprite.z_index = 2
		SpriteHelper.apply_pixel_art(_draw_start_fx_sprite)
		add_child(_draw_start_fx_sprite)
	return _draw_start_fx_sprite


func _update_draw_start_fx(delta: float) -> void:
	if _draw_start_fx_t < 0.0:
		return
	_draw_start_fx_t += delta
	if _draw_start_fx_t >= _draw_start_fx_duration:
		_draw_start_fx_t = -1.0
		if _draw_start_fx_sprite:
			_draw_start_fx_sprite.visible = false
		return
	_update_draw_start_fx_sprite()


func _update_draw_start_fx_sprite() -> void:
	if _draw_start_fx_t < 0.0 or _draw_start_fx_frames == null:
		return
	var fx_sprite := _ensure_draw_start_fx_sprite()
	var tex := EffectHelper.animation_frame_texture_once(_draw_start_fx_frames, _draw_start_fx_t)
	if tex == null:
		fx_sprite.visible = false
		return
	var life_t := clampf(_draw_start_fx_t / maxf(0.001, _draw_start_fx_duration), 0.0, 1.0)
	fx_sprite.texture = tex
	fx_sprite.scale = Vector2.ONE * DRAW_START_FX_SCALE
	fx_sprite.modulate = Color(1.0, 0.98, 0.82, 1.0 - life_t * 0.25)
	fx_sprite.visible = true


func add_path_point(point: Vector2) -> void:
	if attack_path.is_empty() or attack_path.back().distance_to(point) >= 2.0:
		attack_path.append(point)
		_update_path_line()


func consume_ki_by_distance(distance: float) -> bool:
	var cost := distance * float(GameConfig.get_player_value("ki_per_pixel", 0.18))
	if ki < cost:
		return false
	ki -= cost
	return true


func invalidate_path() -> void:
	state = State.IDLE
	attack_path.clear()
	path_index = 0
	path_progress = 0.0
	_update_path_line()


func start_attack() -> void:
	if attack_path.size() < 2:
		invalidate_path()
		return
	var battle := get_tree().get_first_node_in_group("battle")
	if battle and battle.buff_orbs:
		battle.buff_orbs.commit_draw_session()
	state = State.ATTACKING
	combo_count = 0.0
	combo_hit_count = 0
	combo_display_peak = 0
	combo_display_weight = 0.0
	combo_display_timer = 0.0
	if battle and battle.combat:
		battle.combat.begin_round_attack()
	if battle and battle.abilities:
		battle.abilities.on_resolve_started()
	path_index = 0
	path_progress = 0.0
	_path_hit_inside.clear()
	_attack_hits_primmed = false
	_last_attack_pos = attack_path[0]
	hit_projectiles_this_attack.clear()
	_apply_path_line_color()
	_play_anim(SpriteHelper.ANIM_ATTACK)


func update_attack(delta: float, combat: CombatDirector, monsters: Array) -> bool:
	if state != State.ATTACKING or attack_path.size() < 2:
		return false
	if not _attack_hits_primmed:
		_prime_path_start_hits(combat, monsters)
		_attack_hits_primmed = true
	var speed := float(GameConfig.get_player_value("attack_speed", 2300))
	path_progress += speed * delta
	while path_index < attack_path.size() - 1:
		var from := attack_path[path_index]
		var to := attack_path[path_index + 1]
		var seg_len := from.distance_to(to)
		if seg_len < 0.001:
			path_index += 1
			continue
		if path_progress >= seg_len:
			_record_path_crossings(_last_attack_pos, to, combat, monsters, path_index)
			_last_attack_pos = to
			path_progress -= seg_len
			path_index += 1
			continue
		var t := path_progress / seg_len
		var pos := from.lerp(to, t)
		global_position = pos
		_record_path_crossings(_last_attack_pos, pos, combat, monsters, path_index)
		_last_attack_pos = pos
		return false
	_finish_attack(combat)
	return true


func _prime_path_start_hits(combat: CombatDirector, monsters: Array) -> void:
	var hit_pad := get_path_hit_pad()
	var start := attack_path[0]
	for monster in monsters:
		if not is_instance_valid(monster) or not monster.is_combat_targetable():
			continue
		var hit_r: float = monster.get_hitbox_radius() + hit_pad
		var id: int = monster.get_instance_id()
		if start.distance_to(monster.global_position) <= hit_r:
			_path_hit_inside[id] = true
			combat.queue_hit(monster, 0, monster.global_position)
		else:
			_path_hit_inside[id] = false


func _record_path_crossings(
	prev: Vector2,
	curr: Vector2,
	combat: CombatDirector,
	monsters: Array,
	segment_index: int,
) -> void:
	if prev.distance_squared_to(curr) < 0.0001:
		return
	var hit_pad := get_path_hit_pad()
	for monster in monsters:
		if not is_instance_valid(monster) or not monster.is_combat_targetable():
			continue
		var hit_r: float = monster.get_hitbox_radius() + hit_pad
		var center: Vector2 = monster.global_position
		var id: int = monster.get_instance_id()
		var inside: bool = bool(_path_hit_inside.get(id, prev.distance_to(center) <= hit_r))
		for ev in MathUtils.segment_circle_crossings(prev, curr, center, hit_r):
			if bool(ev.get("enter", false)):
				if not inside:
					combat.queue_hit(monster, segment_index, center)
				inside = true
			else:
				inside = false
		_path_hit_inside[id] = inside
	var battle := get_tree().get_first_node_in_group("battle") as BattleController
	if battle:
		battle.block_projectiles_on_path_segment(prev, curr, segment_index, self)


func _finish_attack(combat: CombatDirector) -> void:
	home_position = global_position
	state = State.IDLE
	_reset_sprite_pose()
	_play_anim(SpriteHelper.ANIM_IDLE)
	combat.consume_round_attack()
	combat.begin_resolve(self)
	attack_path.clear()
	_update_path_line()


func end_combo_turn() -> void:
	if get_upgrade_level("shadow_clone") > 0 and combo_display_peak > 10:
		_add_shadow_clones(get_upgrade_level("shadow_clone"))
	if combo_display_peak >= 2:
		combo_display_timer = 0.4
	combo_count = 0.0
	combo_hit_count = 0


func get_combo_bonus_percent(_combo: int = -1) -> int:
	var weighted := combo_display_weight if combo_display_weight > 0.0 else combo_count
	if weighted <= 1.0:
		return 0
	return int(round((weighted - 1.0) * combo_damage_bonus * 100.0))


func get_ability_damage(mult: float) -> int:
	return int(max(1, round(base_attack * attack_power_scale * mult)))


func get_auto_dart_damage() -> int:
	var mult := float(GameConfig.get_player_value("auto_dart_damage_mult", 0.2))
	var dmg := float(get_ability_damage(1)) * turn_buff_attack_mult * mult
	var spirit_lv := get_upgrade_level("spirit_bomb")
	if spirit_lv > 0:
		dmg *= 1.0 + 0.5 * float(spirit_lv)
	return int(max(1, round(dmg)))


func has_spirit_bomb() -> bool:
	return get_upgrade_level("spirit_bomb") > 0


func get_shadow_clone_positions() -> Array:
	var anchor := global_position if state == State.ATTACKING else home_position
	var result: Array = []
	for c in shadow_clones:
		result.append(anchor + Vector2(float(c.ox), float(c.oy)))
	return result


func _add_shadow_clones(count: int) -> void:
	for i in range(count):
		shadow_clones.append({"ox": 0.0, "oy": 0.0})
	_layout_shadow_clones()


func _layout_shadow_clones() -> void:
	var total := shadow_clones.size()
	if total <= 0:
		return
	var idx := 0
	var ring := 0
	while idx < total:
		var on_ring := mini(4 + ring * 2, total - idx)
		var radius := 24.0 + float(ring) * 20.0
		var ring_offset := float(ring) * 0.38
		for slot in range(on_ring):
			var angle := ring_offset + (float(slot) / float(on_ring)) * TAU
			shadow_clones[idx].ox = cos(angle) * radius
			shadow_clones[idx].oy = sin(angle) * radius
			idx += 1
		ring += 1


func register_combo_hit() -> float:
	var battle := get_tree().get_first_node_in_group("battle")
	if battle == null or not battle.combat.is_resolving():
		return combo_count
	combo_hit_count += 1
	var base_inc := 1.0
	var multi_combo_lv := get_upgrade_level("multi_combo")
	var inc := base_inc * turn_buff_combo_mult * pow(1.2, float(multi_combo_lv))
	combo_count += inc
	combo_display_peak = combo_hit_count
	combo_display_weight = combo_count
	combo_display_timer = 0.6
	EventBus.combo_changed.emit(combo_hit_count)
	return combo_count


func get_attack_damage(combo: float) -> Dictionary:
	var bonus := 1.0 + combo_damage_bonus * float(combo)
	var raw := base_attack * attack_power_scale * turn_buff_attack_mult * bonus
	var is_crit := randf() < crit_rate
	if is_crit:
		raw *= crit_damage
	return {"amount": int(max(1, round(raw))), "is_crit": is_crit}


func take_damage(amount: int) -> int:
	if invincible_timer > 0.0 or is_attack_invincible():
		return 0
	if holy_shield_charges > 0:
		holy_shield_charges -= 1
		return 0
	hp = maxi(0, hp - amount)
	invincible_timer = float(GameConfig.get_player_value("invincible_time", 0.45))
	damage_flash_timer = 0.42
	queue_redraw()
	if state == State.IDLE:
		_auto_dart_cycle_active = false
		_auto_dart_released = false
		_play_anim(SpriteHelper.ANIM_HURT)
	EventBus.player_damaged.emit(amount, hp)
	AudioManager.play_player_hurt()
	var battle := get_tree().get_first_node_in_group("battle")
	if battle:
		battle.shake_camera(4.0, 0.12)
	return amount


func heal_percent(ratio: float) -> void:
	var amount := int(round(max_hp * ratio * (1.0 + heal_bonus)))
	hp = mini(max_hp, hp + amount)
	queue_redraw()
	EventBus.player_healed.emit(amount, hp)


func apply_upgrade(upgrade: Dictionary) -> void:
	var id := str(upgrade.get("id", ""))
	upgrade_stacks[id] = int(upgrade_stacks.get(id, 0)) + 1
	_rebuild_upgrades()


func get_upgrade_level(id: String) -> int:
	return int(upgrade_stacks.get(id, 0))


func rebuild_upgrades_from_stacks(stacks: Dictionary, silent := false) -> void:
	var hp_ratio := clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	upgrade_stacks.clear()
	for u in GameConfig.upgrades:
		var id := str(u.get("id", ""))
		var lv := clampi(int(stacks.get(id, 0)), 0, int(u.get("max_level", 9)))
		if lv > 0:
			upgrade_stacks[id] = lv
	_rebuild_upgrades()
	hp = maxi(1, int(round(float(max_hp) * hp_ratio)))
	ki = minf(ki, ki_max)
	if not silent:
		var battle := get_tree().get_first_node_in_group("battle")
		if battle and battle.hud:
			battle.hud.show_message("调试: 强化已更新", 1.2)


func _rebuild_upgrades() -> void:
	base_attack = float(GameConfig.get_player_value("base_attack", 95))
	base_ki = float(GameConfig.get_player_value("base_ki", 234))
	max_hp = int(GameConfig.get_player_value("base_hp", 100))
	crit_rate = float(GameConfig.get_player_value("base_crit_rate", 0.08))
	size_scale = 1.0
	dart_count = 1
	heal_bonus = 0.0
	for id in upgrade_stacks.keys():
		var level := int(upgrade_stacks[id])
		var def := GameConfig.get_upgrade(id)
		if def.is_empty():
			continue
		var apply_type := str(def.get("apply_type", ""))
		match apply_type:
			"ki_mult":
				base_ki = round(base_ki * pow(float(def.get("apply_value", 1.2)), level))
			"hp_mult":
				max_hp = int(round(max_hp * pow(float(def.get("apply_value", 1.1)), level)))
				size_scale *= pow(1.15, level)
			"dart_count":
				dart_count += level
			"crit_rate":
				crit_rate += float(def.get("apply_value", 0.05)) * level
			"heal_bonus":
				heal_bonus += float(def.get("apply_value", 0.5)) * level
			"combo_mult":
				pass
	ki_max = base_ki
	hp = mini(hp, max_hp)
	_update_trigger_radius()
	_apply_sprite_scale()
	sync_auto_dart_anim_speed()


func _play_anim(anim_name: String, force: bool = false) -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	if not anim_sprite.sprite_frames.has_animation(anim_name):
		return
	if anim_name == SpriteHelper.ANIM_HURT:
		force = true
	if not force and anim_sprite.animation == anim_name and anim_sprite.is_playing():
		return
	if force and anim_sprite.animation == anim_name and anim_sprite.is_playing():
		anim_sprite.stop()
		anim_sprite.frame = 0
	anim_sprite.play(anim_name)
	_apply_combat_modulate()


func _on_animation_finished() -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite == null or anim_sprite.sprite_frames == null:
		return
	if anim_sprite.animation == SpriteHelper.ANIM_DEATH:
		return
	if anim_sprite.animation in [SpriteHelper.ANIM_ATTACK, SpriteHelper.ANIM_ATTACK01, SpriteHelper.ANIM_HURT]:
		if state == State.ATTACKING and anim_sprite.animation == SpriteHelper.ANIM_ATTACK:
			return
		if anim_sprite.animation == SpriteHelper.ANIM_ATTACK01:
			_auto_dart_cycle_active = false
			_auto_dart_released = false
		if anim_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_IDLE):
			anim_sprite.play(SpriteHelper.ANIM_IDLE)


func _apply_combat_modulate() -> void:
	if damage_flash_timer > 0.0 and int(floor(damage_flash_timer * 22.0)) % 2 == 0:
		modulate = Color(1.0, 0.45, 0.45)
	elif invincible_timer > 0.0 and damage_flash_timer <= 0.0 and int(floor(invincible_timer * 18.0)) % 2 == 0:
		modulate = Color(1.0, 1.0, 1.0, 0.55)
	else:
		modulate = Color.WHITE


func trigger_combo_abilities(_combo: int, _target_pos: Vector2) -> void:
	pass


func update_idle(delta: float, time_scale: float) -> void:
	if state != State.IDLE:
		return
	if invincible_timer > 0.0:
		invincible_timer -= delta
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
	_apply_combat_modulate()
	if _can_regen_ki():
		ki = minf(ki_max, ki + float(GameConfig.get_player_value("ki_regen_rate", 135)) * delta * time_scale)
	if combo_display_timer > 0.0:
		combo_display_timer -= delta
	_update_holy_shield(delta)


func _can_regen_ki() -> bool:
	if state != State.IDLE or ki >= ki_max - 0.01:
		return false
	var battle := get_tree().get_first_node_in_group("battle")
	if battle == null or battle.combat == null:
		return false
	if battle.combat.is_resolving():
		return false
	if not battle.combat.round_attack_resolved:
		return false
	if battle.state == GameState.LEVEL_UP:
		return false
	return true


func reset_for_new_run() -> void:
	upgrade_stacks.clear()
	shadow_clones.clear()
	clear_fail_death_visuals()
	_load_base_stats()
	hp = max_hp
	ki = ki_max
	home_position = global_position
	begin_stage()
	_rebuild_upgrades()


func _update_holy_shield(delta: float) -> void:
	if get_upgrade_level("holy_shield") <= 0:
		return
	holy_shield_timer -= delta
	if holy_shield_timer <= 0.0:
		holy_shield_charges += 1
		holy_shield_timer = 5.0


func on_enemy_killed(kill_pos: Vector2) -> void:
	kill_count_for_vampire += 1
	if get_upgrade_level("vampire_bat") > 0 and kill_count_for_vampire >= 10:
		kill_count_for_vampire = 0
		var battle := get_tree().get_first_node_in_group("battle")
		if battle and battle.abilities:
			battle.abilities.spawn_vampire_bat_swarm(kill_pos, self)


func _apply_path_line_color() -> void:
	path_line.default_color = PATH_LINE_COLOR_ATTACK if state == State.ATTACKING else PATH_LINE_COLOR


func _update_path_line() -> void:
	path_line.clear_points()
	for p in attack_path:
		path_line.add_point(p)
	_apply_path_line_color()


func begin_fail_death(info: Dictionary) -> void:
	var entering := death_anim.is_empty() or not bool(death_anim.get("active", false))
	death_anim = info.duplicate()
	death_anim["active"] = true
	_trigger_ring_fade_t = 0.0
	var anim_sprite := _get_sprite()
	if anim_sprite:
		if entering:
			_fail_visual_base_rotation = anim_sprite.rotation
			_fail_visual_base_position = anim_sprite.position
		if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(SpriteHelper.ANIM_IDLE):
			anim_sprite.play(SpriteHelper.ANIM_IDLE)
	queue_redraw()


func set_fail_death_phase(phase_name: String) -> void:
	if death_anim.is_empty():
		return
	death_anim["phase"] = phase_name
	queue_redraw()


func clear_fail_death_visuals() -> void:
	death_anim.clear()
	_reset_sprite_pose()
	queue_redraw()


func _reset_sprite_pose() -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite:
		anim_sprite.rotation = 0.0
		anim_sprite.position = Vector2.ZERO
	_fail_visual_base_rotation = 0.0
	_fail_visual_base_position = Vector2.ZERO
	modulate = Color.WHITE


func is_fail_death_pose() -> bool:
	if death_anim.is_empty():
		return false
	var battle := get_tree().get_first_node_in_group("battle")
	if battle and battle.fail_animator:
		return battle.fail_animator.show_fail_pose()
	return bool(death_anim.get("active", false))


func apply_fail_death_visuals(shake: float, fall: float, alpha: float) -> void:
	var anim_sprite := _get_sprite()
	if anim_sprite == null:
		return
	anim_sprite.rotation = fall * 1.05
	anim_sprite.position = Vector2(shake, fall * 22.0)
	modulate = Color(1.0, 1.0, 1.0, alpha)


func _process(delta: float) -> void:
	_update_draw_start_fx(delta)
	if is_fail_death_pose():
		path_line.visible = false
		queue_redraw()
		return
	if state == State.IDLE:
		_apply_combat_modulate()
	path_line.visible = attack_path.size() >= 2
	_update_trigger_ring_fade(delta)


func _should_show_hp_bar() -> bool:
	return hp < max_hp


func get_head_top_global_position() -> Vector2:
	return SpriteHelper.get_character_head_top_global(
		_get_sprite(),
		global_position + Vector2(0.0, -get_effective_radius() * 1.5)
	)


func _draw_hp_bar() -> void:
	var head_pos := to_local(get_head_top_global_position())
	PixelUiHelper.draw_compact_hp_bar(self, head_pos + Vector2(0.0, 5.0), hp, max_hp)


func _draw() -> void:
	if is_fail_death_pose():
		_draw_fail_death_overlay()
		return
	for pos in get_shadow_clone_positions():
		draw_circle(pos - global_position, get_effective_radius() * 0.65, Color(0.45, 0.35, 0.65, 0.55))
	if _should_show_hp_bar():
		_draw_hp_bar()
	var ring_alpha := _get_trigger_ring_alpha()
	if ring_alpha <= 0.0:
		return
	var radius := get_trigger_radius() * lerpf(0.88, 1.0, ring_alpha)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.35 * ring_alpha), 2.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 0.9, 0.3, 0.12 * ring_alpha), radius * 2.0)


func _draw_fail_death_overlay() -> void:
	var battle := get_tree().get_first_node_in_group("battle")
	if battle == null or battle.fail_animator == null:
		return
	var fa: StageFailAnimator = battle.fail_animator
	var shake := fa.death_shake
	var fall := fa.death_fall
	var alpha := fa.death_alpha
	var rot := fall * 1.05
	draw_set_transform(Vector2(shake, fall * 22.0), rot, Vector2.ONE)
	for ang in fa.impale_angles:
		StageFailAnimator.draw_spear(self, Vector2.ZERO, float(ang), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var blood := Color(0.42, 0.06, 0.06, alpha * 0.55)
	draw_rect(Rect2(-10.0 + shake, 10.0 + fall * 22.0, 20.0, 8.0), blood)
