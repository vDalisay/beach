class_name RunSession
extends Node

signal items_changed(ids: PackedStringArray)
signal bags_changed(ids: PackedStringArray)
signal hands_changed(player_id: StringName)
signal wallet_changed(player_id: StringName)
signal progress_changed(waste: int, props: int, required: int)
signal group_completed(payload: Dictionary)
signal section_restored(section_id: StringName)
signal zone_restored(zone_id: StringName)
signal run_completed(receipt: Dictionary)
signal save_requested(revision: int)

var state: RunState
var item_store: ItemStore
var item_view_manager: ItemViewManager
var placement_service: PlacementService
var cloth_tool: ClothTool
var sorting_stations: Dictionary = {}
var waste_containers: Dictionary = {}
var collection_service: CollectionService
var progression: ProgressionService
var sand_cleaner: SandCleaner
var vacuum_tool: VacuumTool
var metal_detector: MetalDetector
var swim_service: SwimService
var rescue_knife: RescueKnife
var scanner: ScannerService
var progress_service: ProgressService
var definitions: Dictionary = {}
var results_open := false

var _publishing := false
var _draining_deferred := false
var _deferred_actions: Array[Callable] = []


func initialize(initial_state: RunState, item_definitions: Dictionary) -> void:
	state = initial_state
	definitions = item_definitions
	item_store = ItemStore.new(self, definitions)
	progress_service = ProgressService.new()
	progress_service.configure(self)


func _process(delta: float) -> void:
	if state != null and not results_open and not get_tree().paused:
		state.elapsed_active_seconds += delta


func is_publishing() -> bool:
	return _publishing


func defer_action(action: Callable) -> ActionResult:
	_deferred_actions.append(action)
	return ActionResult.rejected(ActionResult.Reason.DEFERRED, "Action queued until publication completes")


func finalize_action(
	changed_ids: PackedStringArray,
	hand_players: PackedStringArray = [],
	wallet_players: PackedStringArray = [],
	changed_bag_ids: PackedStringArray = []
) -> void:
	state.prune_recovery_piles()
	var notices := progress_service.finalize(changed_ids)
	state.revision += 1
	_publishing = true
	if not changed_ids.is_empty():
		progress_changed.emit(progress_service.completed_waste, progress_service.completed_props, state.required_total)
	if not changed_ids.is_empty():
		items_changed.emit(changed_ids)
	if not changed_bag_ids.is_empty():
		bags_changed.emit(changed_bag_ids)
	for player_id in hand_players:
		hands_changed.emit(StringName(player_id))
	for player_id in notices.wallet_players:
		if str(player_id) not in wallet_players:
			wallet_players.append(str(player_id))
	for player_id in wallet_players:
		wallet_changed.emit(StringName(player_id))
	for payload in notices.groups:
		group_completed.emit(payload as Dictionary)
	for section_id in notices.sections:
		section_restored.emit(StringName(str(section_id)))
	for zone_id in notices.zones:
		zone_restored.emit(StringName(str(zone_id)))
	if not (notices.completed as Dictionary).is_empty():
		run_completed.emit((notices.completed as Dictionary).duplicate(true))
	save_requested.emit(state.revision)
	_publishing = false
	_drain_deferred_actions()


func _drain_deferred_actions() -> void:
	if _draining_deferred:
		return
	_draining_deferred = true
	while not _deferred_actions.is_empty():
		var action: Callable = _deferred_actions.pop_front()
		action.call()
	_draining_deferred = false
