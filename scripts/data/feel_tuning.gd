class_name FeelTuning
extends Resource
## Presentation-only tuning for hover, hands, placement, tools and completion.
## Nothing here may change ownership, payment, completion, saves, reach or timing of commits.

@export_group("Hover")
@export var hover_outline_px := 2.5
@export var hover_outline_peak_px := 3.5
@export var hover_backing_px := 1.5
@export var hover_max_world_width := 0.03
@export var hover_in_seconds := 0.12
@export var hover_out_seconds := 0.06
@export var hover_action_color := Color("ffffff")
@export var hover_backing_color := Color("0b1a1f")
@export var hover_blocked_color := Color("e8b45a")
@export var hover_blocked_dash_px := 5.0
@export var hover_rim_strength := 0.3
@export var hover_rim_breath := 0.2
@export var hover_rim_hz := 1.4
@export var hover_soft_rim_strength := 0.16
@export var hover_see_through_rim_strength := 0.6
@export var hover_lift_small := 1.06
@export var hover_lift_large := 1.02
@export var hover_hop_height := 0.015
@export var hover_wiggle_degrees := 4.0

@export_group("Reticle and label")
@export var reticle_dot_px := 2.5
@export var reticle_ring_px := 9.0
@export var reticle_ring_width_px := 2.0
@export var reticle_place_px := 10.0
@export var reticle_spring_hz := 7.0
@export var reticle_pop_px := 5.0
@export var reticle_shake_px := 4.0
@export var reticle_shake_seconds := 0.2
@export var reticle_idle_alpha := 0.7
@export var label_in_seconds := 0.1
@export var label_rise_px := 6.0
@export var label_follow_hz := 18.0
@export var label_shake_px := 5.0

@export_group("Viewmodel")
@export var bob_hz := 1.8
@export var bob_sprint_scale := 1.35
@export var bob_crouch_scale := 0.75
@export var bob_amplitude := 0.012
@export var bob_carry_large_scale := 1.4
@export var idle_breath_amplitude := 0.004
@export var idle_breath_hz := 0.25
@export var sway_gain := 0.012
@export var sway_max_degrees := 4.0
@export var sway_spring_hz := 4.5
@export var land_kick := 0.05
@export var land_spring_hz := 5.0
@export var swim_float_amplitude := 0.012
@export var swim_float_hz := 0.5
@export var reduced_clip_strength := 0.5
## The equip raise duration lives in ViewmodelAnimator.CLIPS[&"equip_raise"].
@export var equip_drop_seconds := 0.14
@export var bag_fill_scale_empty := 0.88
@export var bag_fill_scale_full := 1.12
@export var bag_squash_kick := Vector3(0.10, -0.12, 0.10)
@export var bag_spring_hz := 4.0
@export var held_selected_lift := Vector3(0.0, 0.035, -0.03)
@export var vacuum_jitter := 0.0015
@export var vacuum_jitter_hz := 22.0
@export var detector_sweep_degrees := 8.0
@export var detector_sweep_hz := 0.6
## Tool tip positions in ToolSocket space after the grip transform; tune in J03/J06 and after art swaps.
@export var tool_tips: Dictionary[StringName, Vector3] = {
	&"stick": Vector3(0.0, -0.32, -0.34),
	&"cloth": Vector3(0.0, -0.02, -0.06),
	&"knife": Vector3(0.0, 0.02, -0.12),
	&"detector": Vector3(0.0, -0.20, -0.62),
	&"sand_cleaner": Vector3(0.0, -0.10, -0.20),
	&"vacuum": Vector3(0.0, -0.02, -0.46),
}

