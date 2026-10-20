class_name DewModel
extends RefCounted

const WIDTH: int = 7
const CELLS: int = 49
const CROPS: Dictionary = {
	"carrot": {"name": "Carrot", "seed": 4, "grown": 6, "icon": 8, "color": "e8a34c"},
	"turnip": {"name": "Turnip", "seed": 16, "grown": 18, "icon": 20, "color": "ce95b9"},
	"corn": {"name": "Corn", "seed": 28, "grown": 30, "icon": 32, "color": "efcb57"},
	"tomato": {"name": "Tomato", "seed": 40, "grown": 42, "icon": 44, "color": "df7566"},
	"lettuce": {"name": "Lettuce", "seed": 52, "grown": 54, "icon": 56, "color": "8bc37a"},
	"wheat": {"name": "Wheat", "seed": 64, "grown": 66, "icon": 68, "color": "d5b15b"}
}
const CHAPTERS: Array = ["First furrows", "Pebble paths", "Market baskets", "The gatehouse", "Twin wells", "Harvest festival"]
const STYLES: Array = [
	{"name": "Morning meadow", "price": 0, "grass": "a3cf86", "soil": "b78960", "water": "45bcc5"},
	{"name": "Peach sunrise", "price": 250, "grass": "c0cb89", "soil": "c49577", "water": "5eb6be"},
	{"name": "Lavender hour", "price": 600, "grass": "a6b69b", "soil": "a58b88", "water": "8abbd4"},
	{"name": "Golden harvest", "price": 1000, "grass": "c7cc7b", "soil": "b39a63", "water": "63bda8"}
]
const LOGIN: Array = [20, 25, 30, 40, 50, 65, 100]
static var _plots: Array = []

var coins: int = 80
var xp: int = 0
var records: Dictionary = {}
var total_harvests: int = 0
var saved_water: int = 0
var gate_clears: int = 0
var twin_clears: int = 0
var daily_total: int = 0
var style: int = 0
var owned_styles: Array = [0]
var sound: bool = true
var unlocked: Array = []
var day: String = ""
var login_day: String = ""
var login_streak: int = 0
var daily_done: bool = false
var daily_counts: Dictionary = {"plots": 0, "harvests": 0, "water": 0}
var quest_claimed: Array = []
var current_id: int = 0
var daily_mode: bool = false
var plot: Dictionary = {}
var edges: Dictionary = {}
var open_gates: Array = []
var history: Array = []
var assisted: bool = false
var hint_used: bool = false
var attempt_claimed: bool = false
var _nonce: int = 0
var _pending_reward: int = 0

func _init(date: String = "") -> void:
	roll_day(date if not date.is_empty() else Time.get_date_string_from_system(true))
	start_plot(0)

static func all_plots() -> Array:
	if _plots.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/plots.json"))
		if parsed is Array: _plots = _integer_data(parsed)
	return _plots

static func _integer_data(value: Variant) -> Variant:
	# JSON stores all numbers as doubles; cell membership must use one exact type.
	if value is float: return int(value)
	if value is Array:
		var list: Array = []
		for entry: Variant in value: list.append(_integer_data(entry))
		return list
	if value is Dictionary:
		var object: Dictionary = {}
		for key: Variant in value: object[key] = _integer_data(value[key])
		return object
	return value

static func definition(id: int) -> Dictionary:
	var data: Array = all_plots()
	return data[clampi(id, 0, data.size() - 1)].duplicate(true)

static func neighbors(cell: int) -> Array[int]:
	var out: Array[int] = []
	if cell < 0 or cell >= CELLS: return out
	for offset: int in [-7, 1, 7, -1]:
		var next: int = cell + offset
		if next >= 0 and next < CELLS and absi(next % 7 - cell % 7) + absi(next / 7 - cell / 7) == 1: out.append(next)
	return out

static func edge_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

static func pairs_from(state: Dictionary) -> Array:
	var out: Array = []
	for key: String in state:
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var a: int = int(parts[0]); var b: int = int(parts[1])
			if b in neighbors(a): out.append([a, b])
	return out

