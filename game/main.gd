extends Control

const Model = preload("res://game/model.gd")
const Board = preload("res://game/board.gd")
const RESULT_STAR: Texture2D = preload("res://assets/ui/star-gold.svg")
const INK: Color = Color("173d3a")
const CREAM: Color = Color("fff3d4")
const WATER: Color = Color("2c9da7")
const GOLD: Color = Color("f2c25c")
const MUTED: Color = Color("64836b")
const SAVE: String = "user://dewdrop_v1.json"
var model: RefCounted = Model.new()
var stage: Control
var home_content: Control
var home_backdrop: Panel
var board: Control
var screen: String = "home"
var catalog: Dictionary = {}
var textures: Dictionary = {}
var toast_label: Label
var toast_seconds: float = 0
var pulse_result: Dictionary = {}
var receipt: Dictionary = {}
var pulse_time: float = 0
var pulsing: bool = false
var status_label: Label
var water_label: Label
var plan_label: Label
var release_button: Button
var erase_mode: bool = false
var toolbar: Array = []
var sfx: AudioStreamPlayer
var music: AudioStreamPlayer
var autosave: float = 0
var boot_view: String = "home"
var capture_path: String = ""
var demo: bool = false
var runtime_smoke: bool = false

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--demo": demo = true
		if argument == "--runtime-smoke": runtime_smoke = true
		if argument.begins_with("--view="): boot_view = argument.trim_prefix("--view=")
		if argument.begins_with("--capture="): capture_path = argument.trim_prefix("--capture=")
	if not demo: model.load_file(SAVE)
	model.roll_day(Time.get_date_string_from_system(true))
	if demo: _demo_state()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/catalog.json"))
	if parsed is Dictionary: catalog = parsed
	for id: int in [6, 8, 18, 20, 30, 32, 42, 44, 54, 56, 66, 68, 73, 83, 84, 85, 89, 98, 99, 108, 109, 110, 111]: textures[id] = load("res://assets/farm/%d.png" % id)
	sfx = AudioStreamPlayer.new(); add_child(sfx)
	music = AudioStreamPlayer.new(); music.stream = load("res://assets/audio/morning.wav"); music.volume_db = -13
	if music.stream is AudioStreamWAV:
		music.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; music.stream.loop_end = int(music.stream.get_length() * music.stream.mix_rate)
	add_child(music)
	if model.sound and DisplayServer.get_name() != "headless": music.play()
	get_viewport().size_changed.connect(_fit)
	var service: Node = _services()
	if service != null and service.has_signal("menu_bottom_reserve_changed"):
		service.connect("menu_bottom_reserve_changed", _menu_reserve_changed)
	_sync(); _show(boot_view)
	if not capture_path.is_empty(): _capture()
	if runtime_smoke: _runtime_smoke()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST: _save()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not pulsing: _show("home")

func _exit_tree() -> void:
	_stop_audio()

func _stop_audio() -> void:
	if is_instance_valid(music): music.stop(); music.stream = null
	if is_instance_valid(sfx): sfx.stop(); sfx.stream = null

func _process(delta: float) -> void:
	if toast_seconds > 0:
		toast_seconds -= delta
		if is_instance_valid(toast_label): toast_label.visible = toast_seconds > 0
	autosave += delta
	if autosave > 8: autosave = 0; _save()
	if pulsing and is_instance_valid(board):
		pulse_time += delta; board.pulse_progress = minf(1, pulse_time / 2.8)
		var max_distance: int = 1
		for value: Variant in pulse_result.distance.values(): max_distance = maxi(max_distance, int(value))
		var visible_used: int = 0
		for event: Dictionary in pulse_result.events:
			if int(event.distance) <= int(ceil(board.pulse_progress * max_distance)): visible_used += int(event.used)
		if is_instance_valid(water_label): water_label.text = "%d / %d drops" % [int(pulse_result.supply) - visible_used, int(pulse_result.supply)]
		if pulse_time >= 2.8: _finish_pulse()

func _fit() -> void:
	if not is_instance_valid(stage): return
	var available: Vector2 = get_viewport_rect().size
	var factor: float = minf(available.x / 540, available.y / 960)
	stage.scale = Vector2.ONE * factor; stage.position = (available - Vector2(540, 960) * factor) * 0.5
	_fit_home()

