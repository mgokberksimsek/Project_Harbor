extends Sprite2D

@export var speed: float = 250.0

var target_position: Vector2

func _ready():
	target_position = global_position

func _process(delta):
	global_position = global_position.move_toward(target_position, speed * delta)

func move_to(pos: Vector2):
	target_position = pos
