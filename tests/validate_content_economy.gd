extends SceneTree

const REQUIRED := [&"cloth", &"knife", &"detector", &"oxygen_tank"]
const SAMPLE_SEEDS := ["p26-economy", "arrival", "deep-reef"]

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var offers: Array[Resource] = []
	var ids: Array[StringName] = []
	for path in ProgressionService.TOOL_PATHS + ProgressionService.UPGRADE_PATHS:
		var definition := load(path) as Resource
		if definition is ToolDefinition:
			ids.append((definition as ToolDefinition).tool_id)
		elif definition is UpgradeDefinition:
			ids.append((definition as UpgradeDefinition).upgrade_id)
		else:
			check(false, "purchase resource loads: %s" % path)
			continue
		offers.append(definition)
	check(ids.size() == 19, "all 19 purchasable resources load")
	if ids.size() != 19:
		quit(1)
		return
	var prices := PackedInt32Array()
	var prerequisites := PackedInt32Array()
	var total_prices := 0
	for definition in offers:
		var price := (definition as ToolDefinition).shop_price if definition is ToolDefinition else (definition as UpgradeDefinition).price
		var prerequisite := (definition as ToolDefinition).upgrade_prerequisite if definition is ToolDefinition else (definition as UpgradeDefinition).prerequisite
		prices.append(price)
		prerequisites.append(ids.find(prerequisite) if not prerequisite.is_empty() else -1)
		check(prerequisite.is_empty() or ids.has(prerequisite), "purchase prerequisite exists: %s" % prerequisite)
		total_prices += price
	check(total_prices == 5300, "all listed purchases cost $5,300")

	var generator := ManifestGenerator.new()
	var anchors := load(ManifestGenerator.ANCHORS_PATH) as Resource
	var packs := anchors.get_meta(&"packs") as Dictionary
	var minimum_dry := 5400
	var reachable_masks := 0
	for seed_text in SAMPLE_SEEDS:
		var generated := generator.generate(seed_text)
		check(bool(generated.get("ok", false)), "full manifest generates for %s" % seed_text)
		if not generated.get("ok", false):
			continue
		var income := _income_by_access(generated, packs)
		check(income[15] == 5400, "all four access purchases expose every waste ID")
		minimum_dry = mini(minimum_dry, income[0])
		var proof := _prove(ids, prices, prerequisites, income)
		check(bool(proof.ok), "base-only economy remains finishable after every reachable purchase set for %s: %s" % [seed_text, proof.witness])
		reachable_masks = maxi(reachable_masks, int(proof.reachable))
	var optional_before_tank := 0
	for index in ids.size():
		if ids[index] not in REQUIRED and not _depends_on(index, ids.find(&"oxygen_tank"), prerequisites):
			optional_before_tank += prices[index]
	check(optional_before_tank == 2160 and minimum_dry - optional_before_tank - 490 >= 0, "all optional-first purchases leave the $490 access route affordable from dry waste alone")

	# The balance-document counterexample must be detected if the expensive tools
	# are left ungated and only $1,000 of base-pay waste is available.
	var old_prerequisites := prerequisites.duplicate()
	old_prerequisites[ids.find(&"sand_cleaner")] = -1
	old_prerequisites[ids.find(&"vacuum")] = -1
	var low_income := PackedInt32Array()
	for _index in 16:
		low_income.append(1000)
	var optional_first := _prove(ids, prices, old_prerequisites, low_income)
	check(not optional_first.ok and bool(optional_first.optional_990_dead), "$1,000-accessible $990 optional-first fixture finds a dead end")
	var optional_cost := 0
	for purchase_id in [&"vacuum", &"sand_cleaner", &"scanner", &"walking_1", &"bag_40"]:
		optional_cost += prices[ids.find(purchase_id)]
	check(optional_cost == 990 and 1000 - optional_cost < prices[ids.find(&"cloth")], "documented $990 optional sequence leaves too little for cloth")
	print("P26_CONTENT_ECONOMY seeds=%d dry_min=%d optional_before_tank=%d access=490 total=5400 prices=%d reachable_sets=%d optional_fixture=dead_end failures=%d" % [SAMPLE_SEEDS.size(), minimum_dry, optional_before_tank, total_prices, reachable_masks, failures])
	quit(failures)


