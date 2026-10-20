extends SceneTree
var elapsed: float = 0

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 12:
		push_error("Dewdrop UI smoke exceeded its 12-second deadline")
		quit(1)
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	var game: Control = scene.instantiate()
	game.demo = true
	game.runtime_smoke = true
	root.add_child(game)