static func state_from(pairs: Array) -> Dictionary:
	var out: Dictionary = {}
	for edge: Variant in pairs:
		if edge is Array and edge.size() == 2:
			var a: int = int(edge[0]); var b: int = int(edge[1])
			if b in neighbors(a): out[edge_key(a, b)] = true
	return out

func start_plot(id: int, is_daily: bool = false) -> bool:
	if id < 0 or id >= 60: return false
	if not is_daily and id > unlocked_plot(): return false
	current_id = id; daily_mode = is_daily; plot = definition(id)
	edges = {}; open_gates = []; history = []; assisted = false; hint_used = false
	attempt_claimed = false; _pending_reward = 0
	return true

func unlocked_plot() -> int:
	var next: int = 0
	while next < 60 and records.has(str(next)): next += 1
	return mini(next, 59)

func level() -> int:
	return 1 + int(sqrt(float(xp) / 45.0))

func level_floor(which: int) -> int:
	return maxi(0, (which - 1) * (which - 1) * 45)

func stars() -> int:
	var total: int = 0
	for record: Dictionary in records.values(): total += int(record.get("stars", 0))
	return total

func perfect() -> int:
	var total: int = 0
	for record: Dictionary in records.values():
		if bool(record.get("unassisted_perfect", false)): total += 1
	return total

func stat(key: String) -> int:
	match key:
		"plots": return records.size()
		"stars": return stars()
		"level": return level()
		"xp": return xp
		"saved_water": return saved_water
		"harvests": return total_harvests
		"gates": return gate_clears
		"twins": return twin_clears
		"dailies": return daily_total
		"styles": return owned_styles.size() - 1
		"perfect": return perfect()
	return 0

func _remember() -> void:
	history.append({"edges": edges.duplicate(), "gates": open_gates.duplicate()})
	if history.size() > 100: history.pop_front()

func edit_edge(a: int, b: int, erase: bool = false) -> bool:
	if attempt_claimed or b not in neighbors(a): return false
	if a in plot.rocks or b in plot.rocks: return false
	var key: String = edge_key(a, b)
	if erase and not edges.has(key): return false
	if not erase and edges.has(key): return false
	_remember()
	if erase: edges.erase(key)
	else: edges[key] = true
	return true

func toggle_gate(cell: int) -> bool:
	if attempt_claimed or cell not in plot.gates: return false
	_remember()
	if cell in open_gates: open_gates.erase(cell)
	else: open_gates.append(cell)
	return true

func undo() -> bool:
	if history.is_empty() or attempt_claimed: return false
	var prior: Dictionary = history.pop_back()
	edges = prior.edges; open_gates = prior.gates
	return true

func reset_plan() -> void:
	if not edges.is_empty() or not open_gates.is_empty(): _remember()
	edges = {}; open_gates = []; attempt_claimed = false
	_pending_reward = 0
	# Assistance remains attached to the attempt, including after reset and undo.

func hint_action() -> Dictionary:
	var solution: Dictionary = state_from(plot.solution.edges)
	for pair: Array in pairs_from(edges):
		if not solution.has(edge_key(pair[0], pair[1])): return {"kind": "erase", "a": pair[0], "b": pair[1]}
	for gate: Variant in plot.solution.open_gates:
		if int(gate) not in open_gates: return {"kind": "gate", "cell": int(gate)}
	for pair: Array in plot.solution.edges:
		if not edges.has(edge_key(pair[0], pair[1])): return {"kind": "edge", "a": pair[0], "b": pair[1]}
	return {}

func begin_hint_reward() -> int:
	if _pending_reward != 0 or hint_used or attempt_claimed or hint_action().is_empty(): return 0
	_nonce += 1; _pending_reward = _nonce
	return _nonce

func finish_hint_reward(token: int, earned: bool) -> bool:
	if token == 0 or token != _pending_reward: return false
	_pending_reward = 0
	if not earned or attempt_claimed: return false
	var action: Dictionary = hint_action()
	if action.is_empty(): return false
	assisted = true; hint_used = true
	match action.kind:
		"gate": toggle_gate(int(action.cell))
		"edge": edit_edge(int(action.a), int(action.b))
		"erase": edit_edge(int(action.a), int(action.b), true)
	return true

