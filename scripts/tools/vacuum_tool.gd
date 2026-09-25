class_name VacuumTool
extends Node

signal feedback_requested(message: String)

const TOOL_ID := &"vacuum"
const FEEL := preload("res://data/feel/feel_tuning.tres")

var session: RunSession
var player: BeachPlayer
var definition: ToolDefinition
## Suction motes drifting into the nozzle while the vacuum runs (presentation only).
var motes: ParticlePool
var _elapsed := 0.0
var _started := false
var _blocked_until_release := false
var _mote_budget := 0.0
var _mote_rng := RandomNumberGenerator.new()


func configure(run_session: RunSession, player_body: BeachPlayer) -> void:
	session = run_session
	player = player_body
	definition = session.progression.offers[TOOL_ID] as ToolDefinition
	session.vacuum_tool = self
	process_physics_priority = 1
	if motes == null:
		motes = ParticlePool.create(ParticlePool.Kind.DUST, 48)
		motes.drag = 0.0
		motes.rise = 0.0
		motes.grow = -0.6
		motes.tint = Color(FEEL.dust_color, 0.8)
		add_child(motes)
	_mote_rng.seed = 1  # cosmetic stream, never gameplay
	set_physics_process(true)


func is_active() -> bool:
	return session != null and session.progression.active_tool_id(&"local") == TOOL_ID and session.progression.is_owned(&"local", TOOL_ID) and (session.state.players[&"local"].held_objects as Array).is_empty()


func range_meters() -> float:
	if session.progression.is_owned(&"local", &"vacuum_2"):
		return (session.progression.offers[&"vacuum_2"] as UpgradeDefinition).secondary_value
	return definition.range


func interval_seconds() -> float:
	if session.progression.is_owned(&"local", &"vacuum_2"):
		return 1.0 / (session.progression.offers[&"vacuum_2"] as UpgradeDefinition).exact_value
	return definition.use_interval


func suppress_until_release() -> void:
	_blocked_until_release = true
	_started = false
	_elapsed = 0.0


func try_collect_next() -> ActionResult:
	if not is_active():
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Equip the vacuum")
	var record := session.state.players[&"local"] as Dictionary
	if (record.trash_bag as Array).size() + (record.valuable_bag as Array).size() >= int(record.bag_capacity):
		return ActionResult.rejected(ActionResult.Reason.CAPACITY, "Bag full")
	var origin := player.camera.global_position
	var forward := -player.camera.global_basis.z.normalized()
	var cone_cosine := cos(deg_to_rad(definition.cone_degrees))
	for view in CleanupTargetQuery.nearby_waste(session, player, origin, range_meters()):
		var offset := view.global_position + Vector3.UP * WorldItem.profile_size(view.definition.collision_profile).y * 0.5 - origin
		if offset.length() > range_meters() or offset.normalized().dot(forward) < cone_cosine or not CleanupTargetQuery.visible_from_camera(player, view):
			continue
		var result := session.item_store.try_collect(&"local", view.item_id, {
			"target_id": str(view.item_id), "visible": true,
			"distance": offset.length(), "reach": range_meters(),
		})
		if result.ok:
			player.carry.present_collected(view.item_id, &"vacuum")
			player.play_cue(&"vacuum_tick")
			return result
	return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "No eligible litter in cone")


func _physics_process(delta: float) -> void:
	if not is_active() or not player.input_reader.pressed(&"primary"):
		_elapsed = 0.0
		_started = false
		_blocked_until_release = false
		return
	if _blocked_until_release:
		return
	player.hand_rig.set_tool_activity(&"vacuum", 1.0)
	_emit_motes(delta)
	_elapsed += delta
	if not _started:
		_started = true
		_elapsed = 0.0
		_attempt_tick()
		return
	while _elapsed >= interval_seconds():
		_elapsed -= interval_seconds()
		_attempt_tick()
		if _blocked_until_release:
			return


func _attempt_tick() -> void:
	var result := try_collect_next()
	if not result.ok and result.reason == ActionResult.Reason.CAPACITY:
		feedback_requested.emit("Bag full")
		player.play_cue(&"vacuum_full", {"reason": "Bag full"})
		_blocked_until_release = true


## Motes appear along the cone and flow into the visible nozzle, arriving as they fade.
func _emit_motes(delta: float) -> void:
	var reduced := FeelMotion.reduced(player.settings_store)
	_mote_budget += delta * FEEL.vacuum_mote_rate * (0.5 if reduced else 1.0)
	var nozzle := player.hand_rig.tool_tip().global_position
	var basis := player.camera.global_basis
	while _mote_budget >= 1.0:
		_mote_budget -= 1.0
		var direction := (-basis.z + basis.x * _mote_rng.randf_range(-0.35, 0.35) + basis.y * _mote_rng.randf_range(-0.2, 0.2)).normalized()
		var start := player.camera.global_position + direction * _mote_rng.randf_range(1.5, range_meters())
		var to_nozzle := nozzle - start
		motes.emit(start, to_nozzle.normalized() * FEEL.vacuum_mote_speed, _mote_rng.randf_range(0.02, 0.035), to_nozzle.length() / FEEL.vacuum_mote_speed)