func _income_by_access(generated: Dictionary, packs: Dictionary) -> PackedInt32Array:
	var buckets := PackedInt32Array()
	buckets.resize(16)
	var definitions := generated.definitions as Dictionary
	for row_value in generated.rows:
		var row := row_value as Dictionary
		if not bool(row.required) or str(row.kind) != "waste":
			continue
		var definition := definitions[StringName(str(row.definition_id))] as ItemDefinition
		var required_mask := 0
		match definition.required_tool:
			&"cloth": required_mask |= 1
			&"knife": required_mask |= 2
			&"detector": required_mask |= 4
			&"": pass
			_: check(false, "unknown waste access tool: %s" % definition.required_tool)
		var pack := packs[StringName(str(row.section_id))] as Dictionary
		if "water_surface" in pack.tags or "seabed" in pack.tags:
			required_mask |= 8
		for mask in 16:
			if mask & required_mask == required_mask:
				buckets[mask] += 1
	return buckets


func _prove(ids: Array[StringName], prices: PackedInt32Array, prerequisites: PackedInt32Array, income: PackedInt32Array) -> Dictionary:
	var size := 1 << ids.size()
	var visited := PackedByteArray()
	visited.resize(size)
	var viable := PackedByteArray()
	viable.resize(size)
	var costs := PackedInt32Array()
	costs.resize(size)
	var parents := PackedInt32Array()
	parents.resize(size)
	var parent_purchases := PackedByteArray()
	parent_purchases.resize(size)
	var queue: Array[int] = [0]
	visited[0] = 1
	var cursor := 0
	while cursor < queue.size():
		var mask := queue[cursor]
		cursor += 1
		var balance := income[_access_mask(mask, ids)] - costs[mask]
		for index in ids.size():
			var bit := 1 << index
			if mask & bit or (prerequisites[index] >= 0 and not mask & (1 << prerequisites[index])) or prices[index] > balance:
				continue
			var next := mask | bit
			if visited[next]:
				continue
			visited[next] = 1
			costs[next] = costs[mask] + prices[index]
			parents[next] = mask
			parent_purchases[next] = index
			queue.append(next)

	var required_mask := 0
	for purchase_id in REQUIRED:
		required_mask |= 1 << ids.find(purchase_id)
	var dead := -1
	for mask in range(size - 1, -1, -1):
		if not visited[mask]:
			continue
		if mask & required_mask == required_mask:
			viable[mask] = 1
		else:
			var balance := income[_access_mask(mask, ids)] - costs[mask]
			for index in ids.size():
				if not mask & (1 << index) and (prerequisites[index] < 0 or mask & (1 << prerequisites[index])) and prices[index] <= balance and viable[mask | (1 << index)]:
					viable[mask] = 1
					break
		if not viable[mask]:
			dead = mask
	var witness := ""
	if dead >= 0:
		var sequence: Array[String] = []
		var step := dead
		while step != 0:
			sequence.push_front(str(ids[parent_purchases[step]]))
			step = parents[step]
		witness = "%s, balance=$%d, accessible=%d" % [" -> ".join(sequence), income[_access_mask(dead, ids)] - costs[dead], income[_access_mask(dead, ids)]]
	var optional_mask := 0
	for purchase_id in [&"vacuum", &"sand_cleaner", &"scanner", &"walking_1", &"bag_40"]:
		optional_mask |= 1 << ids.find(purchase_id)
	return {"ok": dead < 0, "witness": witness, "reachable": queue.size(), "optional_990_dead": bool(visited[optional_mask]) and not bool(viable[optional_mask])}


func _access_mask(purchases: int, ids: Array[StringName]) -> int:
	var result := 0
	for index in REQUIRED.size():
		if purchases & (1 << ids.find(REQUIRED[index])):
			result |= 1 << index
	return result


func _depends_on(index: int, ancestor: int, prerequisites: PackedInt32Array) -> bool:
	var step := prerequisites[index]
	while step >= 0:
		if step == ancestor:
			return true
		step = prerequisites[step]
	return false


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("P26 FAIL: " + message)
