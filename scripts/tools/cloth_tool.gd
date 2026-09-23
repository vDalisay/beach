class_name ClothTool
extends Node

signal feedback_requested(message: String)

const TOOL_ID := &"cloth"

var session: RunSession
var player: BeachPlayer
var interactor: PlayerInteractor


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	interactor = player.interactor
	session.cloth_tool = self
	if not interactor.primary_requested.is_connected(_on_primary_requested):
		interactor.primary_requested.connect(_on_primary_requested)


func try_clean(player_id: StringName, item_id: StringName, patch_id: StringName, target_context: Dictionary = {}) -> ActionResult:
	if session.is_publishing():
		return session.defer_action(try_clean.bind(player_id, item_id, patch_id, target_context))
	if not session.state.players.has(player_id) or not session.state.items.has(item_id):
		return ActionResult.rejected(ActionResult.Reason.MISSING_ID, "Missing player or dirty item")
	var player_record := session.state.players[player_id] as Dictionary
	if _active_tool(player_record) != TOOL_ID or TOOL_ID not in (player_record[&"owned_tools"] as Array[StringName]):
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Cleaning requires the cloth")
	var record := session.state.items[item_id] as ItemRecord
	var definition := session.definitions.get(record.definition_id) as ItemDefinition
	if record.location != ItemRecord.Location.WORLD or definition == null or definition.kind != ItemDefinition.Kind.PROP:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Only world furniture stains can be cleaned")
	if patch_id not in record.dirty_patches_remaining:
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "Stain is already clean")
	var target_error := _validate_target_context(item_id, patch_id, target_context)
	if target_error != null:
		return target_error
	record.dirty_patches_remaining.erase(patch_id)
	session.finalize_action(PackedStringArray([str(item_id)]))
	var view := session.item_view_manager.view_for(item_id) if session.item_view_manager != null else null
	if view != null:
		view.clean_dirt_patch(patch_id)
	interactor.clear_target()
	return ActionResult.accepted(PackedStringArray([str(item_id)]), {
		"item_id": str(item_id),
		"patch_id": str(patch_id),
		"remaining": record.dirty_patches_remaining.size(),
		"clean": record.dirty_patches_remaining.is_empty(),
	})


func _active_tool(player_record: Dictionary) -> StringName:
	var equipped := player_record[&"equipped_handheld_ids"] as Array[StringName]
	var active_slot := int(player_record.get("active_slot", 0))
	return equipped[active_slot] if active_slot >= 0 and active_slot < equipped.size() else StringName()


func _validate_target_context(item_id: StringName, patch_id: StringName, context: Dictionary) -> ActionResult:
	if context.is_empty():
		return null
	if StringName(str(context.get("target_id", ""))) != item_id or StringName(str(context.get("patch_id", ""))) != patch_id or not bool(context.get("visible", false)):
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Stain is not the visible target")
	if float(context.get("distance", INF)) > float(context.get("reach", 0.0)) + 0.01:
		return ActionResult.rejected(ActionResult.Reason.BLOCKED_TARGET, "Stain is out of reach")
	return null


func _on_primary_requested(target: Dictionary) -> void:
	if not (target.get("actions", PackedStringArray()) as PackedStringArray).has("clean"):
		return
	var result := try_clean(&"local", StringName(str(target.get("id", ""))), StringName(str(target.get("patch_id", ""))), {
		"target_id": str(target.get("id", "")),
		"patch_id": str(target.get("patch_id", "")),
		"visible": true,
		"distance": float(target.get("distance", INF)),
		"reach": interactor.reach,
	})
	if not result.ok:
		feedback_requested.emit(result.message)
