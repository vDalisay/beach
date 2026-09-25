class_name MetalDetector
extends Node3D

signal feedback_requested(message: String)

const TOOL_ID := &"detector"
const FEEL := preload("res://data/feel/feel_tuning.tres")

var session: RunSession
var player: BeachPlayer
var finds: BuriedFind
var definition: ToolDefinition
var meter: Control
var distance_label: Label
var strength_bar: ProgressBar
var marker: MeshInstance3D
var nearest_find: ItemRecord
var _scan_elapsed := 0.0
var _ping_elapsed := 0.0


func configure(run_session: RunSession, player_body: BeachPlayer, buried_finds: BuriedFind, detector_meter: Control) -> void:
	session = run_session
	player = player_body
	finds = buried_finds
	definition = session.progression.offers[TOOL_ID] as ToolDefinition
	meter = detector_meter
	distance_label = meter.get_node("Panel/Content/Distance") as Label
	strength_bar = meter.get_node("Panel/Content/Strength") as ProgressBar
	marker = MeshInstance3D.new()
	marker.name = "DetectorSurfaceSignal"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.44
	ring.outer_radius = 0.48
	ring.rings = 8
	ring.ring_segments = 24
	marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.75, 0.2, 0.8)
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.hide()
	meter.hide()
	set_physics_process(true)


func is_active() -> bool:
	return session != null and player.input_enabled and session.progression.active_tool_id(&"local") == TOOL_ID and session.progression.is_owned(&"local", TOOL_ID) and (session.state.players[&"local"].held_objects as Array).is_empty()


func try_click() -> ActionResult:
	if not is_active():
		return ActionResult.rejected(ActionResult.Reason.TOOL_REQUIRED, "Equip the metal detector")
	if nearest_find == null or nearest_find.location != ItemRecord.Location.BURIED:
		player.play_cue(&"rejected", {"reason": "No buried signal within 4 m"})
		return ActionResult.rejected(ActionResult.Reason.WRONG_STATE, "No buried signal within 4 m")
	var result := finds.try_reveal(&"local", nearest_find.item_id)
	if result.ok:
		var revealed := session.definitions[nearest_find.definition_id] as ItemDefinition
		feedback_requested.emit("Uncovered %s · switch to stick to collect" % revealed.display_name)
		nearest_find = null
		_scan_elapsed = 1.0
		player.play_cue(&"reveal")
	else:
		feedback_requested.emit(result.message)
		player.play_cue(&"rejected", {"reason": result.message})
	return result


func _physics_process(delta: float) -> void:
	if not is_active():
		meter.hide()
		marker.hide()
		nearest_find = null
		return
	meter.show()
	_scan_elapsed += delta
	if _scan_elapsed >= 0.1:
		_scan_elapsed = 0.0
		nearest_find = finds.nearest(player.global_position, definition.range)
	if nearest_find == null:
		distance_label.text = "NO SIGNAL · move along the shore"
		strength_bar.value = 0
		marker.hide()
		player.hand_rig.set_tool_activity(&"detector", 0.3)
		return
	var distance := player.global_position.distance_to(nearest_find.dig_surface_position)
	var strength := clampf(1.0 - distance / definition.range, 0.0, 1.0)
	distance_label.text = "BURIED SIGNAL  %.1f m  ·  %s" % [distance, "%s: uncover" % player.interactor.binding_text(&"primary") if distance <= BuriedFind.DIG_REACH else "move closer"]
	strength_bar.value = strength * 100.0
	marker.global_position = nearest_find.dig_surface_position + Vector3.UP * 0.045
	marker.visible = true
	# The ping rings carry the rhythm now; the surface marker holds still.
	marker.scale = Vector3.ONE
	player.hand_rig.set_tool_activity(&"detector", 0.3 + 0.7 * strength)
	_ping_elapsed += delta
	if _ping_elapsed >= lerpf(FEEL.detector_ping_far_seconds, FEEL.detector_ping_near_seconds, strength):
		_ping_elapsed = 0.0
		_ping(strength)


## One ping: a ring spreads from the signal, the coil flashes and the meter brightens. Rings are
## positional feedback and stay under reduced motion; the tool flash does not.
func _ping(strength: float) -> void:
	FeelRing.spawn(self, marker.global_position + Vector3.UP * 0.01, 0.2, FEEL.detector_ring_radius, 0.5, FEEL.detector_color, 0.05)
	player.hand_rig.flash_tool(FEEL.detector_color, 0.12)
	strength_bar.modulate = Color(1.35, 1.25, 1.0)
	FeelMotion.replace(strength_bar, &"ping", FeelMotion.tween(strength_bar)).tween_property(strength_bar, "modulate", Color.WHITE, 0.15)
	player.play_cue(&"detector_ping", {"strength": strength})
