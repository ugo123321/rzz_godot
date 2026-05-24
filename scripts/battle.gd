extends Node2D
class_name BattleController

const SummonAbilityManagerScript = preload("res://scripts/core/summon_ability_manager.gd")
const ParticleManagerScript = preload("res://scripts/core/particle_manager.gd")
const BloodStainManagerScript = preload("res://scripts/core/blood_stain_manager.gd")
const GroundEffectManagerScript = preload("res://scripts/core/ground_effect_manager.gd")
const LevelOverlayScript = preload("res://scripts/ui/level_overlay.gd")
const CombatAfterimagesScript = preload("res://scripts/ui/combat_afterimages.gd")
const SakuraSystemScript = preload("res://scripts/systems/sakura_system.gd")
const GrassSystemScript = preload("res://scripts/systems/grass_system.gd")

@export var stage_index := 0

var state := GameState.MENU
var time_scale := 1.0
var pending_stage_clear := false

@onready var player: BattlePlayer = $Entities/Player
@onready var monster_container: Node2D = $Entities/Monsters
@onready var projectiles: Node2D = $Entities/Projectiles
@onready var camera: Camera2D = $Camera2D
@onready var dim_overlay: ColorRect = $DimOverlay
@onready var background: ColorRect = $Background
@onready var hud: GameHud = $UI/HUD
@onready var upgrade_popup: UpgradePopup = $UI/UpgradePopup
@onready var intro_label: Label = $UI/IntroLabel

var combat: CombatDirector
var experience: ExperienceManager
var upgrades: UpgradeManager
var spawner: MonsterSpawner
var path_input
var buff_orbs: BuffOrbManager
var abilities: AbilityManager
var summons
var damage_overlay: DamageNumbersOverlay
var afterimages_overlay
var terrain: TerrainBackground
var pause_menu: PauseMenu
var fail_animator: StageFailAnimator
var particles
var blood_stains
var ground_effects
var level_overlay
var grass_field
var sakura_field
var hit_fx_overlay: Node2D

var stage_intro_timer := 0.0

var shake_mag := 0.0
var shake_dur := 0.0
var shake_timer := 0.0


func _ready() -> void:
	add_to_group("battle")
	GameConfig.reload()
	combat = CombatDirector.new()
	add_child(combat)
	experience = ExperienceManager.new()
	add_child(experience)
	upgrades = UpgradeManager.new()
	add_child(upgrades)
	spawner = MonsterSpawner.new()
	add_child(spawner)
	path_input = PathInput.new()
	add_child(path_input)
	path_input.setup(self)
	buff_orbs = BuffOrbManager.new()
	buff_orbs.name = "BuffOrbs"
	add_child(buff_orbs)
	buff_orbs.setup(self)
	abilities = AbilityManager.new()
	add_child(abilities)
	abilities.setup(self)
	summons = SummonAbilityManagerScript.new()
	summons.name = "Summons"
	add_child(summons)
	summons.setup(self)
	damage_overlay = DamageNumbersOverlay.new()
	damage_overlay.name = "DamageNumbers"
	damage_overlay.z_index = 50
	add_child(damage_overlay)
	damage_overlay.setup(combat)
	afterimages_overlay = CombatAfterimagesScript.new()
	afterimages_overlay.name = "CombatAfterimages"
	afterimages_overlay.z_index = 46
	add_child(afterimages_overlay)
	afterimages_overlay.setup(combat, player)
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	$UI.add_child(pause_menu)
	pause_menu.setup(self)
	fail_animator = StageFailAnimator.new()
	add_child(fail_animator)
	fail_animator.setup(self)
	particles = ParticleManagerScript.new()
	particles.name = "Particles"
	particles.z_index = 40
	add_child(particles)
	blood_stains = BloodStainManagerScript.new()
	blood_stains.name = "BloodStains"
	blood_stains.z_index = -4
	add_child(blood_stains)
	ground_effects = GroundEffectManagerScript.new()
	ground_effects.name = "GroundEffects"
	ground_effects.z_index = -3
	add_child(ground_effects)
	ground_effects.setup(self)
	level_overlay = LevelOverlayScript.new()
	level_overlay.name = "LevelOverlay"
	level_overlay.z_index = 60
	$UI.add_child(level_overlay)
	level_overlay.setup(self)
	terrain = TerrainBackground.new()
	terrain.name = "Terrain"
	terrain.z_index = -5
	add_child(terrain)
	grass_field = GrassSystemScript.new()
	grass_field.name = "GrassField"
	grass_field.z_index = -4
	add_child(grass_field)
	sakura_field = SakuraSystemScript.new()
	sakura_field.name = "SakuraField"
	sakura_field.z_index = -2
	add_child(sakura_field)
	hit_fx_overlay = Node2D.new()
	hit_fx_overlay.name = "HitFxOverlay"
	hit_fx_overlay.z_index = 6
	add_child(hit_fx_overlay)
	hit_fx_overlay.draw.connect(_draw_hit_fx_overlay)
	terrain.setup_for_stage(0, _get_safe_zone())
	_sync_background_layer()
	_refresh_stage_ambience()
	upgrade_popup.setup(self, upgrades)
	upgrade_popup.upgrade_picked.connect(_on_upgrade_picked)
	combat.resolve_finished.connect(_on_resolve_finished)
	EventBus.monster_killed.connect(_on_monster_killed)
	_setup_viewport()
	player.apply_config()
	hud.bind_player(player)
	intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_game()