@export_group("Pickup and throw")
@export var yoink_seconds := 0.06
@export var yoink_height := 0.06
@export var yoink_scale := 1.15
@export var bag_travel_base := 0.2
@export var bag_travel_per_meter := 0.04
@export var bag_travel_max := 0.3
@export var bag_arc_height := 0.25
@export var bag_mouth := Vector3(0.0, 0.12, 0.0)
@export var bag_shrink_from := 0.55
@export var bag_end_scale := 0.12
@export var bag_spin_turns := 0.6
@export var stick_tip_fraction := 0.3
@export var vacuum_travel_seconds := 0.2
@export var vacuum_stretch := Vector3(0.7, 0.7, 1.5)
@export var sand_cleaner_stagger := 0.035
@export var prop_yoink_seconds := 0.07
@export var prop_yoink_height := 0.1
@export var prop_wiggle_degrees := 3.0
@export var prop_travel_seconds := 0.26
@export var prop_arc_height := 0.12
@export var pickup_sparkles := 4
@export var pickup_dust := 6
@export var dust_color := Color("e8dcc2")
@export var sand_color := Color("d8c39a")
@export var throw_spin := 6.0
@export var impact_min_speed := 2.0
@export var impact_squash := Vector3(1.12, 0.85, 1.12)
@export var impact_seconds := 0.14

@export_group("Placement")
@export var ghost_color := Color("7ff5c8")
@export var ghost_fill_alpha := 0.16
@export var ghost_rim_alpha := 0.85
@export var ghost_scan_density := 14.0
@export var ghost_breath := 0.12
@export var ghost_appear_seconds := 0.1
@export var ghost_glide_seconds := 0.08
@export var ghost_blob_alpha := 0.28
@export var place_travel_base := 0.2
@export var place_travel_per_meter := 0.04
@export var place_travel_max := 0.3
@export var place_arc_height := 0.18
@export var place_drop_height := 0.06
@export var capture_travel_seconds := 0.18
@export var land_squash := Vector3(1.06, 0.92, 1.06)
@export var land_rebound := Vector3(0.98, 1.06, 0.98)
@export var land_seconds := 0.22
@export var land_sparkles := 6
@export var neighbor_wobble_degrees := 2.0
@export var neighbor_wobble_radius := 1.2
@export var remove_lift := 0.06

@export_group("Tools")
@export var detector_ping_far_seconds := 1.1
@export var detector_ping_near_seconds := 0.22
@export var detector_ring_radius := 0.9
@export var detector_color := Color("ffc24d")
@export var sand_ring_color := Color("7ff5c8")
@export var sand_ring_dashes := 24.0
@export var vacuum_mote_rate := 24.0
@export var vacuum_mote_speed := 3.5
@export var scanner_ring_radius := 30.0
@export var scanner_ring_seconds := 0.9
@export var scanner_color := Color("8ff3e0")
@export var freed_label_seconds := 1.6
@export var reveal_pop_height := 0.06

@export_group("Completion")
## validate_placement.gd waits 0.9 s for the overlay to clear; keep this at or below 0.8.
@export var group_sweep_seconds := 0.8
@export var shine_angle_degrees := 20.0
@export var shine_band_width := 0.22
@export var shine_core_color := Color("fff8e6")
@export var shine_fringe_color := Color("8ff3e0")
@export var shine_intensity := 1.0
@export var clean_gleam_seconds := 0.6
@export var clean_sparkles := 8
@export var set_sparkles_per_item := 3
@export var floater_rise := 0.35
@export var floater_seconds := 1.1
@export var sparkle_colors: Array[Color] = [Color("fff6d8"), Color("ffd86a"), Color("a6f5ee")]

@export_group("Sorting table")
@export var unload_drop_height := 0.45
@export var unload_fall_seconds := 0.22
@export var unload_cascade_max := 0.9
@export var unload_stagger := 0.012
@export var sort_travel_seconds := 0.22
@export var proxy_hover_lift := 0.03
@export var proxy_hover_scale := 1.12
@export var drag_height := 0.12
@export var drag_tilt_degrees := 15.0
@export var cursor_follow_hz := 30.0
@export var bin_bump := Vector3(1.04, 0.92, 1.04)
@export var rack_drop_height := 0.5
@export var stamp_seconds := 0.8