func _menu_reserve_changed() -> void:
	# Banner callbacks only refit the existing menu; they never rebuild a puzzle.
	if screen == "home": call_deferred("_fit_home")

func _fit_home() -> void:
	if screen != "home" or not is_instance_valid(home_content): return
	var reserve: float = 0
	var service: Node = _services()
	if service != null and service.has_method("menu_bottom_reserve"):
		reserve = maxf(0, float(service.call("menu_bottom_reserve", stage)))
	var factor: float = clampf((960.0 - reserve - 12.0) / 916.0, 0.4, 1.0)
	home_content.scale = Vector2.ONE * factor
	home_content.position = Vector2((540.0 - 540.0 * factor) * 0.5, 0)
	if is_instance_valid(home_backdrop): home_backdrop.size.y = 464.0 * factor

func _show(view: String) -> void:
	if pulsing: return
	screen = view; toast_label = null; board = null; toolbar = []; home_content = null; home_backdrop = null
	if is_instance_valid(stage):
		stage.hide()
		stage.queue_free()
	stage = Control.new(); stage.size = Vector2(540, 960); add_child(stage)
	_panel(Rect2(0, 0, 540, 960), CREAM, 0)
	match view:
		"play", "game": _play_screen()
		"levels": _levels()
		"daily": _daily()
		"garden": _garden()
		"journal": _journal()
		"settings": _settings()
		"result": _result_screen()
		_: screen = "home"; _home()
	if screen == "home":
		var nodes: Array[Node] = stage.get_children()
		home_content = Control.new(); home_content.size = Vector2(540, 916); stage.add_child(home_content)
		for child: Node in nodes:
			if child != nodes[0] and child != home_backdrop: child.reparent(home_content, false)
	if screen != "home" and screen != "play" and screen != "game": _button("‹ Home", Rect2(24, 909, 117, 40), func(): _show("home"), true)
	_fit()
	var service: Node = _services()
	if service != null: service.call("set_menu_visible", screen == "home")
	if screen == "home": call_deferred("_fit_home")
	_save()

func _header(title: String, subtitle: String) -> void:
	_label(title, Rect2(25, 25, 490, 43), 29, INK)
	_label(subtitle, Rect2(27, 75, 486, 46), 16, MUTED)