func _setup_viewport() -> void:
	var w := int(GameConfig.get_tuning("logical_width", 390))
	var h := int(GameConfig.get_tuning("logical_height", 700))
	dim_overlay.size = Vector2(w, h)
	dim_overlay.visible = false
	var zoom := maxf(1.0, round(float(GameConfig.get_tuning("camera_zoom", 1.0))))
	camera.zoom = Vector2.ONE * zoom
	player.global_position = Vector2(w * 0.5, h * 0.58)
	player.home_position = player.global_position


func start_game() -> void:
	stage_index = 0
	experience.reset()
	player.reset_for_new_run()
	if fail_animator:
		fail_animator.reset()
	if level_overlay:
		level_overlay.reset_all()
	if sakura_field:
		sakura_field.stop_field()
	if blood_stains:
		blood_stains.clear()
	state = GameState.MENU
	hud.show_message("点击屏幕开始", 999.0)
	intro_label.text = "忍者斩"


func _start_stage() -> void:
	if fail_animator:
		fail_animator.reset()
	player.begin_stage()
	combat.reset_for_stage()
	abilities.reset()
	if summons:
		summons.reset(stage_index > 0)
	if particles:
		particles.clear()
	if blood_stains:
		blood_stains.clear()
	if ground_effects:
		ground_effects.reset()
	spawner.spawn_stage(stage_index, self)
	if terrain:
		terrain.setup_for_stage(stage_index, _get_safe_zone())
	_sync_background_layer()
	_refresh_stage_ambience()
	var stage := GameConfig.get_stage(stage_index)
	var boss_id := str(stage.get("boss_id", ""))
	if boss_id.is_empty() and buff_orbs:
		buff_orbs.spawn_for_stage(stage_index, player.home_position)
	elif buff_orbs:
		buff_orbs.reset()
	hud.set_stage_text(str(stage.get("display_name", "第%d关" % (stage_index + 1))))
	_begin_stage_intro()


func apply_debug_settings(target_level: int, target_stage: int) -> void:
	pending_stage_clear = false
	stage_index = clampi(target_stage, 0, maxi(0, GameConfig.stages.size() - 1))
	experience.set_debug_level(target_level, player)
	player.begin_stage()
	combat.reset_for_stage()
	abilities.reset()
	if summons:
		summons.reset(false)
	if particles:
		particles.clear()
	if blood_stains:
		blood_stains.clear()
	if ground_effects:
		ground_effects.reset()
	if level_overlay:
		level_overlay.reset_all()
	spawner.spawn_stage(stage_index, self)
	if terrain:
		terrain.setup_for_stage(stage_index, _get_safe_zone())
	_sync_background_layer()
	_refresh_stage_ambience()
	var stage := GameConfig.get_stage(stage_index)
	var boss_id := str(stage.get("boss_id", ""))
	if boss_id.is_empty() and buff_orbs:
		buff_orbs.spawn_for_stage(stage_index, player.home_position)
	elif buff_orbs:
		buff_orbs.reset()
	hud.set_stage_text(str(stage.get("display_name", "第%d关" % (stage_index + 1))))
	state = GameState.PLAYING
	intro_label.visible = false
	hud.hide_message()
	hud.show_message("调试跳关已应用", 1.5)


