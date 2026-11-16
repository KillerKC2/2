extends CharacterBody3D

@export var speed: float = 5.0
var touch_move: Vector2 = Vector2.ZERO
var camera: Camera3D

func _ready() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.7, 7.0)
	camera.rotation_degrees = Vector3(-22, 0, 0)
	camera.current = true
	add_child(camera)

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