static func simulate(data: Dictionary, channels: Dictionary, gates: Array) -> Dictionary:
	var graph: Dictionary = {}
	var blocked: Array = data.rocks.duplicate()
	for gate: Variant in data.gates:
		if int(gate) not in gates: blocked.append(int(gate))
	for pair: Array in pairs_from(channels):
		var a: int = int(pair[0]); var b: int = int(pair[1])
		if a in blocked or b in blocked: continue
		if not graph.has(a): graph[a] = []
		if not graph.has(b): graph[b] = []
		graph[a].append(b); graph[b].append(a)
	var seen: Dictionary = {}; var wet: Array = []; var events: Array = []
	var harvested: Dictionary = {}; var consumed: int = 0; var left: int = 0
	var supply: int = 0; var wet_distance: Dictionary = {}; var components: Array = []
	for source: Dictionary in data.sources: supply += int(source.water)
	for source: Dictionary in data.sources:
		var origin: int = int(source.cell)
		if seen.has(origin): continue
		var nodes: Array = [origin]; var component: Array = []; var cursor: int = 0
		seen[origin] = true
		while cursor < nodes.size():
			var at: int = int(nodes[cursor]); cursor += 1; component.append(at)
			var adjacent: Array = graph.get(at, []).duplicate(); adjacent.sort()
			for next: Variant in adjacent:
				if not seen.has(int(next)): seen[int(next)] = true; nodes.append(int(next))
		var budget: int = 0; var distance: Dictionary = {}; var wavefront: Array = []
		for tank: Dictionary in data.sources:
			if int(tank.cell) in component:
				budget += int(tank.water); distance[int(tank.cell)] = 0; wavefront.append(int(tank.cell))
		cursor = 0
		while cursor < wavefront.size():
			var at: int = int(wavefront[cursor]); cursor += 1
			for next: Variant in graph.get(at, []):
				if not distance.has(int(next)): distance[int(next)] = int(distance[at]) + 1; wavefront.append(int(next))
		var beds: Array = []
		for crop: Dictionary in data.crops:
			if int(crop.cell) in component:
				var bed: Dictionary = crop.duplicate(); bed["distance"] = int(distance.get(int(crop.cell), 0)); beds.append(bed)
		beds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.cell) < int(b.cell) if int(a.distance) == int(b.distance) else int(a.distance) < int(b.distance))
		var original: int = budget
		for bed: Dictionary in beds:
			var used: int = mini(budget, int(bed.cost)); budget -= used; consumed += used
			var grown: bool = used == int(bed.cost)
			if grown: harvested[str(bed.species)] = int(harvested.get(str(bed.species), 0)) + 1
			events.append({"cell": int(bed.cell), "species": str(bed.species), "cost": int(bed.cost), "used": used, "grown": grown, "distance": int(bed.distance)})
		left += budget
		components.append({"supply": original, "used": original - budget, "left": budget, "nodes": component})
		for cell: Variant in component:
			wet.append(int(cell)); wet_distance[str(cell)] = int(distance.get(int(cell), 0))
	wet.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(a) < int(b) if int(wet_distance.get(str(a), 0)) == int(wet_distance.get(str(b), 0)) else int(wet_distance.get(str(a), 0)) < int(wet_distance.get(str(b), 0)))
	var success: bool = true; var deficit: Dictionary = {}
	for species: String in data.orders:
		var shortfall: int = maxi(0, int(data.orders[species]) - int(harvested.get(species, 0)))
		if shortfall > 0: success = false; deficit[species] = shortfall
	var count: int = pairs_from(channels).size()
	var score: int = 0
	if success:
		score = 1
		if left >= int(data.reserve_goal): score += 1
		if count <= int(data.par_edges): score += 1
	return {"success": success, "stars": score, "supply": supply, "consumed": consumed, "left": left, "harvested": harvested, "events": events, "wet": wet, "distance": wet_distance, "edges": count, "deficit": deficit, "components": components}

func pulse() -> Dictionary:
	return simulate(plot, edges, open_gates)