func _home() -> void:
	home_backdrop = _panel(Rect2(0, 0, 540, 464), INK, 0)
	_label("DEWDROP", Rect2(31, 27, 478, 58), 52, CREAM)
	_label("PLOT", Rect2(31, 82, 340, 58), 52, GOLD)
	_label("One tank. A clever little garden.", Rect2(34, 148, 470, 31), 21, Color("b9d8c4"))
	_sprite(109, Rect2(404, 69, 75, 75))
	var hero_model: RefCounted = Model.new()
	hero_model.edges = Model.state_from(hero_model.plot.solution.edges)
	var hero: Control = Board.new(); hero.model = hero_model; hero.position = Vector2(127, 190); hero.size = Vector2(286, 286); hero.interactive = false
	hero.pulsing = true; hero.pulse_progress = 1; hero.result = hero_model.pulse(); stage.add_child(hero)
	_sprite(84, Rect2(43, 310, 68, 68)); _sprite(8, Rect2(434, 243, 60, 60)); _sprite(32, Rect2(439, 341, 60, 60))
	var stat_names: Array = ["PLOTS", "STARS", "GROWER"]
	var stat_values: Array = ["%d / 100" % model.records.size(), "%d / 300" % model.stars(), "Level %d" % model.level()]
	for i: int in range(3):
		_panel(Rect2(24 + i * 168, 493, 156, 79), Color("e6e7c5"), 13)
		_label(stat_names[i], Rect2(35 + i * 168, 502, 134, 20), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		_label(stat_values[i], Rect2(30 + i * 168, 530, 144, 30), 23, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_button("GROW THE NEXT PLOT  →", Rect2(24, 600, 492, 67), func(): _start(model.unlocked_plot()), false)
	_button("Daily garden  ·  " + ("complete" if model.daily_done else "fresh today"), Rect2(24, 683, 492, 55), func(): _show("daily"), true)
	_button("100 little plots", Rect2(24, 756, 240, 54), func(): _show("levels"), true)
	_button("Garden colors", Rect2(278, 756, 238, 54), func(): _show("garden"), true)
	_label("%d coins  ·  %d XP" % [model.coins, model.xp], Rect2(25, 828, 490, 27), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_button("Journal", Rect2(24, 860, 235, 56), func(): _show("journal"), true)
	_button("Sound & services", Rect2(278, 860, 238, 56), func(): _show("settings"), true)

func _start(id: int, is_daily: bool = false) -> void:
	if not model.start_plot(id, is_daily): _toast("Finish the previous plot to open this one."); return
	pulse_result = {}; receipt = {}; erase_mode = false; _show("play")

func _play_screen() -> void:
	var p: Dictionary = model.plot
	_label(("DAILY · " if model.daily_mode else "PLOT %02d · " % (model.current_id + 1)) + str(Model.CHAPTERS[int(p.chapter)]).to_upper(), Rect2(25, 22, 491, 28), 15, MUTED)
	_label(str(p.title), Rect2(24, 57, 492, 43), 29, INK)
	var need: int = 0; var supply: int = 0
	for crop: Dictionary in p.crops:
		if bool(crop.wanted): need += int(crop.cost)
	for tank: Dictionary in p.sources: supply += int(tank.water)
	_panel(Rect2(24, 115, 492, 112), INK, 16)
	_label("HARVEST ORDER", Rect2(40, 126, 255, 21), 12, Color("b9d8c4"))
	water_label = _label("%d drops · need %d" % [supply, need], Rect2(285, 125, 213, 26), 16, Color("8ee0df"), HORIZONTAL_ALIGNMENT_RIGHT)
	var order_index: int = 0; var order_size: int = p.orders.size()
	for key: String in p.orders:
		var x: float = 40 + order_index * minf(139, 455.0 / maxi(1, order_size)); order_index += 1
		_sprite(int(Model.CROPS[key].icon), Rect2(x, 158, 38, 38))
		_label("× %d" % int(p.orders[key]), Rect2(x + 42, 163, 58, 28), 21, CREAM)
	board = Board.new(); board.model = model; board.position = Vector2(39, 245); board.size = Vector2(462, 462)
	board.erase_mode = erase_mode; board.interactive = not model.attempt_claimed
	board.edge_requested.connect(_edit_edge); board.gate_requested.connect(_gate); stage.add_child(board)
	if not pulse_result.is_empty(): board.result = pulse_result; board.pulsing = true; board.pulse_progress = 1
	var help: String = "Drag between squares to draw a channel."
	if model.current_id == 0: help = "Drag from the blue tank through both + beds."
	elif model.current_id == 1: help = "The hollow-circle bed is optional. Save your water."
	elif bool(p.get("pooling_required", false)): help = "Open gates and link both tanks to share their water."
	elif not p.gates.is_empty(): help = "Tap a wooden gate to open or close it."
	elif p.sources.size() == 2: help = "Two tanks: connect them to share their supply."
	status_label = _label(help, Rect2(27, 717, 486, 29), 16, INK, HORIZONTAL_ALIGNMENT_CENTER)
	plan_label = _label("Save %d drops · target ≤ %d channels · drawn %d" % [int(p.reserve_goal), int(p.par_edges), model.edges.size()], Rect2(27, 749, 486, 23), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var labels: Array = ["Undo", "Reset", "Erase" if not erase_mode else "Draw", "Hint"]
	for i: int in range(4):
		var choice: int = i
		var tool: Button = _button(labels[i], Rect2(24 + i * 126, 781, 114, 52), func(): _tool(choice), true)
		toolbar.append(tool)
	release_button = _button("RELEASE WATER  ↓", Rect2(24, 851, 492, 64), func(): _begin_pulse())
	release_button.disabled = model.attempt_claimed
	_button("‹ Plots", Rect2(24, 927, 111, 30), func(): _show("levels"), true)
	_label("+ basket bed   ○ optional   blue number = cost", Rect2(143, 930, 373, 24), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

func _clear_preview() -> void:
	pulse_result = {}
	if is_instance_valid(board): board.result = {}; board.pulsing = false; board.queue_redraw()
	if is_instance_valid(plan_label): plan_label.text = "Save %d drops · target ≤ %d channels · drawn %d" % [int(model.plot.reserve_goal), int(model.plot.par_edges), model.edges.size()]

func _edit_edge(a: int, b: int, erase: bool) -> void:
	if pulsing: return
	if model.edit_edge(a, b, erase): _clear_preview()

func _gate(cell: int) -> void:
	if not pulsing and model.toggle_gate(cell): _clear_preview(); _sfx("click")

func _tool(index: int) -> void:
	if pulsing: return
	match index:
		0:
			if model.undo(): _clear_preview()
		1: model.reset_plan(); _clear_preview(); _show("play")
		2:
			erase_mode = not erase_mode; board.erase_mode = erase_mode; toolbar[2].text = "Draw" if erase_mode else "Erase"
			status_label.text = "Drag over channels to erase them." if erase_mode else "Drag between squares to draw a channel."
		3: _request_hint()
	_sfx("click"); _save()

func _begin_pulse() -> void:
	if pulsing or model.attempt_claimed: return
	pulse_result = model.pulse(); pulsing = true; pulse_time = 0
	board.result = pulse_result; board.pulsing = true; board.pulse_progress = 0; board.interactive = false
	for tool: Button in toolbar: tool.disabled = true
	release_button.disabled = true; status_label.text = "Nearest beds drink first. Every drop is accounted for."
	_sfx("release")

func _finish_pulse() -> void:
	pulsing = false; board.pulse_progress = 1
	if bool(pulse_result.success):
		receipt = model.finish_plot(pulse_result); _sync(); _sfx("harvest")
		var service: Node = _services()
		if not demo and service != null and not receipt.is_empty(): service.call("round_finished")
	else: receipt = {}
	_save(); _show("result")

func _result_screen() -> void:
	var ok: bool = bool(pulse_result.get("success", false))
	_header("THE GARDEN BLOOMS" if ok else "A LITTLE MORE PLANNING", "Harvest delivered. The rest can wait." if ok else "Water is precious. Your next try is free.")
	_panel(Rect2(24, 145, 492, 412), INK, 22)
	_sprite(84 if ok else 73, Rect2(209, 166, 122, 122))
	if ok:
		_result_stars(clampi(int(pulse_result.get("stars", 0)), 0, 3))
	else:
		_label("TRY ANOTHER ROUTE", Rect2(38, 302, 464, 55), 29, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label("%d used  +  %d saved  =  %d drops" % [int(pulse_result.get("consumed", 0)), int(pulse_result.get("left", 0)), int(pulse_result.get("supply", 0))], Rect2(39, 374, 462, 40), 23, CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	var summary: String = ""
	if ok:
		summary = "+%d coins   ·   +%d XP" % [int(receipt.get("coins", 0)), int(receipt.get("xp", 0))]
		if int(receipt.get("level_bonus", 0)) > 0: summary += "\nLevel bonus +%d coins" % int(receipt.level_bonus)
		if bool(receipt.get("assisted", false)): summary += "\nHint used · efficiency record excluded"
	else:
		for crop: String in pulse_result.get("deficit", {}): summary += "%s: %d short  " % [str(Model.CROPS[crop].name), int(pulse_result.deficit[crop])]
		summary += "\nOptional beds also drink. Shorter routes help."
	_label(summary, Rect2(46, 439, 448, 92), 18, Color("b9d8c4"), HORIZONTAL_ALIGNMENT_CENTER)
	if ok:
		_button("NEXT LITTLE PLOT  →" if not model.daily_mode else "TODAY'S GOOD THINGS", Rect2(24, 588, 492, 64), func():
			if model.daily_mode: _show("daily")
			elif model.current_id < Model.CAMPAIGN_PLOTS - 1: _start(model.current_id + 1)
			else: _show("levels"))
		_button("Replay this plot", Rect2(24, 677, 492, 54), func(): _start(model.current_id, model.daily_mode), true)
	else:
		_button("KEEP PLANNING", Rect2(24, 588, 492, 64), func(): _show("play"))
		_button("Reset the channels", Rect2(24, 677, 492, 54), func(): model.reset_plan(); pulse_result = {}; _show("play"), true)
	_button("Visit the garden colors", Rect2(24, 764, 492, 54), func(): _show("garden"), true)
	_label("A star for the order, one for saving water,\none for staying within the channel target.", Rect2(35, 839, 470, 57), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _result_stars(count: int) -> void:
	# Award icons must render without a platform font's optional star glyph.
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ResultStars"
	row.position = Vector2(38, 299); row.size = Vector2(464, 48)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(row)
	for index: int in range(count):
		var icon: TextureRect = TextureRect.new()
		icon.name = "EarnedStar%d" % (index + 1)
		icon.texture = RESULT_STAR
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var count_label: Label = _label("%d of 3 stars" % count, Rect2(38, 349, 464, 23), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	count_label.name = "ResultStarCount"

func _levels() -> void:
	_header("TEN LITTLE SEASONS", "%d / 100 plots  ·  %d / 300 stars" % [model.records.size(), model.stars()])
	var scroll: ScrollContainer = ScrollContainer.new(); scroll.position = Vector2(24, 136); scroll.size = Vector2(492, 745); stage.add_child(scroll)
	var holder: Control = Control.new(); holder.mouse_filter = Control.MOUSE_FILTER_PASS; holder.custom_minimum_size = Vector2(475, Model.CHAPTERS.size() * 197); scroll.add_child(holder)
	for chapter: int in range(Model.CHAPTERS.size()):
		var y: float = chapter * 197
		var label: Label = Label.new(); label.text = "%02d  %s" % [chapter + 1, Model.CHAPTERS[chapter]]; label.position = Vector2(4, y); label.size = Vector2(470, 34); label.add_theme_font_size_override("font_size", 23); label.add_theme_color_override("font_color", INK); holder.add_child(label)
		for local: int in range(10):
			var id: int = chapter * 10 + local; var open: bool = id <= model.unlocked_plot()
			var stars: int = int(model.records.get(str(id), {}).get("stars", 0))
			var button: Button = Button.new(); button.position = Vector2((local % 5) * 94 + 1, y + 48 + int(local / 5) * 67); button.size = Vector2(84, 57)
			button.text = "%02d\n%s" % [id + 1, "★".repeat(stars)] if open else "LOCKED"
			_style_button(button, true); button.add_theme_font_size_override("font_size", 16); button.disabled = not open
			button.pressed.connect(func(): _start(id)); holder.add_child(button)
	_label("Finish a plot to open the next. Replays are free.", Rect2(170, 912, 347, 36), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

func _daily() -> void:
	model.roll_day(Time.get_date_string_from_system(true))
	_header("MORNING DEW", "Small daily goals. No rush to catch up.")
	_panel(Rect2(24, 145, 492, 199), INK, 18)
	_sprite(83, Rect2(46, 163, 66, 66))
	_label("TODAY'S PLOT", Rect2(136, 166, 353, 23), 13, Color("b9d8c4"))
	_label(Model.definition(model.daily_plot_id()).title, Rect2(136, 200, 353, 44), 23, CREAM)
	_button("REPLAY FOR FUN" if model.daily_done else "PLAY DAILY · 80 COINS", Rect2(42, 270, 456, 51), func(): _start(model.daily_plot_id(), true))
	_label("THE GROWER'S CHECKLIST", Rect2(26, 370, 490, 26), 15, MUTED)
	var names: Array = ["Complete 2 different plots", "Harvest 6 crop beds", "Save 3 drops of water"]
	var values: Array = [model.daily_counts.plots, model.daily_counts.harvests, model.daily_counts.water]
	var goals: Array = [2, 6, 3]
	for i: int in range(3):
		var y: float = 414 + i * 104; var chosen: int = i
		_panel(Rect2(24, y, 492, 85), Color("e6e7c5"), 13)
		_label(names[i], Rect2(40, y + 11, 334, 29), 20, INK)
		_label("%d / %d  ·  35 coins" % [mini(int(values[i]), int(goals[i])), goals[i]], Rect2(41, y + 47, 329, 25), 15, MUTED)
		var claim: Button = _button("DONE" if i in model.quest_claimed else "CLAIM", Rect2(386, y + 16, 112, 52), func():
			if model.claim_quest(chosen) > 0: _sfx("harvest"); _show("daily"), true)
		claim.disabled = not model.quest_ready(i)
	_panel(Rect2(24, 753, 492, 109), Color("d8e4c0"), 15)
	_label("A little welcome", Rect2(41, 764, 303, 30), 21, INK)
	_label("7-day coins: 20 · 25 · 30 · 40 · 50 · 65 · 100", Rect2(41, 805, 360, 40), 14, MUTED)
	var login: Button = _button("COLLECT" if model.login_available() else "DAY %d ✓" % model.login_streak, Rect2(380, 778, 118, 51), func(): model.claim_login(); _show("daily"); _sfx("harvest"))
	login.disabled = not model.login_available()

func _garden() -> void:
	_header("COLOR YOUR ALLOTMENT", "%d coins  ·  Grower level %d" % [model.coins, model.level()])
	for i: int in range(Model.STYLES.size()):
		var item: Dictionary = Model.STYLES[i]; var y: float = 145 + i * 176; var choice: int = i
		_panel(Rect2(24, y, 492, 153), Color("e6e7c5"), 17)
		_panel(Rect2(40, y + 18, 109, 115), Color(item.grass), 9)
		_panel(Rect2(57, y + 48, 75, 42), Color(item.soil), 0); _sprite(6 + (i % 3) * 12, Rect2(57, y + 36, 72, 72))
		_label(item.name, Rect2(168, y + 20, 325, 36), 23, INK)
		_label("A fresh palette. The same fair puzzles.", Rect2(169, y + 62, 323, 39), 14, MUTED)
		var owned: bool = i in model.owned_styles
		var button: Button = _button("USING" if model.style == i else ("USE COLOR" if owned else "%d COINS" % int(item.price)), Rect2(300, y + 103, 196, 36), func():
			if model.choose_style(choice): _sync(); _show("garden"); _sfx("harvest")
			else: _toast("A few more harvests will earn this color."), true)
		button.disabled = model.style == i or (not owned and model.coins < int(item.price))
	_label("Level %d · %d XP to the next level" % [model.level(), maxi(0, model.level_floor(model.level() + 1) - model.xp)], Rect2(174, 910, 342, 35), 15, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)

func _journal() -> void:
	_header("THE GROWER'S JOURNAL", "%d beds harvested  ·  %d drops saved" % [model.total_harvests, model.saved_water])
	var scroll: ScrollContainer = ScrollContainer.new(); scroll.position = Vector2(24, 142); scroll.size = Vector2(492, 738); stage.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new(); list.custom_minimum_size.x = 476; list.add_theme_constant_override("separation", 12); scroll.add_child(list)
	for entry: Dictionary in catalog.get("achievements", []):
		var item: PanelContainer = PanelContainer.new(); item.mouse_filter = Control.MOUSE_FILTER_PASS; item.custom_minimum_size = Vector2(476, 110)
		var stylebox: StyleBoxFlat = StyleBoxFlat.new(); stylebox.bg_color = Color("d4e5c2") if entry.key in model.unlocked else Color("e6e7c5"); stylebox.set_corner_radius_all(13); stylebox.content_margin_left = 15; stylebox.content_margin_top = 11; item.add_theme_stylebox_override("panel", stylebox)
		var text: Label = Label.new(); text.text = ("★  " if entry.key in model.unlocked else "○  ") + str(entry.title) + "\n" + str(entry.description) + "\n%d / %d" % [mini(model.stat(entry.stat), int(entry.threshold)), int(entry.threshold)]
		text.add_theme_font_size_override("font_size", 17); text.add_theme_color_override("font_color", INK); item.add_child(text); list.add_child(item)
	_button("Play Games achievements", Rect2(180, 909, 336, 40), func(): _service("open_achievements"), true)

func _settings() -> void:
	_header("A QUIET LITTLE GARDEN", "Your pace. Your plot. Your progress.")
	_panel(Rect2(24, 145, 492, 229), Color("e6e7c5"), 18)
	_label("How water works", Rect2(43, 161, 451, 37), 25, INK)
	_label("Draw from a blue tank to the beds you need.\nNearer connected beds drink first; ties go\nfrom top-left to bottom-right. A closed gate\nblocks water. Linked tanks share their supply.\nEvery used drop and saved drop is shown.", Rect2(43, 210, 452, 142), 18, INK)
	_button("Sound: ON" if model.sound else "Sound: OFF", Rect2(24, 402, 492, 54), func():
		model.sound = not model.sound
		if model.sound and DisplayServer.get_name() != "headless": music.play()
		else: music.stop()
		_show("settings"), true)
	_button("Connect Play Games", Rect2(24, 479, 492, 54), func(): _service("sign_in"), true)
	_button("Harvest leaderboards", Rect2(24, 556, 492, 54), func(): _service("open_leaderboards", ["dew_plots"]), true)
	_button("Privacy options", Rect2(24, 633, 492, 54), func(): _service("privacy_options"), true)
	var service: Node = _services()
	_label(str(service.call("status")) if service != null else "Local play is ready. Optional Android services\ncan be connected in a configured Android build.", Rect2(38, 724, 465, 84), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	_label("Saved on this device. No internet is needed\nfor normal play, undo, resets or progression.", Rect2(35, 830, 470, 57), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _request_hint() -> void:
	var service: Node = _services()
	if service == null or not bool(service.call("can_reward")):
		_toast("No hint sponsor available. Planning and retry stay free."); return
	var token: int = model.begin_hint_reward()
	if token == 0: _toast("One sponsored hint per attempt. Your channels are ready."); return
	service.call("reward_requested", "route_hint", func(earned: bool):
		if model.finish_hint_reward(token, earned):
			_clear_preview(); _save()
			_toast("One channel revealed. This attempt is assisted.")
		else: _toast("No hint earned. Your plot is still available."))

func _services() -> Node:
	return get_node_or_null("/root/Services")

func _service(method: String, arguments: Array = []) -> void:
	var service: Node = _services()
	if service != null: service.callv(method, arguments); _toast(str(service.call("status")))
	else: _toast("Android services are unavailable. Local play is ready.")

func _sync() -> void:
	var service: Node = _services()
	for entry: Dictionary in catalog.get("achievements", []):
		if model.stat(entry.stat) >= int(entry.threshold) and entry.key not in model.unlocked:
			model.unlocked.append(entry.key)
			if not demo and service != null: service.call("unlock", entry.key)
	if not demo and service != null:
		for entry: Dictionary in catalog.get("leaderboards", []): service.call("submit", entry.key, model.stat(entry.stat))
	_save()

func _save() -> void:
	if not demo: model.save_file(SAVE)

func _sfx(name: String) -> void:
	if not model.sound or DisplayServer.get_name() == "headless": return
	sfx.stream = load("res://assets/audio/%s.ogg" % name); sfx.volume_db = -9; sfx.play()

func _toast(message: String) -> void:
	if is_instance_valid(toast_label): toast_label.queue_free()
	toast_label = _label(message, Rect2(23, 662 if screen == "play" else 849, 494, 57), 16, CREAM, HORIZONTAL_ALIGNMENT_CENTER, true)
	var box: StyleBoxFlat = StyleBoxFlat.new(); box.bg_color = INK; box.set_corner_radius_all(12)
	toast_label.add_theme_stylebox_override("normal", box); toast_label.z_index = 20; toast_seconds = 3.5

func _panel(rect: Rect2, color: Color, radius: int = 14) -> Panel:
	var panel: Panel = Panel.new(); panel.position = rect.position; panel.size = rect.size; panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox: StyleBoxFlat = StyleBoxFlat.new(); stylebox.bg_color = color; stylebox.set_corner_radius_all(radius); panel.add_theme_stylebox_override("panel", stylebox); stage.add_child(panel)
	return panel

func _label(value: String, rect: Rect2, font_size: int = 20, color: Color = INK, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = value; label.position = rect.position; label.size = rect.size; label.horizontal_alignment = alignment; label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", color); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; stage.add_child(label)
	return label

func _sprite(id: int, rect: Rect2) -> void:
	var image: TextureRect = TextureRect.new(); image.texture = textures[id]; image.position = rect.position; image.size = rect.size; image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; image.mouse_filter = Control.MOUSE_FILTER_IGNORE; stage.add_child(image)

func _style_button(button: Button, secondary: bool) -> void:
	button.mouse_filter = Control.MOUSE_FILTER_PASS if screen not in ["play", "game"] else Control.MOUSE_FILTER_STOP
	var normal: StyleBoxFlat = StyleBoxFlat.new(); normal.bg_color = Color("e0e5c2") if secondary else WATER; normal.set_corner_radius_all(12); normal.content_margin_left = 10; normal.content_margin_right = 10
	var hover: StyleBoxFlat = normal.duplicate(); hover.bg_color = normal.bg_color.lightened(0.06)
	var pressed: StyleBoxFlat = normal.duplicate(); pressed.bg_color = normal.bg_color.darkened(0.12)
	var disabled: StyleBoxFlat = normal.duplicate(); disabled.bg_color = Color("e6e7cf")
	button.add_theme_stylebox_override("normal", normal); button.add_theme_stylebox_override("hover", hover); button.add_theme_stylebox_override("pressed", pressed); button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_font_size_override("font_size", 19); button.add_theme_color_override("font_color", INK if secondary else CREAM); button.add_theme_color_override("font_hover_color", INK if secondary else CREAM); button.add_theme_color_override("font_pressed_color", INK if secondary else CREAM); button.add_theme_color_override("font_disabled_color", Color("99a38c"))
	button.focus_mode = Control.FOCUS_NONE

func _button(value: String, rect: Rect2, callback: Callable, secondary: bool = false) -> Button:
	var button: Button = Button.new(); button.text = value; button.position = rect.position; button.size = rect.size; _style_button(button, secondary); button.pressed.connect(callback); stage.add_child(button)
	return button

func _demo_state() -> void:
	model.coins = 760; model.xp = 1430; model.total_harvests = 114; model.saved_water = 87
	for id: int in range(35): model.records[str(id)] = {"stars": 3 if id % 4 != 0 else 2, "unassisted_perfect": id % 4 != 0, "reserve": 3}
	model.gate_clears = 5; model.daily_total = 3; model.owned_styles = [0, 1]; model.login_streak = 3
	model.daily_counts = {"plots": 2, "harvests": 8, "water": 5}
	model.start_plot(32)
	var solution: Array = model.plot.solution.edges
	for i: int in range(mini(10, solution.size())): model.edges[Model.edge_key(solution[i][0], solution[i][1])] = true
	model.open_gates = model.plot.gates.duplicate()
	if boot_view == "result":
		model.edges = Model.state_from(solution); pulse_result = model.pulse(); receipt = model.finish_plot(pulse_result)

func _capture() -> void:
	for i: int in range(15): await get_tree().process_frame
	if DisplayServer.get_name() == "headless": push_error("Capture requires actual GPU rendering"); get_tree().quit(1); return
	await RenderingServer.frame_post_draw
	var error: Error = get_viewport().get_texture().get_image().save_png(capture_path)
	print("DEWDROP_CAPTURE_OK: ", capture_path, " result=", error)
	_stop_audio(); await get_tree().create_timer(0.1).timeout; get_tree().quit(0 if error == OK else 1)

func _runtime_smoke() -> void:
	await get_tree().process_frame
	_start(0); await get_tree().process_frame; await get_tree().process_frame
	var path: Array = model.plot.solution.edges
	# Inject real screen-touch/drag events through the viewport's GUI dispatch.
	var first: Vector2 = board.get_global_transform() * board.tile_center(int(path[0][0]))
	var touch: InputEventScreenTouch = InputEventScreenTouch.new(); touch.index = 0; touch.position = first; touch.pressed = true; get_viewport().push_input(touch, true)
	for edge: Array in path:
		var drag: InputEventScreenDrag = InputEventScreenDrag.new(); drag.index = 0; drag.position = board.get_global_transform() * board.tile_center(int(edge[1])); get_viewport().push_input(drag, true)
	var lift: InputEventScreenTouch = InputEventScreenTouch.new(); lift.index = 0; lift.position = board.get_global_transform() * board.tile_center(int(path[-1][1])); lift.pressed = false; get_viewport().push_input(lift, true)
	await get_tree().process_frame
	if not bool(model.pulse().success): push_error("Touch route failed to build a solvable channel"); get_tree().quit(1); return
	var center: Vector2 = release_button.get_global_rect().get_center()
	var click: InputEventMouseButton = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.position = center; click.pressed = true; get_viewport().push_input(click, true)
	click = InputEventMouseButton.new(); click.button_index = MOUSE_BUTTON_LEFT; click.position = center; click.pressed = false; get_viewport().push_input(click, true)
	await get_tree().create_timer(3.2).timeout
	if screen != "result" or receipt.is_empty() or not model.records.has("0"):
		push_error("Water button, animation or harvest receipt failed"); get_tree().quit(1); return
	_show("daily"); await get_tree().process_frame
	_show("garden"); await get_tree().process_frame
	_show("journal"); await get_tree().process_frame
	print("DEWDROP_UI_SMOKE_OK: actual touch routing, release button, pulse, receipt, daily, garden and journal")
	_stop_audio(); await get_tree().create_timer(0.1).timeout; get_tree().quit(0)
