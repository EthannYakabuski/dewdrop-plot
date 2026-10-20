extends SceneTree
var checks: int = 0
var failures: int = 0
var elapsed: float = 0

class MenuServices extends Node:
	signal menu_bottom_reserve_changed
	var reserve: float = 160
	var visible: bool = false
	func set_menu_visible(value: bool) -> void: visible = value
	func menu_bottom_reserve(_reference: CanvasItem = null) -> float: return reserve if visible else 0
	func status() -> String: return "Layout fixture; no native ads or rewards."

class LayoutGame extends "res://game/main.gd":
	var fixture: Node
	func _services() -> Node: return fixture

func _initialize() -> void:
	call_deferred("_run")

func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 10:
		push_error("Menu layout test exceeded its 10-second deadline")
		quit(1)
	return false

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)

func _buttons(parent: Node) -> Array:
	var out: Array = []
	for child: Node in parent.get_children():
		if child is Button: out.append(child)
		out.append_array(_buttons(child))
	return out

func _geometry(game: Control, reserve: float) -> void:
	var bottom: float = game.stage.global_position.y + (960 - reserve - 12) * game.stage.scale.y
	var buttons: Array = _buttons(game.home_content)
	check(buttons.size() == 6, "Home actions missing from layout fixture")
	for button: Button in buttons:
		var rect: Rect2 = button.get_global_rect()
		check(rect.end.y <= bottom + 0.1, "Home action overlaps the actual reserved menu area: " + button.text)
		check(rect.size.y >= 44 * game.stage.scale.y, "Home action shrank below a usable touch height: " + button.text)

func _run() -> void:
	var fixture: Node = MenuServices.new()
	var game: Control = LayoutGame.new(); game.fixture = fixture; game.demo = true
	root.add_child(game)
	await process_frame; await process_frame
	_geometry(game, 160)
	var existing_home: int = game.home_content.get_instance_id()
	fixture.reserve = 180; fixture.menu_bottom_reserve_changed.emit()
	await process_frame; await process_frame
	_geometry(game, 180)
	check(game.home_content.get_instance_id() == existing_home, "Banner signal rebuilt the home menu")
	game._start(0); await process_frame
	game.model.edit_edge(21, 22)
	var existing_board: int = game.board.get_instance_id()
	fixture.reserve = 220; fixture.menu_bottom_reserve_changed.emit()
	await process_frame; await process_frame
	check(game.board.get_instance_id() == existing_board and game.model.edges.size() == 1, "Banner callback reset gameplay or lost a plan")
	game._show("home"); await process_frame; await process_frame
	fixture.reserve = 0; fixture.menu_bottom_reserve_changed.emit()
	await process_frame; await process_frame
	_geometry(game, 0)
	check(is_equal_approx(game.home_content.scale.y, 1), "Unavailable banner left an unnecessary menu gap")
	root.remove_child(game); game.free(); fixture.free()
	await process_frame
	print("DEWDROP_MENU_LAYOUT: %d checks; %d failures; 160/180 reserve, live refit and retained gameplay" % [checks, failures])
	quit(0 if failures == 0 else 1)
