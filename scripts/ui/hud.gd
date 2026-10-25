class_name FortHUD
extends CanvasLayer
## View-only HUD. Economy and gameplay decisions remain in FortGame.

signal start_wave_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal build_requested
signal upgrade_requested
signal close_requested
signal sound_toggled(muted: bool)

const INK := Color("122b35")
const PANEL := Color("173743")
const EDGE := Color("3c6470")
const CREAM := Color("f1f1df")
const MUTED := Color("afc4c3")
const GOLD := Color("f5cd66")
const BLUE := Color("6fb8e0")

var _root: Control
var _safe_top: MarginContainer
var _safe_bottom: MarginContainer
var _gold_value: Label
var _health_value: Label
var _wave_value: Label
var _wave_button: Button
var _pause_button: Button
var _message: Label
var _context: PanelContainer
var _context_title: Label
var _context_details: Label
var _context_action: Button
var _context_hint: Label
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_description: Label
var _resume_button: Button
var _restart_button: Button
var _sound_button: Button
var _slot: FortBuildSlot
var _tower_levels: Array = []
var _gold := 0
var _result_shown := false
var _paused := false
var _notice_time := 0.0
var _sound_muted := false
var _health_flash_remaining := 0.0
var _health_color := CREAM


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_ui()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _process(delta: float) -> void:
	# The menu remains interactive while paused; gameplay notices freeze with it.
	if get_tree().paused:
		return
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0:
			_message.text = "Toca una casilla + para construir"
			_message.add_theme_color_override("font_color", CREAM)
	if _health_flash_remaining > 0.0:
		_health_flash_remaining = maxf(0.0, _health_flash_remaining - delta)
		var strength := _health_flash_remaining / 0.45
		_health_value.add_theme_color_override("font_color", _health_color.lerp(Color("ff8a68"), strength))
		_health_value.scale = Vector2.ONE * (1.0 + 0.10 * strength)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.theme = _make_theme()

	_safe_top = MarginContainer.new()
	_safe_top.name = "SafeTop"
	_safe_top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_safe_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_safe_top)
	var top_panel := _panel(PANEL, 16)
	_safe_top.add_child(top_panel)
	var top_content := VBoxContainer.new()
	top_content.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_content)
	var brand_row := HBoxContainer.new()
	brand_row.add_theme_constant_override("separation", 12)
	top_content.add_child(brand_row)
	var title := _label("FORT CONTROL", 28, CREAM)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_row.add_child(title)
	_pause_button = _button("Ⅱ", BLUE)
	_pause_button.name = "PauseButton"
	_pause_button.custom_minimum_size = Vector2(90, 90)
	_pause_button.tooltip_text = "Pausar (P / Esc)"
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	brand_row.add_child(_pause_button)
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 8)
	top_content.add_child(stats_row)
	_gold_value = _stat(stats_row, "ORO", "300", GOLD)
	_health_value = _stat(stats_row, "FORTALEZA", "20", CREAM)
	_wave_value = _stat(stats_row, "OLEADA", "0 / 5", BLUE)

	_safe_bottom = MarginContainer.new()
	_safe_bottom.name = "SafeBottom"
	_safe_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_safe_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_safe_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_safe_bottom)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe_bottom.add_child(bottom)
	_message = _label("Toca una casilla + para construir", 19, CREAM)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_shadow_color", INK)
	_message.add_theme_constant_override("shadow_offset_x", 1)
	_message.add_theme_constant_override("shadow_offset_y", 2)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(_message)

	_context = _panel(PANEL, 16)
	_context.name = "SelectionPanel"
	_context.hide()
	bottom.add_child(_context)
	var context_content := VBoxContainer.new()
	context_content.add_theme_constant_override("separation", 7)
	_context.add_child(context_content)
	var context_heading := HBoxContainer.new()
	context_content.add_child(context_heading)
	_context_title = _label("Torre ballesta", 25, CREAM)
	_context_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_heading.add_child(_context_title)
	var close := _button("×", MUTED)
	close.name = "CloseSelectionButton"
	close.custom_minimum_size = Vector2(90, 90)
	close.pressed.connect(func() -> void: close_requested.emit())
	context_heading.add_child(close)
	_context_details = _label("", 19, MUTED)
	_context_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_content.add_child(_context_details)
	_context_action = _button("Construir · 100 oro", GOLD)
	_context_action.name = "BuildUpgradeButton"
	_context_action.pressed.connect(_on_context_action)
	context_content.add_child(_context_action)
	_context_hint = _label("", 17, MUTED)
	_context_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_content.add_child(_context_hint)

	_wave_button = _button("INICIAR OLEADA 1  →", GOLD)
	_wave_button.name = "StartWaveButton"
	_wave_button.custom_minimum_size.y = 94
	_wave_button.pressed.connect(func() -> void: start_wave_requested.emit())
	bottom.add_child(_wave_button)
	var help := _label("Arrastra para explorar  ·  Pellizca o usa la rueda para zoom", 16, MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_shadow_color", INK)
	help.add_theme_constant_override("shadow_offset_y", 2)
	bottom.add_child(help)

	_overlay = ColorRect.new()
	_overlay.name = "PauseAndResultOverlay"
	_overlay.color = Color(0.035, 0.09, 0.12, 0.88)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.hide()
	_root.add_child(_overlay)
	var overlay_margin := MarginContainer.new()
	overlay_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		overlay_margin.add_theme_constant_override("margin_" + edge, 30)
	_overlay.add_child(overlay_margin)
	var center := CenterContainer.new()
	overlay_margin.add_child(center)
	var result_panel := _panel(PANEL, 24)
	result_panel.custom_minimum_size.x = 420
	center.add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_box)
	var sigil := _label("◆  FORT CONTROL  ◆", 20, GOLD)
	sigil.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(sigil)
	_overlay_title = _label("PAUSA", 40, CREAM)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_box.add_child(_overlay_title)
	_overlay_description = _label("Tu fortaleza te espera.", 20, MUTED)
	_overlay_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_description.custom_minimum_size = Vector2(350, 65)
	result_box.add_child(_overlay_description)
	_resume_button = _button("Continuar", GOLD)
	_resume_button.name = "ResumeButton"
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	result_box.add_child(_resume_button)
	_sound_button = _button("Sonido: activado", CREAM)
	_sound_button.name = "SoundToggleButton"
	_sound_button.pressed.connect(func() -> void:
		set_sound_muted(not _sound_muted)
		sound_toggled.emit(_sound_muted)
	)
	result_box.add_child(_sound_button)
	set_sound_muted(_sound_muted)
	_restart_button = _button("Reiniciar partida", BLUE)
	_restart_button.name = "RestartButton"
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	result_box.add_child(_restart_button)


