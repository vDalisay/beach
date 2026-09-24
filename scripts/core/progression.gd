class_name ProgressionService
extends Node

const STICK_SCENE := preload("res://art/synty/wrappers/tool_poking_stick.tscn")
const TOOL_PATHS := [
	"res://data/tools/cloth.tres", "res://data/tools/knife.tres", "res://data/tools/flippers.tres",
	"res://data/tools/detector.tres", "res://data/tools/oxygen_tank.tres",
	"res://data/tools/sand_cleaner.tres", "res://data/tools/vacuum.tres",
]
const UPGRADE_PATHS := [
	"res://data/upgrades/bag_40.tres", "res://data/upgrades/walking_1.tres",
	"res://data/upgrades/bag_80.tres", "res://data/upgrades/scanner.tres",
	"res://data/upgrades/reach_1.tres", "res://data/upgrades/walking_2.tres",
	"res://data/upgrades/bag_140.tres", "res://data/upgrades/reach_2.tres",
	"res://data/upgrades/unlimited_breathing.tres", "res://data/upgrades/bag_200.tres",
	"res://data/upgrades/sand_cleaner_2.tres", "res://data/upgrades/vacuum_2.tres",
]
const SHOP_ORDER: Array[StringName] = [
	&"cloth", &"knife", &"bag_40", &"flippers", &"detector", &"oxygen_tank",
	&"bag_80", &"sand_cleaner", &"vacuum", &"bag_140", &"unlimited_breathing",
	&"bag_200", &"sand_cleaner_2", &"vacuum_2",
]
const BOOKLET_ORDER: Array[StringName] = [&"walking_1", &"scanner", &"reach_1", &"walking_2", &"reach_2"]

var session: RunSession
var player: BeachPlayer
var shop: EquipmentShop
var offers: Dictionary = {}


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	for path in TOOL_PATHS + UPGRADE_PATHS:
		var definition := load(path) as Resource
		if definition is ToolDefinition:
			offers[(definition as ToolDefinition).tool_id] = definition
		elif definition is UpgradeDefinition:
			offers[(definition as UpgradeDefinition).upgrade_id] = definition
	session.progression = self
	player.carry.tool_switch_requested.connect(_on_tool_switch_requested)
	session.hands_changed.connect(_on_hands_changed)
	recompute_stats(&"local")
	refresh_tool_visual()


func ordered_offers(source: UpgradeDefinition.Source) -> Array[StringName]:
	return SHOP_ORDER if source == UpgradeDefinition.Source.SHOP else BOOKLET_ORDER


func is_owned(player_id: StringName, purchase_id: StringName) -> bool:
	if not session.state.players.has(player_id):
		return false
	var record := session.state.players[player_id] as Dictionary
	if purchase_id == &"stick":
		return true
	if not offers.has(purchase_id):
		return false
	var definition := offers[purchase_id] as Resource
	if definition is ToolDefinition:
		return purchase_id in (record.owned_tools as Array[StringName]) or purchase_id in (record.owned_gear as Array[StringName])
	return int((record.upgrade_levels as Dictionary).get(purchase_id, 0)) > 0


func try_purchase(player_id: StringName, purchase_id: StringName, source: UpgradeDefinition.Source) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_purchase.bind(player_id, purchase_id, source))
	if not session.state.players.has(player_id) or not offers.has(purchase_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Unknown player or purchase")
	var definition := offers[purchase_id] as Resource
	var tool := definition as ToolDefinition
	var upgrade := definition as UpgradeDefinition
	if (tool != null and source != UpgradeDefinition.Source.SHOP) or (upgrade != null and upgrade.source != source):
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Purchase must use its listed source")
	if source == UpgradeDefinition.Source.SHOP and (shop == null or not shop.player_near_counter()):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Visit the physical shop counter")
	if (tool != null and not tool.implemented) or (upgrade != null and not upgrade.implemented):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Coming in a later implementation packet")
	if is_owned(player_id, purchase_id):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Already owned")
	var prerequisite := tool.upgrade_prerequisite if tool != null else upgrade.prerequisite
	if not prerequisite.is_empty() and not is_owned(player_id, prerequisite):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Requires %s" % offer_name(prerequisite))
	var price := tool.shop_price if tool != null else upgrade.price
	var record := session.state.players[player_id] as Dictionary
	if int(record.money) < price:
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Need $%d more" % (price - int(record.money)))
	record.money = int(record.money) - price
	if tool != null:
		if tool.handheld:
			(record.owned_tools as Array[StringName]).append(purchase_id)
		else:
			(record.owned_gear as Array[StringName]).append(purchase_id)
	else:
		(record.upgrade_levels as Dictionary)[purchase_id] = upgrade.level
	recompute_stats(player_id)
	session.finalize_action(PackedStringArray(), PackedStringArray(), PackedStringArray([str(player_id)]))
	if shop != null:
		shop.refresh_rack()
	return ActionResult.accepted(PackedStringArray(), {"purchase_id": str(purchase_id), "price": price, "balance": int(record.money)})


func try_equip(player_id: StringName, tool_id: StringName, slot: int) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_equip.bind(player_id, tool_id, slot))
	if not session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "Missing player")
	if shop == null or not shop.player_near_rack():
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Use the physical tool rack")
	if slot < 0 or slot >= 2:
		return ActionResult.rejected(ActionResult.Reason.INVALID_REFERENCE, "Choose slot 1 or 2")
	if not is_owned(player_id, tool_id) or (tool_id != &"stick" and (not offers.has(tool_id) or not offers[tool_id] is ToolDefinition or not (offers[tool_id] as ToolDefinition).handheld)):
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Tool is not owned")
	var record := session.state.players[player_id] as Dictionary
	if not (record.held_objects as Array).is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Place or throw carried objects first")
	var equipped := record.equipped_handheld_ids as Array[StringName]
	if tool_id in equipped and (slot >= equipped.size() or equipped[slot] != tool_id):
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Tool is already in another slot")
	if slot > equipped.size():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Fill slot 1 first")
	if slot == equipped.size():
		equipped.append(tool_id)
	else:
		equipped[slot] = tool_id
	record.active_slot = slot
	refresh_tool_visual()
	session.finalize_action(PackedStringArray(), PackedStringArray([str(player_id)]))
	return ActionResult.accepted(PackedStringArray(), {"tool_id": str(tool_id), "slot": slot})