func shake_camera(magnitude: float, duration: float) -> void:
	if magnitude >= shake_mag:
		shake_mag = magnitude
		shake_dur = duration
	shake_timer = maxf(shake_timer, duration)


func _sync_background_layer() -> void:
	if background == null:
		return
	background.z_index = -100
	background.visible = true


func _refresh_stage_ambience() -> void:
	if grass_field == null:
		return
	var w := float(GameConfig.get_tuning("logical_width", 390))
	var h := float(GameConfig.get_tuning("logical_height", 700))
	var play_bottom := PixelUiHelper.get_play_area_bottom(h)
	grass_field.init_field(w, h, play_bottom, _get_safe_zone())


func _get_safe_zone() -> Dictionary:
	if player == null:
		return {}
	return {
		"x": player.home_position.x,
		"y": player.home_position.y,
		"r": player.get_trigger_radius(),
	}


func _update_ambience(delta: float) -> void:
	var w := float(GameConfig.get_tuning("logical_width", 390))
	var h := float(GameConfig.get_tuning("logical_height", 700))
	if grass_field:
		grass_field.update_field(delta)
	if sakura_field:
		sakura_field.update_field(delta, w, h)


func _update_camera_shake(delta: float) -> void:
	if shake_timer <= 0.0:
		camera.offset = Vector2.ZERO
		return
	shake_timer -= delta
	var intensity := shake_timer / maxf(0.001, shake_dur)
	camera.offset = Vector2(
		randf_range(-1.0, 1.0) * 2.0 * shake_mag * intensity,
		randf_range(-1.0, 1.0) * 2.0 * shake_mag * intensity
	)
	if shake_timer <= 0.0:
		camera.offset = Vector2.ZERO
		shake_mag = 0.0


func _begin_stage_intro() -> void:
	state = GameState.STAGE_INTRO
	intro_label.visible = false
	if sakura_field:
		var slide_in := float(GameConfig.get_tuning("stage_intro_slide_in", 0.38))
		var hold := float(GameConfig.get_tuning("stage_intro_hold", 0.85))
		var slide_out := float(GameConfig.get_tuning("stage_intro_slide_out", 0.38))
		var sakura_extra := float(GameConfig.get_tuning("stage_intro_sakura_extra", 0.8))
		var intro_dur := slide_in + hold + slide_out
		var w := float(GameConfig.get_tuning("logical_width", 390))
		var h := float(GameConfig.get_tuning("logical_height", 700))
		sakura_field.start_field(w, h, intro_dur + sakura_extra)
	var stage := GameConfig.get_stage(stage_index)
	var boss_id := str(stage.get("boss_id", ""))
	var boss_name := ""
	if boss_id == "centipede":
		boss_name = "Boss: 千足虫"
	if level_overlay:
		level_overlay.start_stage_intro(stage_index + 1, boss_name, _finish_stage_intro)


func _finish_stage_intro() -> void:
	state = GameState.PLAYING
	intro_label.visible = false
	if level_overlay:
		level_overlay.clear_stage_intro()
	hud.hide_message()
	if experience:
		EventBus.exp_changed.emit(experience.level, experience.exp, experience.exp_to_next)


func enter_bullet_time() -> void:
	time_scale = float(GameConfig.get_tuning("bullet_time_scale", 0.14))
	dim_overlay.visible = true
	dim_overlay.color = Color(0, 0, 0, float(GameConfig.get_tuning("bullet_time_dim_alpha", 0.42)))