func update_status(gold: int, health: int, wave: int, total: int, can_start: bool) -> void:
	_gold = gold
	_gold_value.text = str(gold)
	_health_value.text = str(health)
	_health_color = Color("ef9d88") if health <= 5 else CREAM
	if _health_flash_remaining <= 0.0:
		_health_value.add_theme_color_override("font_color", _health_color)
	_wave_value.text = "%d / %d" % [wave, total]
	_wave_button.disabled = not can_start or _paused or _result_shown
	if can_start:
		_wave_button.text = "INICIAR OLEADA %d  →" % (wave + 1)
	elif wave >= total:
		_wave_button.text = "ÚLTIMA DEFENSA · ELIMINA A LOS RESTANTES"
	else:
		_wave_button.text = "OLEADA EN CURSO · DEFIENDE LA FORTALEZA"
	if is_instance_valid(_slot):
		_refresh_context()


func show_slot(slot: FortBuildSlot, tower_levels: Array, gold: int) -> void:
	_slot = slot
	_tower_levels = tower_levels
	_gold = gold
	_context.show()
	_refresh_context()


func _refresh_context() -> void:
	if not is_instance_valid(_slot) or _tower_levels.is_empty():
		clear_selection()
		return
	var tower: FortTower = _slot.tower as FortTower
	if _slot.occupied and is_instance_valid(tower):
		var level: int = tower.level
		var stats: Dictionary = tower.stats()
		_context_title.text = "Ballesta · Nivel %d" % level
		if level >= _tower_levels.size():
			_context_details.text = "Daño %d   ·   Alcance %.1f\n%.2f ataques/s · Alcance en azul" % [int(stats.damage), float(stats.range), 1.0 / float(stats.interval)]
			_context_action.text = "NIVEL MÁXIMO"
			_context_action.disabled = true
			_context_hint.text = "Defensa completamente mejorada"
		else:
			var next_stats: Dictionary = _tower_levels[level]
			var next_cost := int(next_stats.cost)
			_context_details.text = "Daño %d → %d   ·   Alcance %.1f → %.1f\nAtaques/s %.2f → %.2f" % [
				int(stats.damage), int(next_stats.damage), float(stats.range), float(next_stats.range),
				1.0 / float(stats.interval), 1.0 / float(next_stats.interval)
			]
			_context_action.text = "Mejorar a nivel %d · %d oro" % [level + 1, next_cost]
			_context_action.disabled = _gold < next_cost
			_context_hint.text = "Faltan %d monedas · Azul: actual / Dorado: mejora" % (next_cost - _gold) if _gold < next_cost else "Azul: alcance actual · Dorado: después de mejorar"
	else:
		var initial_stats: Dictionary = _tower_levels[0]
		var cost := int(initial_stats.cost)
		_context_title.text = "Construir ballesta"
		_context_details.text = "Daño %d   ·   Alcance %.1f\n%.2f ataques/s · Alcance en azul" % [int(initial_stats.damage), float(initial_stats.range), 1.0 / float(initial_stats.interval)]
		_context_action.text = "Construir · %d oro" % cost
		_context_action.disabled = _gold < cost
		_context_hint.text = "Faltan %d monedas" % (cost - _gold) if _gold < cost else "Una torre por casilla · 3 niveles de mejora"