func try_switch_tool(player_id: StringName) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_switch_tool.bind(player_id))
	if not session.state.players.has(player_id):
		return ActionResult.rejected(ActionResult.Reason.INVALID_OWNER, "Missing player")
	var record := session.state.players[player_id] as Dictionary
	var equipped := record.equipped_handheld_ids as Array[StringName]
	if equipped.size() < 2:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Equip a second tool at the shop rack")
	if not (record.held_objects as Array).is_empty():
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Place or throw carried objects first")
	record.active_slot = 1 - int(record.active_slot)
	refresh_tool_visual()
	session.finalize_action(PackedStringArray(), PackedStringArray([str(player_id)]))
	return ActionResult.accepted(PackedStringArray(), {"active_tool": str(equipped[int(record.active_slot)])})


func recompute_stats(player_id: StringName) -> void:
	var record := session.state.players[player_id] as Dictionary
	var levels := record.upgrade_levels as Dictionary
	var bag_capacity := 20
	var walk_speed := 3.5
	var reach := 2.5
	for purchase_id in levels:
		if int(levels[purchase_id]) <= 0 or not offers.has(purchase_id):
			continue
		var upgrade := offers[purchase_id] as UpgradeDefinition
		if upgrade == null:
			continue
		match upgrade.affected_stat:
			&"bag_capacity": bag_capacity = maxi(bag_capacity, int(upgrade.exact_value))
			&"walk_speed": walk_speed = maxf(walk_speed, upgrade.exact_value)
			&"interaction_reach": reach = maxf(reach, upgrade.exact_value)
	record.bag_capacity = bag_capacity
	player.movement.walk_speed = walk_speed
	player.interactor.reach = reach
	player.movement.set_swim_speed(4.0 if &"flippers" in (record.owned_gear as Array[StringName]) else 2.5)


func max_air_seconds(player_id: StringName) -> float:
	if is_owned(player_id, &"unlimited_breathing"):
		return INF
	return 60.0 if is_owned(player_id, &"oxygen_tank") else 10.0


func active_tool_id(player_id: StringName) -> StringName:
	if not session.state.players.has(player_id):
		return StringName()
	var record := session.state.players[player_id] as Dictionary
	var equipped := record.equipped_handheld_ids as Array[StringName]
	var slot := int(record.active_slot)
	return equipped[slot] if slot >= 0 and slot < equipped.size() else StringName()


func offer_name(purchase_id: StringName) -> String:
	var definition := offers.get(purchase_id) as Resource
	if definition is ToolDefinition:
		return (definition as ToolDefinition).display_name
	if definition is UpgradeDefinition:
		return (definition as UpgradeDefinition).display_name
	return str(purchase_id)


func refresh_tool_visual() -> void:
	var record := session.state.players[&"local"] as Dictionary
	if not (record.held_objects as Array).is_empty():
		player.hand_rig.clear_tool()
		return
	var equipped := record.equipped_handheld_ids as Array[StringName]
	var slot := int(record.active_slot)
	var tool_id := equipped[slot] if slot >= 0 and slot < equipped.size() else &"stick"
	var definition := offers.get(tool_id) as ToolDefinition
	var scene: PackedScene = STICK_SCENE if tool_id == &"stick" else (load(definition.scene_path) as PackedScene if definition != null and not definition.scene_path.is_empty() else null)
	var visual := player.hand_rig.set_tool_scene(scene)
	if visual != null and tool_id == &"stick":
		visual.position = Vector3(0.02, -0.16, 0.05)
		visual.rotation = Vector3(-0.9, 0.0, -0.15)
		visual.scale = Vector3.ONE * 0.48
	elif visual != null and tool_id == &"cloth":
		visual.position = Vector3(-0.03, -0.03, 0.0)
		visual.scale = Vector3.ONE * 0.65
	elif visual != null and tool_id == &"knife":
		visual.position = Vector3(-0.05, -0.06, 0.0)
		visual.scale = Vector3.ONE * 0.75
	elif visual != null and tool_id in [&"sand_cleaner", &"vacuum", &"detector"]:
		visual.scale = Vector3.ONE * 0.5


func _on_tool_switch_requested() -> void:
	var result := try_switch_tool(&"local")
	if not result.ok:
		player.carry.feedback_requested.emit(result.message)


func _on_hands_changed(_player_id: StringName) -> void:
	refresh_tool_visual()