func exit_bullet_time(cancelled: bool) -> void:
	time_scale = 1.0
	dim_overlay.visible = false
	if cancelled:
		if buff_orbs:
			buff_orbs.cancel_draw_session()
		if player.state == BattlePlayer.State.BULLET_TIME:
			player.invalidate_path()
		return
	player.start_attack()


func resume_from_pause() -> void:
	if state != GameState.PAUSED:
		return
	state = GameState.PLAYING
	if pause_menu:
		pause_menu.close_menu()
	hud.show_message("继续战斗", 1.0)


func pause_game() -> void:
	if state in [GameState.MENU, GameState.FAIL_DEATH, GameState.STAGE_CLEAR, GameState.COMPLETE, GameState.FAIL, GameState.STAGE_FAIL, GameState.LEVEL_UP]:
		return
	# 关卡 intro 期间也允许暂停
	state = GameState.PAUSED
	path_input.cancel_active()
	if pause_menu:
		pause_menu.z_index = 200
		pause_menu.open_menu()
		pause_menu.move_to_front()


func enter_level_up() -> void:
	state = GameState.LEVEL_UP
	path_input.cancel_active()
	upgrades.generate_choices(player)
	upgrade_popup.z_index = 80
	upgrade_popup.show_popup()
	upgrade_popup.move_to_front()


func _on_monster_killed(monster: Node) -> void:
	if blood_stains and is_instance_valid(monster) and monster is BattleMonster:
		var hit_r: float = monster.get_hitbox_radius()
		var intensity := 1.35 if hit_r > 13.0 else 1.0
		var hit_angle := randf() * TAU
		if player:
			hit_angle = (monster.global_position - player.global_position).angle()
		blood_stains.spawn(
			monster.global_position.x,
			monster.global_position.y + hit_r * 0.35,
			intensity,
			hit_angle
		)
	if player and player.ice_ready:
		combat.try_ice_burst(player, monster.global_position)
	experience.on_monster_killed(monster)
	if player:
		player.on_enemy_killed(monster.global_position)


func _on_upgrade_picked(_index: int) -> void:
	state = GameState.PLAYING
	experience.try_trigger_upgrade(self)
	_try_finish_stage_clear()


func _on_resolve_finished() -> void:
	experience.try_trigger_upgrade(self)
	_try_finish_stage_clear()


func _needs_fx_redraw() -> bool:
	if abilities and abilities.has_active_fx():
		return true
	if summons and summons.has_active_fx():
		return true
	if particles:
		for p in particles.pool:
			if p.active:
				return true
	if blood_stains and not blood_stains.stains.is_empty():
		return true
	if fail_animator and fail_animator.is_active():
		return true
	return false


func _update_path_preview() -> void:
	var targets := spawner.get_active_monsters()
	if player.state == BattlePlayer.State.BULLET_TIME and player.attack_path.size() >= 2:
		combat.update_path_preview_highlights(player.attack_path, player, targets)
	else:
		combat.clear_path_preview_highlights(targets)


func _try_finish_stage_clear() -> void:
	if not pending_stage_clear:
		return
	if combat.is_resolving() or combat.has_combat_presentation() or state == GameState.LEVEL_UP:
		return
	if abilities and abilities.has_active_fx():
		return
	if summons and summons.has_active_fx():
		return
	pending_stage_clear = false
	_begin_stage_clear()


func _begin_stage_clear() -> void:
	state = GameState.STAGE_CLEAR
	intro_label.visible = false
	hud.hide_message()
	if level_overlay:
		level_overlay.show_clear_flash(_advance_stage)


func _advance_stage() -> void:
	if level_overlay:
		level_overlay.reset_all()
	stage_index += 1
	if stage_index >= GameConfig.stages.size():
		state = GameState.COMPLETE
		if level_overlay:
			level_overlay.show_game_complete()
		hud.hide_message()
		return
	_start_stage()


