extends Spatial

# Preload your two item scenes
var item_scenes = [
	preload("res://Scenes/Key.tscn"),
	preload("res://Scenes/KeyCard.tscn")
]

onready var spawn_points = [
	$SpawnPoint1,
	$SpawnPoint2
]

func _ready() -> void:
	randomize()
	spawn_random_items()

func spawn_random_items() -> void:
	# Shuffle spawn locations to randomize allotment every run
	spawn_points.shuffle()

	for i in range(item_scenes.size()):
		if i >= spawn_points.size():
			break

		# Instance the scene and place it at the chosen spawn location
		var item = item_scenes[i].instance()
		add_child(item)
		item.global_transform.origin = spawn_points[i].global_transform.origin