func finish_plot(result: Dictionary) -> Dictionary:
	if attempt_claimed or not bool(result.get("success", false)): return {}
	# Recompute from the real current graph. Callers cannot submit a forged result.
	var actual: Dictionary = pulse()
	if not bool(actual.success): return {}
	attempt_claimed = true; _pending_reward = 0
	var fresh: bool = not records.has(str(current_id)) and not daily_mode
	var old_stars: int = int(records.get(str(current_id), {}).get("stars", 0))
	var new_stars: int = int(actual.stars)
	var bonus_coins: int = 0; var bonus_xp: int = 0; var level_before: int = level()
	var scoreable: bool = fresh or (daily_mode and not daily_done)
	if not daily_mode:
		var record: Dictionary = records.get(str(current_id), {"stars": 0, "unassisted_perfect": false, "reserve": 0})
		record.stars = maxi(old_stars, new_stars)
		record.reserve = maxi(int(record.reserve), int(actual.left))
		if not assisted and new_stars == 3: record.unassisted_perfect = true
		records[str(current_id)] = record
		if fresh:
			bonus_coins = 40 + int(plot.chapter) * 8; bonus_xp = 35 + int(plot.chapter) * 10
		elif new_stars > old_stars:
			bonus_coins = (new_stars - old_stars) * 12; bonus_xp = (new_stars - old_stars) * 10
	if daily_mode and not daily_done:
		daily_done = true; daily_total += 1; bonus_coins = 80; bonus_xp = 55
	if scoreable:
		var beds: int = 0
		for amount: Variant in actual.harvested.values(): beds += int(amount)
		total_harvests += beds; saved_water += int(actual.left)
		if not plot.gates.is_empty(): gate_clears += 1
		if plot.sources.size() == 2: twin_clears += 1
		daily_counts.plots = int(daily_counts.plots) + 1
		daily_counts.harvests = int(daily_counts.harvests) + beds
		daily_counts.water = int(daily_counts.water) + int(actual.left)
	coins += bonus_coins; xp += bonus_xp
	var level_bonus: int = 0
	for earned_level: int in range(level_before + 1, level() + 1): level_bonus += earned_level * 15
	coins += level_bonus
	return {"fresh": fresh, "coins": bonus_coins, "xp": bonus_xp, "level_bonus": level_bonus, "stars": new_stars, "reserve": int(actual.left), "used": int(actual.consumed), "assisted": assisted, "daily": daily_mode}

func roll_day(date: String) -> bool:
	if date.length() != 10 or date <= day: return false
	day = date; daily_done = false; daily_counts = {"plots": 0, "harvests": 0, "water": 0}; quest_claimed = []
	return true

func login_available() -> bool:
	return not day.is_empty() and login_day < day

func claim_login() -> int:
	if not login_available(): return 0
	var today: int = int(Time.get_unix_time_from_datetime_string(day + "T00:00:00"))
	var previous: int = int(Time.get_unix_time_from_datetime_string(login_day + "T00:00:00")) if login_day.length() == 10 else 0
	login_streak = login_streak % 7 + 1 if today - previous == 86400 else 1
	login_day = day; var value: int = int(LOGIN[login_streak - 1]); coins += value
	return value

func daily_plot_id() -> int:
	return posmod(int(Time.get_unix_time_from_datetime_string(day + "T00:00:00")) / 86400 + 17, 40)

func quest_ready(index: int) -> bool:
	if index in quest_claimed: return false
	match index:
		0: return int(daily_counts.plots) >= 2
		1: return int(daily_counts.harvests) >= 6
		2: return int(daily_counts.water) >= 3
	return false

func claim_quest(index: int) -> int:
	if not quest_ready(index): return 0
	quest_claimed.append(index); coins += 35
	return 35

func choose_style(index: int) -> bool:
	if index < 0 or index >= STYLES.size(): return false
	if index not in owned_styles:
		var price: int = int(STYLES[index].price)
		if coins < price: return false
		coins -= price; owned_styles.append(index)
	style = index
	return true