func _process(delta: float) -> void:
	var scaled_delta := delta * time_scale
	match state:
		GameState.MENU:
			_update_ambience(delta)
		GameState.STAGE_INTRO:
			_update_ambience(delta)
			if level_overlay:
				level_overlay.update_overlay(delta)
		GameState.PLAYING:
			_update_playing(scaled_delta, delta)
		GameState.PAUSED:
			pass
		GameState.STAGE_CLEAR:
			if level_overlay:
				level_overlay.update_overlay(delta)
		GameState.FAIL_DEATH:
			_update_ambience(delta)
			if combat:
				combat.update_afterimages(delta)
			if fail_animator:
				fail_animator.update(delta)
			if particles:
				particles.update_particles(delta)
			if blood_stains:
				blood_stains.update_stains(delta)
			if spawner:
				for monster in spawner.monsters:
					if is_instance_valid(monster):
						monster.queue_redraw()
			_update_camera_shake(delta)
			queue_redraw()
		GameState.STAGE_FAIL:
			if level_overlay:
				level_overlay.update_overlay(delta)
		GameState.COMPLETE:
			pass
		GameState.LEVEL_UP:
			upgrades.update(delta)
	_update_camera_shake(delta)


func _update_playing(scaled_delta: float, real_delta: float) -> void:
	_update_ambience(real_delta)
	player.update_idle(real_delta, time_scale if time_scale < 1.0 else 1.0)
	if level_overlay and level_overlay.is_stage_intro_active():
		level_overlay.update_overlay(real_delta)
	if player.state == BattlePlayer.State.ATTACKING:
		player.update_attack(scaled_delta, combat, spawner.get_active_monsters())
	combat.update_afterimages(real_delta)
	combat.update_resolve(scaled_delta, player)
	combat.update_damage_numbers(real_delta)
	if buff_orbs:
		buff_orbs.update(real_delta, player)
	if abilities:
		abilities.update(real_delta, player, spawner.get_active_monsters())
	if summons:
		var summon_delta := 0.0 if time_scale < 1.0 else real_delta
		summons.update(summon_delta, player, spawner.get_active_monsters())
	if particles:
		particles.update_particles(real_delta)
	if blood_stains:
		blood_stains.update_stains(real_delta)
	if ground_effects:
		var effect_delta := 0.0 if time_scale < 1.0 else real_delta
		ground_effects.update_effects(effect_delta, player)
	spawner.update_boss(real_delta, player)
	for monster in spawner.monsters:
		if is_instance_valid(monster) and monster.has_method("update_death"):
			monster.update_death(real_delta)
		if is_instance_valid(monster) and monster.has_method("update_ai"):
			monster.update_ai(scaled_delta if time_scale >= 1.0 else 0.0, player, self)
	_update_path_preview()
	experience.try_trigger_upgrade(self)
	if _needs_fx_redraw():
		queue_redraw()
		if hit_fx_overlay:
			hit_fx_overlay.queue_redraw()
	if player.hp <= 0 and state == GameState.PLAYING:
		_begin_fail_death()
		return
	var summon_fx_active: bool = summons != null and summons.has_active_fx()
	if spawner.all_dead() and not combat.is_resolving() and not combat.has_combat_presentation() and player.state == BattlePlayer.State.IDLE and not abilities.has_active_fx() and not summon_fx_active:
		pending_stage_clear = true
		_try_finish_stage_clear()


func _begin_fail_death() -> void:
	if fail_animator and fail_animator.is_active():
		return
	state = GameState.FAIL_DEATH
	path_input.cancel_active()
	if fail_animator:
		fail_animator.start(_on_fail_death_finished)


func _on_fail_death_finished() -> void:
	state = GameState.STAGE_FAIL
	hud.hide_message()
	if level_overlay:
		level_overlay.show_fail_intro(Callable())


func _draw_hit_fx_overlay() -> void:
	if abilities:
		abilities.draw_hit_fx(hit_fx_overlay)


func _draw() -> void:
	if blood_stains:
		blood_stains.draw_stains(self)
	if fail_animator:
		fail_animator.draw_flying_spears(self)
	if particles:
		particles.draw_particles(self)
	if abilities:
		abilities.draw_fx(self)
	if summons:
		summons.draw_fx(self)


