extends SceneTree
const Model = preload("res://game/model.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_campaign()
	_test_simulation()
	_test_editing_and_hint()
	_test_progression()
	_test_daily()
	_test_persistence()
	print("DEWDROP_MODEL_TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(message)

func solution(data: Dictionary) -> Dictionary:
	return Model.simulate(data, Model.state_from(data.solution.edges), data.solution.open_gates)

func _test_campaign() -> void:
	var plots: Array = Model.all_plots(); var signatures: Dictionary = {}; var optional_failures: int = 0
	check(plots.size() == 60, "Campaign does not contain 60 actual plots")
	for id: int in range(plots.size()):
		var p: Dictionary = plots[id]
		check(int(p.id) == id and int(p.chapter) == int(id / 10), "Campaign chapter/id mismatch")
		var signature: String = JSON.stringify([p.sources, p.crops, p.rocks, p.gates, p.orders])
		check(not signatures.has(signature), "Repeated plot arrangement")
		signatures[signature] = true
		var occupied: Array = []
		for crop: Dictionary in p.crops:
			check(int(crop.cell) not in occupied and int(crop.cell) >= 0 and int(crop.cell) < 49, "Overlapping or out-of-bounds crop")
			check(int(crop.cost) > 0 and Model.CROPS.has(str(crop.species)), "Invalid crop cost/species")
			occupied.append(int(crop.cell))
		for source: Dictionary in p.sources:
			check(int(source.cell) not in occupied and int(source.water) > 0, "Invalid tank placement/budget")
			occupied.append(int(source.cell))
		for edge: Array in p.solution.edges:
			check(int(edge[1]) in Model.neighbors(int(edge[0])), "Witness contains a non-adjacent channel")
			check(int(edge[0]) not in p.rocks and int(edge[1]) not in p.rocks, "Witness crosses a rock")
		var result: Dictionary = solution(p)
		check(bool(result.success) and int(result.stars) == 3, "Stored solution fails the actual play simulation: plot %d" % (id + 1))
		check(int(result.consumed) + int(result.left) == int(result.supply), "Water created or destroyed in witness")
		for component: Dictionary in result.components:
			check(int(component.used) + int(component.left) == int(component.supply), "Component water is not conserved")
		var empty: Dictionary = Model.simulate(p, {}, [])
		check(not bool(empty.success), "Empty channels automatically solve a plot")
		var all_edges: Dictionary = {}
		for a: int in range(49):
			for b: int in Model.neighbors(a): all_edges[Model.edge_key(a, b)] = true
		var greedy: Dictionary = Model.simulate(p, all_edges, p.gates)
		check(int(greedy.consumed) + int(greedy.left) == int(greedy.supply), "Full-grid water is not conserved")
		if not bool(greedy.success): optional_failures += 1
		if id >= 10: check(not p.rocks.is_empty(), "Rock chapter lacks rocks")
		if id >= 30: check(not p.gates.is_empty(), "Gate chapter lacks gates")
		if id >= 40: check(p.sources.size() == 2, "Twin-tank chapter lacks a second tank")
	check(optional_failures >= 20, "Optional thirsty beds do not create meaningful limited-water choices")
	check(bool(plots[0].tutorial) and bool(plots[1].tutorial) and not bool(plots[2].tutorial), "First two tutorials missing")

func _test_simulation() -> void:
	var p: Dictionary = {"rocks": [], "gates": [], "orders": {"carrot": 1}, "sources": [{"cell": 0, "water": 4}], "crops": [{"cell": 1, "species": "corn", "cost": 3}, {"cell": 2, "species": "carrot", "cost": 2}], "reserve_goal": 2, "par_edges": 4}
	var failed: Dictionary = Model.simulate(p, Model.state_from([[0, 1], [1, 2]]), [])
	check(not bool(failed.success), "Nearest optional bed did not consume scarce water first")
	check(int(failed.consumed) == 4 and int(failed.left) == 0, "Partial crop consumption not conserved")
	check(not bool(failed.events[1].grown) and int(failed.events[1].used) == 1, "Partial watering incorrectly harvested a crop")
	var bypass: Dictionary = Model.simulate(p, Model.state_from([[0, 7], [7, 8], [8, 9], [9, 2]]), [])
	check(bool(bypass.success) and int(bypass.left) == 2, "Bypassing a thirsty optional bed did not conserve water")
	p.gates = [8]
	check(not bool(Model.simulate(p, Model.state_from([[0, 7], [7, 8], [8, 9], [9, 2]]), []).success), "Closed gate leaks water")
	check(bool(Model.simulate(p, Model.state_from([[0, 7], [7, 8], [8, 9], [9, 2]]), [8]).success), "Open gate blocks water")
	p.rocks = [7]
	check(not bool(Model.simulate(p, Model.state_from([[0, 7], [7, 8], [8, 9], [9, 2]]), [8]).success), "Rock carries a channel")
	var two: Dictionary = {"rocks": [], "gates": [], "orders": {"carrot": 1, "corn": 1}, "sources": [{"cell": 0, "water": 1}, {"cell": 6, "water": 5}], "crops": [{"cell": 1, "species": "carrot", "cost": 2}, {"cell": 5, "species": "corn", "cost": 3}], "reserve_goal": 1, "par_edges": 6}
	var separate: Dictionary = Model.simulate(two, Model.state_from([[0, 1], [6, 5]]), [])
	check(not bool(separate.success), "Disconnected tanks borrowed each other's water")
	var connected: Dictionary = Model.simulate(two, Model.state_from([[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6]]), [])
	check(bool(connected.success) and int(connected.left) == 1 and connected.components.size() == 1, "Connected tanks did not pool supply exactly once")
	check(Model.neighbors(-1).is_empty() and Model.neighbors(49).is_empty(), "Invalid cells have neighbors")
	check(Model.state_from([[0, 48], [-1, 0], [6, 7]]).is_empty(), "Invalid channels accepted")
	# Ties are always served in cell order, independent of insertion order.
	var tie: Dictionary = {"rocks": [], "gates": [], "orders": {"carrot": 1}, "sources": [{"cell": 8, "water": 2}], "crops": [{"cell": 9, "species": "corn", "cost": 2}, {"cell": 1, "species": "carrot", "cost": 2}], "reserve_goal": 0, "par_edges": 2}
	var order: Dictionary = Model.simulate(tie, Model.state_from([[8, 9], [8, 1]]), [])
	check(bool(order.success) and int(order.events[0].cell) == 1, "Distance-tie order is unstable")

func _test_editing_and_hint() -> void:
	var m: RefCounted = Model.new("2026-10-20")
	check(m.edit_edge(21, 22), "Valid draw rejected")
	check(not m.edit_edge(21, 22), "Duplicate draw inserted")
	check(not m.edit_edge(0, 48), "Remote draw accepted")
	check(m.undo() and m.edges.is_empty(), "Undo failed to restore graph")
	check(not m.undo(), "Empty undo succeeded")
	check(m.edit_edge(21, 22) and m.edit_edge(21, 22, true) and m.edges.is_empty(), "Erase did not remove edge")
	m.undo(); check(m.edges.size() == 1, "Undo erase did not restore edge")
	m.reset_plan(); check(m.edges.is_empty(), "Reset left channels")
	m.undo(); check(m.edges.size() == 1, "Undo reset did not restore plan")
	var denied: int = m.begin_hint_reward()
	check(denied > 0 and not m.finish_hint_reward(denied, false), "Uncompleted ad granted a hint")
	check(not m.assisted and not m.hint_used, "Unavailable reward changed entitlement")
	var earned: int = m.begin_hint_reward()
	check(earned > denied and m.begin_hint_reward() == 0, "Concurrent sponsored hint allowed")
	check(m.finish_hint_reward(earned, true), "Earned callback did not reveal a route step")
	var edge_count: int = m.edges.size()
	check(not m.finish_hint_reward(earned, true) and m.edges.size() == edge_count, "Duplicate earned callback granted another step")
	check(m.assisted and m.hint_used, "Assisted state missing")
	m.undo(); m.reset_plan(); check(m.assisted and m.hint_used, "Undo/reset laundered assisted state")
	check(m.begin_hint_reward() == 0, "Second earned hint in same attempt allowed")
	m.start_plot(0); var stale: int = m.begin_hint_reward(); m.start_plot(0)
	check(not m.finish_hint_reward(stale, true) and not m.assisted, "Old attempt reward applied to a new plot")

func _test_progression() -> void:
	var m: RefCounted = Model.new("2026-10-20")
	check(not m.start_plot(1) and m.start_plot(0), "Campaign unlock boundary missing")
	check(m.finish_plot({"success": true}).is_empty(), "Forged successful result paid out")
	m.edges = Model.state_from(m.plot.solution.edges); m.open_gates = m.plot.solution.open_gates.duplicate()
	var before: int = m.coins; var result: Dictionary = m.pulse(); var receipt: Dictionary = m.finish_plot(result)
	check(not receipt.is_empty() and bool(receipt.fresh), "First clear did not pay")
	check(m.records.size() == 1 and m.stars() == 3 and m.perfect() == 1 and m.unlocked_plot() == 1, "Clear did not record stars/unlock")
	check(m.coins > before and m.xp > 0, "Clear gave no progression")
	var paid_coins: int = m.coins; var paid_xp: int = m.xp
	check(m.finish_plot(result).is_empty() and m.coins == paid_coins and m.xp == paid_xp, "Double harvest paid twice")
	m.start_plot(0); m.edges = Model.state_from(m.plot.solution.edges)
	m.finish_plot(m.pulse()); check(m.coins == paid_coins and m.xp == paid_xp, "Identical replay farmed coins or XP")
	var a: RefCounted = Model.new("2026-10-20"); var token: int = a.begin_hint_reward(); a.finish_hint_reward(token, true)
	a.edges = Model.state_from(a.plot.solution.edges); a.finish_plot(a.pulse())
	check(a.stars() == 3 and a.perfect() == 0, "Assisted run entered efficiency record")
	check(not a.choose_style(1), "Unaffordable cosmetic bought")
	a.coins = 300; check(a.choose_style(1) and a.coins == 50, "Cosmetic cost incorrect")
	check(a.choose_style(1) and a.coins == 50, "Owned cosmetic charged twice")
	check(not a.choose_style(99), "Invalid cosmetic selected")
	var campaign: RefCounted = Model.new("2026-10-20")
	for id: int in range(60):
		check(campaign.start_plot(id), "Sequential campaign progression blocked")
		campaign.edges = Model.state_from(campaign.plot.solution.edges); campaign.open_gates = campaign.plot.solution.open_gates.duplicate()
		check(not campaign.finish_plot(campaign.pulse()).is_empty(), "Campaign witness failed to pay")
	check(campaign.records.size() == 60 and campaign.stars() == 180 and campaign.perfect() == 60, "Complete campaign stats incorrect")
	check(campaign.level() >= 8 and campaign.total_harvests > 150 and campaign.saved_water > 50, "Campaign progression too small")

func _test_daily() -> void:
	var m: RefCounted = Model.new("2026-10-20")
	check(m.claim_login() == 20 and m.claim_login() == 0, "Login reward repeated")
	check(not m.roll_day("2026-10-19") and m.claim_login() == 0, "Clock rollback reopens daily rewards")
	for i: int in range(1, 7):
		m.roll_day("2026-10-%02d" % (20 + i)); check(m.claim_login() == int(Model.LOGIN[i]), "Login streak amount wrong")
	m.roll_day("2026-10-27"); check(m.claim_login() == 20 and m.login_streak == 1, "Seven-day reward cycle failed to reset")
	m.roll_day("2026-10-30"); check(m.claim_login() == 20 and m.login_streak == 1, "Missed days did not reset streak")
	check(not m.quest_ready(0) and m.claim_quest(0) == 0, "Unearned quest paid")
	m.daily_counts = {"plots": 2, "harvests": 6, "water": 3}
	for i: int in range(3): check(m.claim_quest(i) == 35 and m.claim_quest(i) == 0, "Quest reward is not idempotent")
	var id: int = m.daily_plot_id(); check(id >= 0 and id < 40 and id == m.daily_plot_id(), "Daily plot not bounded/deterministic")
	m.start_plot(id, true); m.edges = Model.state_from(m.plot.solution.edges); m.open_gates = m.plot.solution.open_gates.duplicate()
	var first: Dictionary = m.finish_plot(m.pulse()); check(int(first.coins) == 80 and m.daily_done and m.daily_total == 1, "Daily clear reward missing")
	check(m.records.is_empty() and m.unlocked_plot() == 0, "Daily bypassed campaign unlocks")
	var after: int = m.coins; m.start_plot(id, true); m.edges = Model.state_from(m.plot.solution.edges); m.open_gates = m.plot.solution.open_gates.duplicate(); m.finish_plot(m.pulse())
	check(m.coins == after and m.daily_total == 1, "Daily replay paid twice")

func _test_persistence() -> void:
	var m: RefCounted = Model.new("2026-10-20"); m.coins = 550; m.xp = 300; m.choose_style(1); m.edit_edge(21, 22)
	var token: int = m.begin_hint_reward(); m.finish_hint_reward(token, true); m.claim_login()
	var data: Dictionary = m.to_data(); var clone: RefCounted = Model.new("2026-10-20"); clone.load_data(data)
	check(clone.coins == m.coins and clone.xp == m.xp and clone.style == m.style, "Progress save round trip changed values")
	check(clone.edges == m.edges and clone.assisted and clone.hint_used, "Draft/assistance save round trip failed")
	check(clone.claim_login() == 0, "Save load reopened login claim")
	var tomorrow: RefCounted = Model.new("2026-10-21"); tomorrow.load_data(data)
	check(tomorrow.day == "2026-10-21" and tomorrow.login_available(), "New-day load kept stale daily state")
	var corrupt: Dictionary = {"coins": -9, "xp": -100, "records": {"999": {"stars": 3}, "0": {"stars": 9, "unassisted_perfect": true}}, "style": 99, "owned_styles": [99], "draft": {"id": 0, "edges": [[0, 48], [6, 7], [-1, 0]], "open_gates": [400]}}
	clone.load_data(corrupt)
	check(clone.coins == 0 and clone.xp == 0 and clone.style == 0 and clone.records.size() == 1 and clone.stars() == 3, "Corrupt numerical progress not bounded")
	check(clone.edges.is_empty() and clone.open_gates.is_empty(), "Corrupt draft graph accepted")
	var path: String = "user://dewdrop_core_test_only.json"
	check(m.save_file(path), "Actual test save write failed")
	m.coins += 23; check(m.save_file(path), "Atomic replacement failed")
	var loaded: RefCounted = Model.new("2026-10-20"); check(loaded.load_file(path) and loaded.coins == m.coins, "Actual file round trip failed")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE); file.store_string("{broken"); file.close()
	check(loaded.load_file(path) and loaded.coins == m.coins - 23, "Previous-save backup recovery failed")
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
