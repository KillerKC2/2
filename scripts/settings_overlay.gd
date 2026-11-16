extends CanvasLayer

var panel: PanelContainer
var gyro_toggle: CheckButton
var sensitivity_slider: HSlider
var quality_status: Label
var atmosphere_toggle: CheckButton
var root_game: Node

func _ready() -> void:
	root_game = get_parent()
	_build_ui()
	_apply_quality("Средняя")

func _build_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var open_button := Button.new()
	open_button.text = "НАСТРОЙКИ"
	open_button.position = Vector2(18, 176)
	open_button.size = Vector2(170, 52)
	open_button.pressed.connect(func(): panel.visible = not panel.visible)
	ui.add_child(open_button)

	panel = PanelContainer.new()
	panel.position = Vector2(205, 100)
	panel.size = Vector2(420, 470)
	panel.visible = false
	ui.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Настройки управления и графики"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)

	var quality_title := Label.new()
	quality_title.text = "Графика (можно менять во время игры)"
	column.add_child(quality_title)

	var quality_buttons := HBoxContainer.new()
	column.add_child(quality_buttons)
	for quality in ["Низкая", "Средняя", "Высокая"]:
		var button := Button.new()
		button.text = quality
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_apply_quality.bind(quality))
		quality_buttons.add_child(button)

	quality_status = Label.new()
	quality_status.text = ""
	quality_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(quality_status)

	gyro_toggle = CheckButton.new()
	gyro_toggle.text = "Включить гироскоп для прицеливания"
	gyro_toggle.toggled.connect(_set_gyro_enabled)
	column.add_child(gyro_toggle)

	var sensitivity_title := Label.new()
	sensitivity_title.text = "Чувствительность гироскопа"
	column.add_child(sensitivity_title)

	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 0.2
	sensitivity_slider.max_value = 3.0
	sensitivity_slider.step = 0.1
	sensitivity_slider.value = 1.0
	sensitivity_slider.value_changed.connect(_set_gyro_sensitivity)
	column.add_child(sensitivity_slider)

	atmosphere_toggle = CheckButton.new()
	atmosphere_toggle.text = "Мрачная атмосфера (без графического насилия)"
	atmosphere_toggle.toggled.connect(_set_atmosphere)
	column.add_child(atmosphere_toggle)

	var note := Label.new()
	note.text = "Гироскоп доступен только на устройствах с датчиком. Если управление дёргается, уменьши чувствительность или выключи его."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)

	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.pressed.connect(func(): panel.visible = false)
	column.add_child(close_button)

func _player() -> Node:
	if is_instance_valid(root_game):
		return root_game.get("player")
	return null

func _set_gyro_enabled(enabled: bool) -> void:
	var target := _player()
	if target != null and is_instance_valid(target):
		target.set("gyro_enabled", enabled)
	
func _set_gyro_sensitivity(value: float) -> void:
	var target := _player()
	if target != null and is_instance_valid(target):
		target.set("gyro_sensitivity", value)

func _apply_quality(preset: String) -> void:
	var viewport := get_viewport()
	var environment_node := root_game.get_node_or_null("WorldEnvironment") if is_instance_valid(root_game) else null
	var environment: Environment = environment_node.environment if environment_node is WorldEnvironment else null
	match preset:
		"Низкая":
			viewport.scaling_3d_scale = 0.72
			Engine.max_fps = 30
			if environment:
				environment.glow_enabled = false
				environment.ssao_enabled = false
			quality_status.text = "Низкая: уменьшено внутреннее разрешение, отключены тяжёлые эффекты, лимит 30 кадров/с."
		"Высокая":
			viewport.scaling_3d_scale = 1.0
			Engine.max_fps = 60
			if environment:
				environment.glow_enabled = true
				environment.ssao_enabled = true
			quality_status.text = "Высокая: полное разрешение и дополнительные эффекты, лимит 60 кадров/с."
		_:
			viewport.scaling_3d_scale = 0.88
			Engine.max_fps = 45
			if environment:
				environment.glow_enabled = false
				environment.ssao_enabled = false
			quality_status.text = "Средняя: сбалансированное разрешение, лимит 45 кадров/с."

func _set_atmosphere(enabled: bool) -> void:
	var environment_node := root_game.get_node_or_null("WorldEnvironment") if is_instance_valid(root_game) else null
	if not environment_node is WorldEnvironment:
		return
	var environment: Environment = environment_node.environment
	if enabled:
		environment.ambient_light_color = Color("59656f")
		environment.ambient_light_energy = 0.35
	else:
		environment.ambient_light_color = Color("8ca5ad")
		environment.ambient_light_energy = 0.55
