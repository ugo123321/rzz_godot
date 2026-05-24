extends Node2D
class_name DamageNumbersOverlay

var combat: CombatDirector


func setup(combat_director: CombatDirector) -> void:
	combat = combat_director


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if combat == null:
		return
	var font := PixelUiHelper.get_ui_font()
	for dn in combat.damage_numbers:
		var t := clampf(float(dn.life) / float(dn.max_life), 0.0, 1.0)
		var pos: Vector2 = dn.pos - global_position
		var is_crit: bool = bool(dn.is_crit)
		var is_heal: bool = bool(dn.get("is_heal", false))
		var tint = dn.get("color")
		var color := Color.WHITE
		if tint is Color:
			color = tint as Color
			color.a = t
		elif is_heal:
			color = Color("#68d878", t)
		elif is_crit:
			color = Color("#ffd060", t)
		else:
			color = Color(1.0, 1.0, 1.0, t)
		var font_size := 20 if is_crit else 15
		var text := str(dn.get("damage", 0))
		if is_heal:
			text = "+%s" % text
		draw_string(font, pos + Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
