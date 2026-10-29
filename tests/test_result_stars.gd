extends SceneTree
## Result rendering regression: no optional font glyph and no repeated award.
var checks: int = 0
var failures: int = 0
var elapsed: float = 0

func _initialize() -> void:
	call_deferred("_run")

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 12:
		push_error("Dewdrop result star test exceeded its 12-second deadline")
		quit(1)
	return false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _labels(parent: Node) -> Array[Label]:
	var found: Array[Label] = []
	for child: Node in parent.get_children():
		if child is Label: found.append(child)
		found.append_array(_labels(child))
	return found

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--qa-isolated"):
		push_error("Isolated test data is required."); quit(2); return
	var game: Control = load("res://main.tscn").instantiate()
	game.demo = true
	root.add_child(game)
	await process_frame; await process_frame
	var banked: Array = [game.model.coins, game.model.xp, game.model.records.duplicate(true)]
	for viewport_size: Vector2i in [Vector2i(540, 960), Vector2i(1280, 720)]:
		root.size = viewport_size
		for stars: int in range(1, 4):
			game.pulse_result = {"success": true, "stars": stars, "consumed": 4, "left": 1, "supply": 5}
			game.receipt = {"coins": 40, "xp": 35}
			game._show("result")
			await process_frame; await process_frame
			var row: HBoxContainer = game.stage.get_node("ResultStars")
			var count_label: Label = game.stage.get_node("ResultStarCount")
			check(row.get_child_count() == stars, "Each earned star has a result icon")
			check(count_label.text == "%d of 3 stars" % stars, "The award has a readable numeric star count")
			var previous_end: float = row.get_global_rect().position.x
			for icon: TextureRect in row.get_children():
				check(icon.texture != null and icon.texture.get_width() > 0, "Earned icon loads a real image rather than a font glyph")
				var icon_rect: Rect2 = icon.get_global_rect()
				check(row.get_global_rect().encloses(icon_rect), "Star icon fits the result row at each viewport size")
				check(icon_rect.position.x >= previous_end, "Adjacent award icons do not overlap")
				previous_end = icon_rect.end.x
			check(row.get_global_rect().end.y <= count_label.get_global_rect().position.y, "Numeric count clears the icon row")
			for label: Label in _labels(game.stage):
				check(not label.text.contains(String.chr(0x2605)), "Result does not rely on the unavailable star glyph")
			check([game.model.coins, game.model.xp, game.model.records] == banked, "Rendering an award never banks rewards again")
	game.pulse_result = {"success": false, "stars": 0, "consumed": 0, "left": 5, "supply": 5, "deficit": {}}
	game.receipt = {}
	game._show("result")
	await process_frame
	check(not game.stage.has_node("ResultStars"), "A failed attempt does not display earned star icons")
	var failure_copy: bool = false
	for label: Label in _labels(game.stage):
		if label.text == "TRY ANOTHER ROUTE": failure_copy = true
	check(failure_copy, "Failure guidance is retained")
	root.remove_child(game); game.free()
	await process_frame
	print("DEWDROP_RESULT_STARS: %d checks; %d failures; image icons, readable count and unchanged rewards" % [checks, failures])
	quit(0 if failures == 0 else 1)