@export_group("HUD")
@export var count_min_seconds := 0.25
@export var count_max_seconds := 0.8
@export var bump_scale := 1.12
@export var bump_seconds := 0.16
@export var bar_shine_seconds := 0.6
@export var notice_in_seconds := 0.18
@export var notice_out_seconds := 0.12
@export var notice_rise_px := 10.0
@export var bag_warn_ratio := 0.8
@export var bag_color_normal := Color("9fe6d6")
@export var bag_color_warn := Color("e8b45a")
@export var bag_color_full := Color("e2725b")
@export var money_color := Color("ffd85a")
@export var money_float_seconds := 0.9

@export_group("Collection and money")
@export var coin_min := 3
@export var coin_max := 10
@export var coin_value := 10
@export var coin_seconds := 0.55
@export var coin_stagger := 0.05
@export var receipt_slide_px := 48.0
@export var receipt_in_seconds := 0.22
@export var receipt_type_seconds := 0.45
@export var receipt_count_seconds := 0.6
@export var phone_ring_degrees := 8.0
@export var phone_ring_seconds := 0.45
@export var container_lift_seconds := 0.35

@export_group("Restoration")
@export var wave_seconds := 1.8
@export var wave_radius_section := 12.0
@export var wave_radius_zone := 22.0
@export var wave_height := 1.2
@export var wave_color_shore := Color("fff1c9")
@export var wave_color_reef := Color("7ff0e0")
@export var wave_sparkle_interval := 0.08
@export var wave_sparkles_per_step := 6
@export var bloom_pop_seconds := 0.45
@export var pointer_seconds := 4.0
@export var pointer_far_distance := 25.0
@export var beacon_seconds := 3.5
@export var beacon_height := 12.0
@export var max_concurrent_waves := 4
@export var banner_batch_threshold := 3

@export_group("Finale")
@export var finale_capture_seconds := 1.1
@export var finale_flash_alpha := 0.55
@export var finale_count_seconds := 0.6
@export var confetti_amount := 80
@export var confetti_colors: Array[Color] = [Color("f2d49b"), Color("5fd6c8"), Color("ff8f8a"), Color("ffffff")]
@export var postcard_size := Vector2(384, 216)

@export_group("Rumble")
## weak, strong, seconds. Only used when the vibration setting is on and the last input was a controller.
@export var rumble: Dictionary[StringName, Vector3] = {
	&"poke": Vector3(0.10, 0.0, 0.04),
	&"bag_catch": Vector3(0.08, 0.0, 0.03),
	&"rejected": Vector3(0.0, 0.30, 0.06),
	&"hold": Vector3(0.15, 0.05, 0.06),
	&"hold_bag": Vector3(0.15, 0.05, 0.06),
	&"throw": Vector3(0.12, 0.0, 0.05),
	&"place": Vector3(0.20, 0.12, 0.08),
	&"deposit": Vector3(0.18, 0.10, 0.08),
	&"clean": Vector3(0.10, 0.0, 0.05),
	&"clean_done": Vector3(0.25, 0.10, 0.12),
	&"cut": Vector3(0.20, 0.15, 0.06),
	&"animal_freed": Vector3(0.30, 0.10, 0.25),
	&"reveal": Vector3(0.25, 0.20, 0.12),
	&"sift": Vector3(0.20, 0.15, 0.10),
	&"vacuum_tick": Vector3(0.05, 0.0, 0.02),
	&"vacuum_full": Vector3(0.0, 0.35, 0.12),
	&"equip": Vector3(0.08, 0.05, 0.05),
	&"scanner_pulse": Vector3(0.10, 0.0, 0.08),
	&"collect_call": Vector3(0.20, 0.10, 0.15),
	&"set_complete": Vector3(0.30, 0.10, 0.18),
	&"section_restored": Vector3(0.35, 0.20, 0.30),
	&"zone_restored": Vector3(0.40, 0.25, 0.45),
	&"run_complete": Vector3(0.30, 0.10, 0.60),
}
