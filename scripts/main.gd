extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EXTRACTION_POINT := Vector3(11, 0, -11)

var player: CharacterBody3D
var camera: Camera3D
var move_buttons := {"left": false, "right": false, "up": false, "down": false}
var loot_items: Array[Node3D] = []
var loot_count := 0
var loot_value := 0
var status_label: Label
var inventory_label: Label
var extracted := false

var ground_material := StandardMaterial3D.new()
var wall_material := StandardMaterial3D.new()
var player_material := StandardMaterial3D.new()
var bot_material := StandardMaterial3D.new()
var loot_material := StandardMaterial3D.new()
var extract_material := StandardMaterial3D.new()

func _ready() -> void:
	_setup_materials()
	_build_world()
	_build_player()
	_build_targets()
	_build_loot()
	_build_hud()
	_update_hud("Собери припасы и эвакуируйся через зелёную площадку.")

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or extracted:
		return
	var x := float(move_buttons["right"]) - float(move_buttons["left"])
	var y := float(move_buttons["down"]) - float(move_buttons["up"])
	player.touch_move = Vector2(x, y).normalized()

func _setup_materials() -> void:
	ground_material.albedo_color = Color("26343a")
	wall_material.albedo_color = Color("59656a")
	player_material.albedo_color = Color("4d8c76")
	bot_material.albedo_color = Color("b35c43")
	loot_material.albedo_color = Color("e8bb53")
	extract_material.albedo_color = Color("55c9a0")

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8ca5ad")
	environment.ambient_light_energy = 0.55
	world_env.environment = environment
	add_child(world_env)

	_add_box("Ground", Vector3(0, -0.5, 0), Vector3(42, 1, 42), ground_material)
	_add_box("Depot A", Vector3(-6, 1.2, -4), Vector3(5, 2.4, 2), wall_material)
	_add_box("Depot B", Vector3(5, 1.2, -7), Vector3(2, 2.4, 6), wall_material)
	_add_box("Cover 1", Vector3(-2, 0.65, 3), Vector3(3, 1.3, 1), wall_material)
	_add_box("Cover 2", Vector3(7, 0.65, 2), Vector3(1, 1.3, 4), wall_material)
	_add_box("Crate 1", Vector3(2, 0.6, -1), Vector3(1.2, 1.2, 1.2), wall_material)
	_add_box("Crate 2", Vector3(-9, 0.6, 5), Vector3(1.2, 1.2, 1.2), wall_material)

	var extraction := MeshInstance3D.new()
	extraction.name = "ExtractionPoint"
	var ring := CylinderMesh.new()
	ring.top_radius = 2.4
	ring.bottom_radius = 2.4
	ring.height = 0.12
	extraction.mesh = ring
	extraction.material_override = extract_material
	extraction.position = Vector3(EXTRACTION_POINT.x, 0.08, EXTRACTION_POINT.z)
	add_child(extraction)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1, 8)
	player.set_script(PlayerScript)
	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.42
	capsule_shape.height = 1.8
	collision.shape = capsule_shape
	player.add_child(collision)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.42
	capsule_mesh.height = 1.8
	mesh.mesh = capsule_mesh
	mesh.material_override = player_material
	player.add_child(mesh)
	add_child(player)
	camera = player.camera

func _build_targets() -> void:
	_add_target(Vector3(-8, 1, -8), "Practice marker 1")
	_add_target(Vector3(7, 1, -2), "Practice marker 2")
	_add_target(Vector3(1, 1, -12), "Practice marker 3")

func _add_target(at: Vector3, target_name: String) -> void:
	var target := StaticBody3D.new()
	target.name = target_name
	target.position = at
	target.add_to_group("targets")
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	shape_node.shape = shape
	target.add_child(shape_node)
	var visual := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	visual.mesh = mesh
	visual.material_override = bot_material
	target.add_child(visual)
	add_child(target)

func _build_loot() -> void:
	_add_loot(Vector3(-4, 0.45, 0), "Медная шестерня", 120)
	_add_loot(Vector3(4, 0.45, -9), "Полевой аккумулятор", 250)
	_add_loot(Vector3(9, 0.45, 6), "Запечатанный контейнер", 400)

