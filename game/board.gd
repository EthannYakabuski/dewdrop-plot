class_name DewBoard
extends Control

signal edge_requested(a: int, b: int, erase: bool)
signal gate_requested(cell: int)
const Model = preload("res://game/model.gd")
var model: RefCounted
var textures: Dictionary = {}
var erase_mode: bool = false
var interactive: bool = true
var pulsing: bool = false
var pulse_progress: float = 0.0
var result: Dictionary = {}
var pointer_cell: int = -1
var pointer_down: bool = false
var hovered: int = -1
var animation_time: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id: int in [4, 6, 8, 16, 18, 20, 28, 30, 32, 40, 42, 44, 52, 54, 56, 64, 66, 68, 73, 77, 83, 84, 89, 98, 109]:
		textures[id] = load("res://assets/farm/%d.png" % id)

func _process(delta: float) -> void:
	animation_time += delta
	if pulsing: queue_redraw()

func tile_center(cell: int) -> Vector2:
	return Vector2(cell % 7 + 0.5, int(cell / 7) + 0.5) * size.x / 7.0

func cell_at(position: Vector2) -> int:
	var side: float = size.x / 7.0
	var x: int = int(floor(position.x / side)); var y: int = int(floor(position.y / side))
	return y * 7 + x if x >= 0 and x < 7 and y >= 0 and y < 7 else -1

func _gui_input(event: InputEvent) -> void:
	if not interactive or model == null: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin(event.position)
		else: _end()
		accept_event()
	elif event is InputEventMouseMotion and pointer_down:
		_drag(event.position); accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed: _begin(event.position)
		else: _end()
		accept_event()
	elif event is InputEventScreenDrag and pointer_down:
		_drag(event.position); accept_event()

func _begin(position: Vector2) -> void:
	pointer_cell = cell_at(position); pointer_down = pointer_cell >= 0
	hovered = pointer_cell
	if pointer_cell in model.plot.gates: gate_requested.emit(pointer_cell)
	queue_redraw()

func _drag(position: Vector2) -> void:
	var next: int = cell_at(position)
	if next < 0: return
	if pointer_cell < 0: pointer_cell = next
	# Sparse touch events are interpolated across orthogonal grid cells.
	var guard: int = 0
	while pointer_cell != next and guard < 14:
		guard += 1
		var dx: int = next % 7 - pointer_cell % 7
		var dy: int = int(next / 7) - int(pointer_cell / 7)
		var step: int = pointer_cell + (signi(dx) if dx != 0 else signi(dy) * 7)
		edge_requested.emit(pointer_cell, step, erase_mode)
		pointer_cell = step
	hovered = next; queue_redraw()

func _end() -> void:
	pointer_down = false; pointer_cell = -1; hovered = -1; queue_redraw()

