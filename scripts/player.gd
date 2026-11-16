extends CharacterBody3D

@export var speed: float = 5.0
@export var gyro_enabled := false
@export_range(0.1, 4.0, 0.1) var gyro_sensitivity := 1.0
@export_range(-1.0, 1.0, 0.05) var gyro_yaw_sign := -1.0
var touch_move: Vector2 = Vector2.ZERO
var camera: Camera3D
var pitch := deg_to_rad(-22.0)

func _ready() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.7, 7.0)
	pitch = deg_to_rad(-22.0)
	camera.rotation = Vector3(pitch, 0.0, 0.0)
	camera.current = true
	add_child(camera)

func _process(delta: float) -> void:
	if not gyro_enabled or not is_instance_valid(camera):
		return
	var angular_velocity := Input.get_gyroscope()
	if angular_velocity.length_squared() < 0.0001:
		return
	var sensitivity := gyro_sensitivity * delta
	camera.rotation.y = wrapf(camera.rotation.y + angular_velocity.y * sensitivity * gyro_yaw_sign, -PI, PI)
	pitch = clampf(pitch + angular_velocity.x * sensitivity, deg_to_rad(-70.0), deg_to_rad(35.0))
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var movement := touch_move if touch_move.length() > 0.05 else keyboard
	var direction := Vector3(movement.x, 0.0, movement.y).normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	if direction.length() > 0.05:
		rotation.y = atan2(-direction.x, -direction.z)
	move_and_slide()