func _add_loot(at: Vector3, item_name: String, value: int) -> void:
	var item := MeshInstance3D.new()
	item.name = "Loot_" + item_name
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	item.mesh = mesh
	item.material_override = loot_material
	item.position = at
	item.set_meta("loot_name", item_name)
	item.set_meta("loot_value", value)
	add_child(item)
	loot_items.append(item)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)

	var title := Label.new()
	title.text = "СЕВЕРНЫЙ РЕЙД  •  тренировочная вылазка"
	title.position = Vector2(22, 14)
	title.add_theme_font_size_override("font_size", 24)
	ui.add_child(title)

	status_label = Label.new()
	status_label.position = Vector2(22, 52)
	status_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(status_label)

	inventory_label = Label.new()
	inventory_label.position = Vector2(22, 82)
	inventory_label.add_theme_font_size_override("font_size", 18)
	ui.add_child(inventory_label)

	_add_action_button(ui, "↑", Vector2(108, -174), Vector2(76, 64), func(): _set_move("up", true), func(): _set_move("up", false))
	_add_action_button(ui, "←", Vector2(26, -100), Vector2(76, 64), func(): _set_move("left", true), func(): _set_move("left", false))
	_add_action_button(ui, "↓", Vector2(108, -100), Vector2(76, 64), func(): _set_move("down", true), func(): _set_move("down", false))
	_add_action_button(ui, "→", Vector2(190, -100), Vector2(76, 64), func(): _set_move("right", true), func(): _set_move("right", false))
	_add_action_button(ui, "ТРЕНИРОВКА", Vector2(-190, -104), Vector2(166, 68), func(): try_shoot(), func(): pass)
	_add_action_button(ui, "ПОДОБРАТЬ", Vector2(-190, -184), Vector2(166, 62), func(): pick_up_loot(), func(): pass)
	_add_action_button(ui, "ЭВАКУАЦИЯ", Vector2(-190, -258), Vector2(166, 62), func(): try_extract(), func(): pass)

func _add_action_button(parent: Control, text: String, offset: Vector2, button_size: Vector2, on_down: Callable, on_up: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size = button_size
	button.anchor_left = 0.0 if offset.x >= 0 else 1.0
	button.anchor_right = button.anchor_left
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.position = offset
	button.add_theme_font_size_override("font_size", 18)
	button.button_down.connect(on_down)
	button.button_up.connect(on_up)
	parent.add_child(button)

func _set_move(direction: String, active: bool) -> void:
	move_buttons[direction] = active

func try_shoot() -> void:
	if extracted or not is_instance_valid(camera):
		return
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(screen_center)
	var direction := camera.project_ray_normal(screen_center)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 80.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_update_hud("Мимо тренировочной мишени — наведи центр экрана.")
		return
	var collider: Object = hit.get("collider")
	if collider is Node and collider.is_in_group("targets"):
		collider.queue_free()
		_update_hud("Мишень сбита. Это тренировочная цель — она не атакует.")
	else:
		_update_hud("Попадание в укрытие. Игроку ничего не угрожает.")

func pick_up_loot() -> void:
	if extracted:
		return
	for item in loot_items:
		if is_instance_valid(item) and player.global_position.distance_to(item.global_position) < 2.5:
			var item_name: String = item.get_meta("loot_name", "Припасы")
			var item_value: int = item.get_meta("loot_value", 0)
			item.queue_free()
			loot_count += 1
			loot_value += item_value
			_update_hud("Подобрано: %s. Теперь направляйся к зелёной точке." % item_name)
			return
	_update_hud("Рядом нет добычи. Ищи золотые предметы.")

func try_extract() -> void:
	if extracted:
		return
	if player.global_position.distance_to(EXTRACTION_POINT) > 3.5:
		_update_hud("Ты ещё не у точки эвакуации — ищи зелёный круг.")
		return
	if loot_count == 0:
		_update_hud("Эвакуация доступна после того, как подберёшь хотя бы один предмет.")
		return
	extracted = true
	player.touch_move = Vector2.ZERO
	_update_hud("ВЫЛАЗКА УСПЕШНА! Вывезено предметов: %d." % loot_count)

func _update_hud(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
	if is_instance_valid(inventory_label):
		inventory_label.text = "Добыча: %d предмет(а)  •  ценность: %d" % [loot_count, loot_value]

func _add_box(box_name: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = box_name
	body.position = at
	var collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = dimensions
	collision.shape = box_shape
	body.add_child(collision)
	var visual := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = dimensions
	visual.mesh = box_mesh
	visual.material_override = material
	body.add_child(visual)
	add_child(body)
