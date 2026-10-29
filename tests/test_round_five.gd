extends SceneTree
## Isolated content/progression/Window source tests, not native gameplay proof.
const Model = preload("res://game/model.gd")
const ORIGINAL_SIXTY_SHA256 = "38cc796fbb49b8e9a537180132a901ce827e09b9a59f7ca652a6da5fbd632ee3"
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_cmdline_user_args().has("--qa-isolated"):
		push_error("Isolated test data is required."); quit(2); return
	var plots: Array = Model.all_plots()
	check(plots.size() == 100 and Model.CHAPTERS.size() == 10, "Ten chapters contain one hundred real plot definitions")
	check(JSON.stringify(plots.slice(0,60), "", true).sha256_text() == ORIGINAL_SIXTY_SHA256, "Original sixty definitions remain structurally exact")
	var geometries := {}
	for i in range(60): geometries[_geometry(plots[i])] = true
	var pooled := 0
	var families := {}
	for i in range(60,100):
		var plot: Dictionary = plots[i]
		var geometry := _geometry(plot)
		check(not geometries.has(geometry), "New route geometry is distinct under rotations/reflections: %d" % (i+1))
		geometries[geometry] = true
		families[str(plot.extension_family)] = int(families.get(str(plot.extension_family),0)) + 1
		check(plot.orders.size() <= 4, "Harvest-order icons fit the existing four-item row")
		var channels: Dictionary = Model.state_from(plot.solution.edges)
		var result: Dictionary = Model.simulate(plot, channels, plot.solution.open_gates)
		check(result.success and int(result.stars) == 3, "Actual simulator accepts the stored extension witness: %d" % (i+1))
		check(int(result.consumed)+int(result.left) == int(result.supply), "Witness conserves every supplied drop")
		check(not Model.simulate(plot,channels,[]).success, "The new gates affect the actual solution")
		if bool(plot.pooling_required):
			pooled += 1
			var disconnected: Dictionary = channels.duplicate()
			disconnected.erase(Model.edge_key(int(plot.required_link[0]),int(plot.required_link[1])))
			check(not Model.simulate(plot,disconnected,plot.solution.open_gates).success, "Unequal tanks actually require their stored connecting channel")
	check(pooled == 20 and families.size() == 4, "Four ten-plot families include twenty genuine shared-budget puzzles")
	for count in families.values(): check(int(count) == 10, "Each extension chapter has ten fixed puzzles")
	_test_save_continuity(plots)
	await _test_final_roster()
	print("DEWDROP_ROUND_FIVE checks=%d failures=%d;100 runtime witnesses checked by model suite" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _cell(cell: int, mirror: bool, rotations: int) -> int:
	var x := cell % 7
	var y := int(cell / 7)
	if mirror: x = 6 - x
	for _rotation in range(rotations):
		var previous := x
		x = 6-y
		y = previous
	return x+y*7

func _geometry(plot: Dictionary) -> String:
	var best := ""
	for mirror in [false,true]:
		for turns in range(4):
			var sources: Array[int] = []
			var edges: Array[String] = []
			for tank in plot.sources: sources.append(_cell(int(tank.cell),mirror,turns))
			for edge in plot.solution.edges:
				edges.append(Model.edge_key(_cell(int(edge[0]),mirror,turns),_cell(int(edge[1]),mirror,turns)))
			sources.sort(); edges.sort()
			var serial := JSON.stringify([sources,edges])
			if best.is_empty() or serial < best: best = serial
	return best

func _test_save_continuity(plots: Array) -> void:
	var legacy := {}
	for i in range(60): legacy[str(i)] = {"stars":3,"reserve":int(plots[i].reserve_goal),"unassisted_perfect":true}
	var model = Model.new("2026-10-29")
	model.load_data({"version":1,"coins":654,"xp":333,"records":legacy,"draft":{"id":59,"daily":false,"edges":plots[59].solution.edges,"open_gates":plots[59].solution.open_gates}})
	check(model.records == legacy and model.coins == 654 and model.xp == 333, "Legacy sixty-plot records and banked rewards are retained")
	check(model.current_id == 59 and model.unlocked_plot() == 60 and model.start_plot(60), "Legacy final draft continues and the sixty-first plot unlocks naturally")
	for i in range(60,100): model.records[str(i)] = {"stars":3,"reserve":int(plots[i].reserve_goal),"unassisted_perfect":true}
	check(model.start_plot(99) and not model.start_plot(100), "The final plot opens while out-of-range plot101 stays invalid")
	model.edges = Model.state_from(plots[99].solution.edges)
	model.open_gates = plots[99].solution.open_gates.duplicate()
	var restored = Model.new("2026-10-29")
	restored.load_data(JSON.parse_string(JSON.stringify(model.to_data())))
	check(restored.records.size() == 100 and restored.stars() == 300 and restored.current_id == 99 and restored.edges == model.edges, "All one hundred records and the final draft survive JSON save/load")
	for day in range(1,29):
		model.roll_day("2026-11-%02d" % day)
		check(model.daily_plot_id() >= 0 and model.daily_plot_id() < 40, "Daily selection stays in the unchanged curated pool")

func _buttons(node: Node) -> Array[Button]:
	var found: Array[Button] = []
	for child in node.get_children():
		if child is Button: found.append(child)
		found.append_array(_buttons(child))
	return found

func _test_final_roster() -> void:
	var game = load("res://main.tscn").instantiate()
	game.demo = true
	root.add_child(game)
	game.set_process(false)
	for i in range(100): game.model.records[str(i)] = {"stars":3,"reserve":0,"unassisted_perfect":true}
	game._show("levels")
	await process_frame
	await process_frame
	var last: Button
	var plot_buttons := 0
	for button in _buttons(game.stage):
		if button.text.begins_with("100\n"): last = button
		if button.text.split("\n")[0].is_valid_int(): plot_buttons += 1
	check(plot_buttons == 100 and is_instance_valid(last) and not last.disabled, "The roster builds all100 accessible plot buttons")
	if is_instance_valid(last):
		var holder: Control = last.get_parent()
		var scroll: ScrollContainer = holder.get_parent()
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
		check(scroll.get_global_rect().encloses(last.get_global_rect()), "The final chapter scrolls fully into the real Window roster")
		last.pressed.emit()
		check(game.model.current_id == 99 and is_instance_valid(game.board), "Selecting the final roster card opens its real puzzle board")
	game.queue_free()
	await process_frame
	await process_frame
