class_name MechHUD
extends CanvasLayer

## HP bar, loadout slots, wave + scrap counters, announcements, end screens.

var game: MechGame
var hp_fill: ColorRect
var hp_label: Label
var slot_labels: Dictionary = {}
var wave_label: Label
var scrap_label: Label
var msg_label: Label
var msg_t := 0.0
var over_panel: PanelContainer
var over_title: Label
var over_sub: Label


func _ready() -> void:
	layer = 5
	# HP bar.
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.position = Vector2(20, 18)
	hp_bg.size = Vector2(340, 30)
	add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color("58d68d")
	hp_fill.position = Vector2(24, 22)
	hp_fill.size = Vector2(332, 22)
	add_child(hp_fill)
	hp_label = _mk_label(self, Vector2(20, 18), Vector2(340, 30), "100", 16, Color.WHITE)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Loadout slots.
	var y := 58.0
	for slot in ["arm", "leg", "core"]:
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.45)
		bg.position = Vector2(20, y)
		bg.size = Vector2(300, 30)
		add_child(bg)
		var lab := _mk_label(self, Vector2(30, y), Vector2(290, 30), "", 15, Color.WHITE)
		lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_labels[slot] = lab
		y += 34.0

	# Wave + scrap.
	wave_label = _mk_label(self, Vector2(-150, 18), Vector2(300, 36), "", 26, Color.WHITE)
	wave_label.position = Vector2(640 - 150, 18)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scrap_label = _mk_label(self, Vector2(1100, 18), Vector2(160, 36), "", 22, Color("ffd75e"))
	scrap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Center announcements.
	msg_label = _mk_label(self, Vector2(240, 200), Vector2(800, 60), "", 40, Color.WHITE)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.modulate.a = 0.0

	# End-screen overlay (hidden).
	over_panel = PanelContainer.new()
	over_panel.set_anchors_preset(Control.PRESET_CENTER)
	over_panel.custom_minimum_size = Vector2(520, 300)
	over_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	style.set_border_width_all(3)
	style.border_color = Color("ff9a3c")
	style.set_corner_radius_all(8)
	over_panel.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	over_panel.add_child(vb)
	over_title = _mk_label(vb, Vector2.ZERO, Vector2(500, 60), "", 44, Color("ff9a3c"))
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_sub = _mk_label(vb, Vector2.ZERO, Vector2(500, 40), "", 20, Color.WHITE)
	over_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := Button.new()
	btn.text = "RESTART"
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func() -> void: game.restart())
	var bc := CenterContainer.new()
	bc.add_child(btn)
	vb.add_child(bc)
	add_child(over_panel)


func _mk_label(parent: Node, pos: Vector2, size: Vector2, text: String, fsize: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	if msg_t > 0.0:
		msg_t -= delta
		msg_label.modulate.a = clampf(msg_t / 0.5, 0.0, 1.0) if msg_t < 0.5 else 1.0


func refresh() -> void:
	var p: PlayerMech = game.player
	if p == null:
		return
	var f := clampf(p.hp / p.max_hp, 0.0, 1.0)
	hp_fill.size.x = 332.0 * f
	hp_fill.color = Color("58d68d") if f > 0.5 else (Color("f5b041") if f > 0.25 else Color("e05252"))
	hp_label.text = "%d / %d" % [int(ceil(p.hp)), int(p.max_hp)]
	for slot in ["arm", "leg", "core"]:
		var pid := str(p.loadout[slot])
		var lab: Label = slot_labels[slot]
		lab.text = "%s: %s" % [PartsDB.SLOT_TITLES[slot], PartsDB.part_name(slot, pid)]
		lab.add_theme_color_override("font_color", PartsDB.part_color(slot, pid))
	wave_label.text = "WAVE %d / 5" % (game.wave_idx + 1) if game.state != "victory" else "CLEAR!"
	scrap_label.text = "SCRAP %d" % game.scrap


func announce(text: String, col: Color = Color.WHITE) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", col)
	msg_t = 2.2
	msg_label.modulate.a = 1.0


func show_end(victory: bool) -> void:
	over_title.text = "JUNKYARD CHAMPION!" if victory else "WRECKED"
	over_title.add_theme_color_override("font_color", Color("ffd75e") if victory else Color("e05252"))
	var waves := game.wave_idx + (1 if victory else 0)
	over_sub.text = "Waves cleared: %d / 5\nScrap collected: %d" % [waves, game.scrap]
	over_panel.visible = true