func _on_context_action() -> void:
	if not is_instance_valid(_slot):
		return
	if _slot.occupied:
		upgrade_requested.emit()
	else:
		build_requested.emit()


func clear_selection() -> void:
	_slot = null
	_context.hide()


func show_message(text: String) -> void:
	_message.text = text
	_message.add_theme_color_override("font_color", CREAM)
	_notice_time = 3.5


func announce_wave(number: int, total: int) -> void:
	show_message("OLEADA %d / %d · ¡Defiende la fortaleza!" % [number, total])
	_message.add_theme_color_override("font_color", GOLD)


func set_sound_muted(value: bool) -> void:
	_sound_muted = value
	if is_instance_valid(_sound_button):
		_sound_button.text = "Sonido: desactivado" if value else "Sonido: activado"
		_sound_button.tooltip_text = "Activar efectos de sonido" if value else "Silenciar efectos de sonido"


func flash_castle_damage(amount: int) -> void:
	if amount <= 0 or not is_instance_valid(_health_value):
		return
	_health_flash_remaining = 0.45
	_health_value.pivot_offset = _health_value.size * 0.5
	_health_value.add_theme_color_override("font_color", Color("ff8a68"))
	_health_value.scale = Vector2.ONE * 1.10


func set_paused(value: bool) -> void:
	_paused = value
	if _result_shown:
		return
	_overlay.visible = value
	_overlay_title.text = "PAUSA"
	_overlay_description.text = "Respira. Tu fortaleza te espera."
	_resume_button.show()


func show_result(victory: bool) -> void:
	_result_shown = true
	_context.hide()
	_overlay.show()
	_resume_button.hide()
	_overlay_title.text = "¡VICTORIA!" if victory else "FORTALEZA CAÍDA"
	_overlay_title.add_theme_color_override("font_color", GOLD if victory else Color("ef9d88"))
	_overlay_description.text = "Resististe las cinco oleadas.\nEl valle vuelve a estar a salvo." if victory else "Los esqueletos atravesaron tus defensas.\nConstruye, mejora y vuelve a intentarlo."
	_wave_button.disabled = true
	_pause_button.disabled = true


func _apply_safe_area() -> void:
	if not is_instance_valid(_safe_top):
		return
	var left := 16
	var right := 16
	var top := 16
	var bottom := 16
	if OS.get_name() in ["Android", "iOS"]:
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var viewport_size := get_viewport().get_visible_rect().size
		if screen.x > 0 and screen.y > 0 and safe.size.x > 0:
			var scale_x := viewport_size.x / float(screen.x)
			var scale_y := viewport_size.y / float(screen.y)
			left += ceili(safe.position.x * scale_x)
			right += ceili((screen.x - safe.end.x) * scale_x)
			top += ceili(safe.position.y * scale_y)
			bottom += ceili((screen.y - safe.end.y) * scale_y)
	_safe_top.add_theme_constant_override("margin_left", left)
	_safe_top.add_theme_constant_override("margin_right", right)
	_safe_top.add_theme_constant_override("margin_top", top)
	_safe_bottom.add_theme_constant_override("margin_left", left)
	_safe_bottom.add_theme_constant_override("margin_right", right)
	_safe_bottom.add_theme_constant_override("margin_bottom", bottom)


func _stat(parent: HBoxContainer, title: String, value: String, color: Color) -> Label:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 0)
	parent.add_child(box)
	var title_label := _label(title, 15, MUTED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var value_label := _label(value, 26, color)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value_label)
	return value_label


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 90
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color("8ca3a8"))
	button.add_theme_stylebox_override("normal", _style(accent, accent.lightened(0.15), 10, 10))
	button.add_theme_stylebox_override("hover", _style(accent.lightened(0.12), CREAM, 10, 10))
	button.add_theme_stylebox_override("pressed", _style(accent.darkened(0.16), accent, 10, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("28434c"), EDGE, 10, 10))
	return button


func _panel(color: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _style(color, EDGE, 14, padding))
	return panel


func _style(background: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style


func _make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", CREAM)
	return theme


func reset_hud() -> void:
	_result_shown = false
	_paused = false
	_notice_time = 0.0
	_health_flash_remaining = 0.0
	_health_value.scale = Vector2.ONE
	_health_value.add_theme_color_override("font_color", _health_color)
	_slot = null
	_tower_levels = []
	_context.hide()
	_overlay.hide()
	_resume_button.show()
	_pause_button.disabled = false
	_wave_button.disabled = false
	_message.text = "Toca una casilla + para construir"
	_message.add_theme_color_override("font_color", CREAM)
	set_sound_muted(_sound_muted)
	_overlay_title.remove_theme_color_override("font_color")
