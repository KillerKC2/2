extends CanvasLayer

const PORT := 2456
const MAX_PEERS := 4
const LOCAL_NICK_DEFAULT := "KillerKC2"

var peer: ENetMultiplayerPeer
var panel: PanelContainer
var address_input: LineEdit
var nick_input: LineEdit
var status_label: Label
var remote_players: Dictionary = {}
var last_sent_position := Vector3.ZERO
var send_elapsed := 0.0
var local_nick := LOCAL_NICK_DEFAULT

func _ready() -> void:
	_build_network_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	send_elapsed += delta
	if send_elapsed < 0.1:
		return
	send_elapsed = 0.0
	var local_player: Variant = get_parent().get("player")
	if not local_player is Node3D:
		return
	var position: Vector3 = local_player.global_position
	if position.distance_squared_to(last_sent_position) < 0.0025:
		return
	last_sent_position = position
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return
	if multiplayer.is_server():
		rpc("_receive_position", 1, position)
	else:
		rpc_id(1, "_submit_position", position)

func _build_network_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var toggle := Button.new()
	toggle.text = "ЛОКАЛЬНАЯ СЕТЬ"
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.offset_left = -220
	toggle.offset_right = -20
	toggle.offset_top = 18
	toggle.offset_bottom = 66
	toggle.pressed.connect(func(): panel.visible = not panel.visible)
	ui.add_child(toggle)

	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -360
	panel.offset_right = -20
	panel.offset_top = 76
	panel.offset_bottom = 340
	panel.visible = false
	ui.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var title := Label.new()
	title.text = "Совместная игра по Wi-Fi"
	title.add_theme_font_size_override("font_size", 19)
	column.add_child(title)

	nick_input = LineEdit.new()
	nick_input.text = LOCAL_NICK_DEFAULT
	nick_input.placeholder_text = "Твой ник"
	column.add_child(nick_input)

	address_input = LineEdit.new()
	address_input.text = "192.168.1.10"
	address_input.placeholder_text = "IP телефона-хоста"
	column.add_child(address_input)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var host_button := Button.new()
	host_button.text = "Создать"
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(host_game)
	buttons.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "Подключиться"
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(join_game)
	buttons.add_child(join_button)

	var leave_button := Button.new()
	leave_button.text = "Отключиться"
	leave_button.pressed.connect(leave_game)
	column.add_child(leave_button)

	status_label = Label.new()
	status_label.text = "Офлайн. Можно играть одному без интернета."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status_label)

func host_game() -> void:
	local_nick = _read_nick()
	_leave_peer_only()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PEERS)
	if error != OK:
		_set_status("Не удалось создать комнату (ошибка %d)." % error)
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Комната создана на порту %d. Сообщи брату IP этого телефона." % PORT)

func join_game() -> void:
	local_nick = _read_nick()
	var address := address_input.text.strip_edges()
	if address.is_empty():
		_set_status("Введи локальный IP телефона, который создал комнату.")
		return
	_leave_peer_only()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		_set_status("Не удалось начать подключение (ошибка %d). Проверь IP и Wi-Fi." % error)
		return
	multiplayer.multiplayer_peer = peer
	_set_status("Подключаюсь к %s:%d…" % [address, PORT])

func leave_game() -> void:
	_leave_peer_only()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for peer_id in remote_players.keys():
		_remove_remote_player(int(peer_id))
	_set_status("Отключено. Одиночная игра доступна офлайн.")

func _leave_peer_only() -> void:
	if peer != null:
		peer.close()
	peer = null

func _read_nick() -> String:
	var value := nick_input.text.strip_edges()
	if value.is_empty():
		return LOCAL_NICK_DEFAULT
	return value.left(20)

func _on_peer_connected(peer_id: int) -> void:
	_set_status("Игрок подключился (ID %d). Ждём обновления позиции." % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	_remove_remote_player(peer_id)
	_set_status("Игрок %d отключился." % peer_id)

func _on_connected_to_server() -> void:
	_set_status("Подключено к комнате. Вы в локальной сети.")

func _on_connection_failed() -> void:
	_set_status("Не удалось подключиться. Проверьте, что оба телефона в одной Wi-Fi сети и хост открыт.")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _on_server_disconnected() -> void:
	_set_status("Хост отключился. Возвращаемся в офлайн.")
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for peer_id in remote_players.keys():
		_remove_remote_player(int(peer_id))

@rpc("any_peer", "call_remote", "unreliable")
func _submit_position(position: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 1:
		return
	rpc("_receive_position", sender_id, position)

@rpc("authority", "call_remote", "unreliable")
func _receive_position(peer_id: int, position: Vector3) -> void:
	_set_remote_position(peer_id, position)

func _set_remote_position(peer_id: int, position: Vector3) -> void:
	if peer_id == multiplayer.get_unique_id():
		return
	var avatar: Node3D = remote_players.get(peer_id)
	if not is_instance_valid(avatar):
		avatar = _create_remote_player(peer_id)
		remote_players[peer_id] = avatar
	avatar.position = position

func _create_remote_player(peer_id: int) -> Node3D:
	var avatar := Node3D.new()
	avatar.name = "LANPlayer_%d" % peer_id
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	body.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("55a9db")
	body.material_override = material
	avatar.add_child(body)
	var name_tag := Label3D.new()
	name_tag.text = "Игрок %d" % peer_id
	name_tag.position = Vector3(0, 1.4, 0)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	avatar.add_child(name_tag)
	get_parent().add_child(avatar)
	return avatar

func _remove_remote_player(peer_id: int) -> void:
	var avatar: Node3D = remote_players.get(peer_id)
	if is_instance_valid(avatar):
		avatar.queue_free()
	remote_players.erase(peer_id)

func _set_status(message: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = message
	var root := get_parent()
	if root.has_method("_update_hud"):
		root.call("_update_hud", message)