func _pixel_rect(rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> void:
	draw_rect(rect, color)
	if border.a > 0: draw_rect(rect, border, false, 2)

func _sprite(id: int, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if textures.has(id): draw_texture_rect(textures[id], rect, false, tint)

func _text(value: String, at: Vector2, font_size: int, color: Color, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, at, value, align, width, font_size, color)

func _drop(at: Vector2, scale_factor: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(0, -9), Vector2(7, 1), Vector2(6, 7), Vector2(0, 10), Vector2(-6, 7), Vector2(-7, 1)])
	for i: int in range(points.size()): points[i] = at + points[i] * scale_factor
	draw_colored_polygon(points, color)

func _draw() -> void:
	if model == null or model.plot.is_empty(): return
	var palette: Dictionary = Model.STYLES[model.style]
	var grass: Color = Color(palette.grass); var soil: Color = Color(palette.soil)
	var side: float = size.x / 7.0
	var crop_cells: Dictionary = {}
	for crop: Dictionary in model.plot.crops: crop_cells[int(crop.cell)] = crop
	var water_cells: Array = result.get("wet", [])
	var max_distance: int = 1
	for value: Variant in result.get("distance", {}).values(): max_distance = maxi(max_distance, int(value))
	var reached: int = int(ceil(pulse_progress * max_distance))
	_pixel_rect(Rect2(Vector2.ZERO, size), grass, Color("63875a"))
	for cell: int in range(49):
		var corner: Vector2 = tile_center(cell) - Vector2.ONE * side * 0.5
		var tone: Color = grass.lightened(0.035) if (cell % 7 + int(cell / 7)) % 2 == 0 else grass.darkened(0.025)
		draw_rect(Rect2(corner + Vector2.ONE, Vector2.ONE * (side - 2)), tone)
		draw_rect(Rect2(corner, Vector2.ONE * side), Color("789e63"), false, 1)
		# Hand-placed tufts make empty ground legible without visual noise.
		if cell not in crop_cells and cell not in model.plot.rocks:
			draw_rect(Rect2(corner + Vector2(12 + cell % 3 * 11, 15 + cell % 4 * 8), Vector2(3, 3)), grass.darkened(0.13))
	for pair: Array in Model.pairs_from(model.edges):
		var a: Vector2 = tile_center(int(pair[0])); var b: Vector2 = tile_center(int(pair[1]))
		draw_line(a, b, Color("795e48"), 24, false)
		draw_line(a, b, soil.lightened(0.3), 16, false)
		if pulsing and int(pair[0]) in water_cells and int(pair[1]) in water_cells:
			var distance_a: int = int(result.get("distance", {}).get(str(pair[0]), 999))
			var distance_b: int = int(result.get("distance", {}).get(str(pair[1]), 999))
			if maxi(distance_a, distance_b) <= reached:
				draw_line(a, b, Color(palette.water), 15, false)
				draw_line(a + Vector2(0, -3), b + Vector2(0, -3), Color("bdeff0"), 3, false)
	for crop: Dictionary in model.plot.crops:
		var center: Vector2 = tile_center(int(crop.cell)); var info: Dictionary = Model.CROPS[crop.species]
		var grown: bool = false; var wet_bed: bool = false; var used: int = 0
		for event: Dictionary in result.get("events", []):
			if int(event.cell) == int(crop.cell) and int(event.distance) <= reached and pulsing:
				grown = bool(event.grown); used = int(event.used); wet_bed = used > 0
		var bed_color: Color = soil.darkened(0.1) if not wet_bed else soil.darkened(0.24)
		_pixel_rect(Rect2(center - Vector2(24, 22), Vector2(48, 43)), bed_color)
		draw_line(center + Vector2(-21, 6), center + Vector2(20, 6), soil.lightened(0.14), 2)
		_sprite(int(info.grown) if grown else int(info.seed), Rect2(center - Vector2(26, 31), Vector2(52, 52)))
		_pixel_rect(Rect2(center + Vector2(5, 10), Vector2(25, 20)), Color("246d7d"))
		_drop(center + Vector2(10, 19), 0.48, Color("c7f0ed"))
		_text(str(int(crop.cost)), center + Vector2(16, 26), 14, Color.WHITE)
		if bool(crop.wanted):
			_pixel_rect(Rect2(center + Vector2(13, -28), Vector2(15, 15)), Color("f2c25c"))
			_text("+", center + Vector2(15, -15), 15, Color("664a30"))
		else:
			draw_arc(center + Vector2(19, -21), 5, 0, TAU, 8, Color("6c7350"), 2)
		if grown:
			_text("+1", center + Vector2(-12, -31 - sin(animation_time * 3 + int(crop.cell)) * 2), 16, Color("fff3d4"))
	for rock: Variant in model.plot.rocks:
		_sprite(89, Rect2(tile_center(int(rock)) - Vector2(27, 30), Vector2(54, 54)))
	for source: Dictionary in model.plot.sources:
		var center: Vector2 = tile_center(int(source.cell))
		_pixel_rect(Rect2(center - Vector2(29, 26), Vector2(58, 51)), Color("375c5b"))
		_sprite(73, Rect2(center - Vector2(25, 27), Vector2(50, 50)))
		_pixel_rect(Rect2(center + Vector2(-15, 9), Vector2(31, 23)), Color("246d7d"))
		_text(str(int(source.water)), center + Vector2(-14, 27), 17, Color("fff3d4"), 30, HORIZONTAL_ALIGNMENT_CENTER)
	for gate: Variant in model.plot.gates:
		var center: Vector2 = tile_center(int(gate)); var is_open: bool = int(gate) in model.open_gates
		draw_rect(Rect2(center - Vector2(23, 19), Vector2(7, 40)), Color("70523c"))
		draw_rect(Rect2(center + Vector2(16, -19), Vector2(7, 40)), Color("70523c"))
		if not is_open:
			draw_line(center + Vector2(-20, -12), center + Vector2(20, -12), Color("e3a35b"), 8)
			draw_line(center + Vector2(-20, 4), center + Vector2(20, 4), Color("e3a35b"), 8)
		else: _text("OPEN", center + Vector2(-23, -21), 11, Color("173d3a"), 46, HORIZONTAL_ALIGNMENT_CENTER)
	if hovered >= 0:
		draw_rect(Rect2(tile_center(hovered) - Vector2.ONE * (side * 0.5 - 2), Vector2.ONE * (side - 4)), Color("fff3d4") if not erase_mode else Color("df7566"), false, 3)