func _pointer_flow_uses_early_input() -> bool:
	return state in [
		GameState.MENU,
		GameState.STAGE_INTRO,
		GameState.FAIL,
		GameState.COMPLETE,
		GameState.STAGE_FAIL,
	]


func _input(event: InputEvent) -> void:
	if pause_menu and pause_menu.visible:
		return
	if upgrade_popup.visible:
		return
	if event.is_action_pressed("ui_cancel") and state in [GameState.PLAYING, GameState.STAGE_INTRO]:
		pause_game()
		get_viewport().set_input_as_handled()
		return
	if _pointer_flow_uses_early_input():
		_dispatch_pointer_event(event, true)
		return
	# 战斗中画线必须在 _input 处理：全屏 HUD 会挡住 _unhandled_input
	if state == GameState.PLAYING:
		_dispatch_pointer_event(event, false)


func _unhandled_input(event: InputEvent) -> void:
	if pause_menu and pause_menu.visible:
		return
	if upgrade_popup.visible:
		return
	if _pointer_flow_uses_early_input() or state == GameState.PLAYING:
		return
	_dispatch_pointer_event(event, false)


func _dispatch_pointer_event(event: InputEvent, mark_handled: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position, "down")
		if mark_handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_pointer(event.position, "up")
		if mark_handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_pointer(event.position, "move")
	elif event is InputEventScreenTouch and event.pressed:
		_handle_pointer(event.position, "down")
		if mark_handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_handle_pointer(event.position, "up")
		if mark_handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_handle_pointer(event.position, "move")


func _handle_pointer(screen_pos: Vector2, phase: String) -> void:
	if state == GameState.MENU:
		if phase == "down":
			hud.hide_message()
			state = GameState.STAGE_INTRO
			_start_stage()
		return
	if state == GameState.FAIL or state == GameState.COMPLETE or state == GameState.STAGE_FAIL:
		if phase == "down":
			hud.hide_message()
			start_game()
			state = GameState.STAGE_INTRO
			_start_stage()
		return
	if state == GameState.STAGE_INTRO:
		if phase == "down":
			_finish_stage_intro()
		return
	if state == GameState.LEVEL_UP:
		return
	if state == GameState.PAUSED or state == GameState.FAIL_DEATH or state == GameState.STAGE_CLEAR:
		return
	if phase == "down" and hud.is_pause_button_at(screen_pos):
		return
	match phase:
		"down":
			path_input.handle_start(screen_pos)
		"move":
			path_input.handle_move(screen_pos)
		"up":
			path_input.handle_end()


func screen_to_world(screen_pos: Vector2) -> Vector2:
	var xform := get_viewport().get_canvas_transform()
	return xform.affine_inverse() * screen_pos


func is_in_bounds(pos: Vector2) -> bool:
	var w := float(GameConfig.get_tuning("logical_width", 390))
	var h := float(GameConfig.get_tuning("logical_height", 700))
	return pos.x >= 0 and pos.y >= 0 and pos.x <= w and pos.y <= h


func spawn_arrow(from_pos: Vector2, to_pos: Vector2, damage: int, kind_id: String = "") -> void:
	var dir := (to_pos - from_pos).normalized()
	var arrow := ColorRect.new()
	var is_fire := kind_id == "FIRE_MAGE"
	arrow.size = Vector2(10 if not is_fire else 8, 4 if not is_fire else 8)
	arrow.color = Color(1.0, 0.35, 0.12) if is_fire else Color(0.9, 0.8, 0.2)
	arrow.position = from_pos
	projectiles.add_child(arrow)
	var tween := create_tween()
	var target := from_pos + dir * 300.0
	tween.tween_property(arrow, "position", target, 0.8)
	tween.tween_callback(func():
		if is_instance_valid(arrow):
			if arrow.position.distance_to(player.global_position) < 20.0:
				player.take_damage(damage)
			arrow.queue_free()
	)