func to_data() -> Dictionary:
	return {"version": 1, "coins": coins, "xp": xp, "records": records.duplicate(true), "harvests": total_harvests, "water": saved_water, "gates": gate_clears, "twins": twin_clears, "dailies": daily_total, "style": style, "owned_styles": owned_styles.duplicate(), "sound": sound, "unlocked": unlocked.duplicate(), "day": day, "login_day": login_day, "login_streak": login_streak, "daily_done": daily_done, "daily_counts": daily_counts.duplicate(), "quest_claimed": quest_claimed.duplicate(), "draft": {"id": current_id, "daily": daily_mode, "edges": pairs_from(edges), "open_gates": open_gates.duplicate(), "assisted": assisted, "hint_used": hint_used, "claimed": attempt_claimed}}

func load_data(data: Dictionary) -> void:
	coins = clampi(int(data.get("coins", 80)), 0, 999999999); xp = clampi(int(data.get("xp", 0)), 0, 99999999)
	records = {}
	var raw: Variant = data.get("records", {})
	if raw is Dictionary:
		for key: Variant in raw:
			if str(key).is_valid_int() and int(key) >= 0 and int(key) < 60 and raw[key] is Dictionary:
				var value: Dictionary = raw[key]; var rating: int = clampi(int(value.get("stars", 0)), 0, 3)
				if rating > 0: records[str(key)] = {"stars": rating, "reserve": clampi(int(value.get("reserve", 0)), 0, 99), "unassisted_perfect": bool(value.get("unassisted_perfect", false)) and rating == 3}
	total_harvests = clampi(int(data.get("harvests", 0)), 0, 9999999); saved_water = clampi(int(data.get("water", 0)), 0, 9999999)
	gate_clears = clampi(int(data.get("gates", 0)), 0, 99999); twin_clears = clampi(int(data.get("twins", 0)), 0, 99999); daily_total = clampi(int(data.get("dailies", 0)), 0, 99999)
	owned_styles = [0]
	if data.get("owned_styles", []) is Array:
		for value: Variant in data.get("owned_styles", []):
			if int(value) in [1, 2, 3] and int(value) not in owned_styles: owned_styles.append(int(value))
	style = int(data.get("style", 0)); style = style if style in owned_styles else 0
	sound = bool(data.get("sound", true)); unlocked = data.get("unlocked", []).duplicate() if data.get("unlocked", []) is Array else []
	var saved_day: String = str(data.get("day", ""))
	if saved_day.length() == 10 and saved_day > day: day = saved_day
	if saved_day == day:
		daily_done = bool(data.get("daily_done", false)); quest_claimed = []
		if data.get("quest_claimed", []) is Array:
			for value: Variant in data.quest_claimed:
				if int(value) in [0, 1, 2] and int(value) not in quest_claimed: quest_claimed.append(int(value))
		if data.get("daily_counts", {}) is Dictionary:
			for key: String in daily_counts: daily_counts[key] = clampi(int(data.daily_counts.get(key, 0)), 0, 99999)
	login_day = str(data.get("login_day", "")); login_streak = clampi(int(data.get("login_streak", 0)), 0, 7)
	var draft: Variant = data.get("draft", {})
	if draft is Dictionary and start_plot(clampi(int(draft.get("id", 0)), 0, 59), bool(draft.get("daily", false))):
		if draft.get("edges", []) is Array:
			for pair: Array in pairs_from(state_from(draft.edges)):
				if pair[0] not in plot.rocks and pair[1] not in plot.rocks: edges[edge_key(pair[0], pair[1])] = true
		if draft.get("open_gates", []) is Array:
			for cell: Variant in draft.open_gates:
				if int(cell) in plot.gates and int(cell) not in open_gates: open_gates.append(int(cell))
		assisted = bool(draft.get("assisted", false)); hint_used = bool(draft.get("hint_used", false)); attempt_claimed = bool(draft.get("claimed", false))

func save_file(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(to_data())); file.close()
	var absolute: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"): DirAccess.remove_absolute(absolute + ".bak")
		if DirAccess.rename_absolute(absolute, absolute + ".bak") != OK: return false
	return DirAccess.rename_absolute(absolute + ".tmp", absolute) == OK

func load_file(path: String) -> bool:
	for candidate: String in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parser: JSON = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK: continue
		var parsed: Variant = parser.data
		if parsed is Dictionary and int(parsed.get("version", 0)) == 1: load_data(parsed); return true
	return false
