# J01 — Hover highlight that reads and invites

Dependencies: J00. Read first: [plan](../12-game-feel.md) §4 rules 6, 10 and 12, §5.4, §8 and §11.2 (`validate_interaction.gd` contract). Also [P08](P08-interaction.md).

**Outcome:**

- Hovering an actionable object gives it a crisp, crack-free white outline of constant screen width, a dark backing that reads on bright sand, a soft rim glow and a small lift (a hop for litter).
- A target the current input cannot act on ("Bag full", "Needs Knife", "Hands full", an uncleanable stain) gets a dashed amber outline with no glow or lift.
- Slotted props, disposal bags, stains and stations are highlighted too. Stations get a soft rim only.
- Glass gets a rim instead of a hull, so no white silhouette shows through it.

**Own files:**

| File | Change |
|---|---|
| `shaders/hover_outline.gdshader` | Rewrite |
| `shaders/hover_rim.gdshader` | New |
| `scripts/feel/hover_highlight.gd` | New |
| `scripts/items/world_item.gd` | Hover and outline section only |
| `scripts/player/interactor.gd` | `_set_target` and a new helper |
| `scripts/items/placement_service.gd` | Two small helpers and the sweep mesh filter |
| `scripts/items/dirt_visual.gd` | `set_highlighted` |
| `scripts/stations/sorting_station.gd`, `waste_container.gd`, `collection_call_point.gd`, `equipment_shop.gd` | One `set_meta` line each |

## Steps

### 1. Rewrite the outline shader

The overlay mesh carries welded normals (step 3), so the hull no longer splits at hard edges. The width is converted from pixels to view-space metres per vertex, so the outline looks the same at 0.8 m and 2.5 m.

```glsl
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, skip_vertex_transform, shadows_disabled, fog_disabled;

// Inverted-hull hover outline with constant screen width. HoverHighlight supplies a
// copy of the mesh with welded normals so low-poly hard edges do not crack.
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float width_px = 2.5;
uniform float max_world_width = 0.03;
uniform float dash_px = 0.0; // > 0: diagonal screen-space dashes (blocked style)

void vertex() {
	vec4 view_position = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 view_normal = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	float view_distance = max(-view_position.z, 0.05);
	float metres_per_pixel = 2.0 * view_distance / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	view_position.xyz += view_normal * min(width_px * metres_per_pixel, max_world_width);
	VERTEX = view_position.xyz;
	NORMAL = view_normal;
}

void fragment() {
	if (dash_px > 0.0 && mod(floor((FRAGCOORD.x + FRAGCOORD.y) / dash_px), 2.0) < 1.0) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
```

If the Compatibility compiler rejects `VIEWPORT_SIZE` in `vertex()`, add `uniform vec2 viewport_px = vec2(1280.0, 720.0);` and have `HoverHighlight` set it from `get_viewport().get_visible_rect().size` when a hover starts. Record which variant you shipped.

### 2. Add the rim shader

`shaders/hover_rim.gdshader`:

```glsl
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// Soft additive rim for hovered objects; the only highlight on see-through (glass) meshes.
uniform vec4 rim_color : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float rim_strength = 0.3;
uniform float fill_strength = 0.04;
uniform float rim_power = 2.5;
uniform float breath_amount = 0.2;
uniform float breath_hz = 1.4;
uniform float push = 0.002;

void vertex() {
	VERTEX += NORMAL * push;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, rim_power);
	float pulse = 1.0 + breath_amount * sin(TIME * 6.2831853 * breath_hz);
	ALBEDO = rim_color.rgb * (rim * rim_strength + fill_strength) * pulse;
}
```

### 3. Create `HoverHighlight`

`scripts/feel/hover_highlight.gd`:

```gdscript
class_name HoverHighlight
extends RefCounted
## Lazily built hover overlays under one visual root. Only the hovered object shows them.
## Materials are shared per style: only one target is hovered at a time (plan §4 rule 6).

enum Style { ACTION, BLOCKED, SOFT }

const FEEL := preload("res://data/feel/feel_tuning.tres")
const OUTLINE_SHADER := preload("res://shaders/hover_outline.gdshader")
const RIM_SHADER := preload("res://shaders/hover_rim.gdshader")
const OVERLAYS := &"hover_overlays"
## Existing marker: sweeps, mesh collectors and outline builders must skip these meshes.
const MARK := &"hover_outline"

static var _chains: Dictionary = {}
static var _outline_meshes: Dictionary = {}
static var _width_tween: Tween


static func set_active(root: Node3D, active: bool, style: Style = Style.ACTION, reduced_motion := false, see_through := false) -> void:
	if root == null or not is_instance_valid(root):
		return
	var overlays := _overlays(root, active)
	for overlay_value in overlays:
		var overlay := overlay_value as MeshInstance3D
		overlay.visible = active
		if active:
			overlay.material_override = _material(style, see_through or bool(overlay.get_meta(&"see_through", false)))
	if active:
		_animate_width(style, reduced_motion)
		for chain_value in _chains.values():
			_set_breath(chain_value as Material, reduced_motion)


static func overlay_count(root: Node3D) -> int:
	return (root.get_meta(OVERLAYS, []) as Array).size() if root != null and is_instance_valid(root) else 0


## Copy of `source` with normals averaged across coincident vertices (welded), for the hull.
static func outline_mesh(source: Mesh) -> Mesh:
	if source == null:
		return null
	if _outline_meshes.has(source):
		return _outline_meshes[source]
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		if source is ArrayMesh and (source as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := source.surface_get_arrays(surface)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		if vertices.is_empty() or normals.size() != vertices.size():
			continue
		var summed := {}
		for index in vertices.size():
			var key := (vertices[index] * 10000.0).round()
			summed[key] = (summed.get(key, Vector3.ZERO) as Vector3) + normals[index]
		var welded := PackedVector3Array()
		welded.resize(vertices.size())
		for index in vertices.size():
			var total := summed[(vertices[index] * 10000.0).round()] as Vector3
			welded[index] = total.normalized() if total.length_squared() > 0.000001 else normals[index]
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = vertices
		out[Mesh.ARRAY_NORMAL] = welded
		out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var chosen: Mesh = result if result.get_surface_count() > 0 else source
	_outline_meshes[source] = chosen
	return chosen


static func _overlays(root: Node3D, build: bool) -> Array:
	if root.has_meta(OVERLAYS):
		var cached := (root.get_meta(OVERLAYS) as Array).filter(func(o: Variant) -> bool: return is_instance_valid(o))
		root.set_meta(OVERLAYS, cached)
		return cached
	if not build:
		return []
	var sources: Array[MeshInstance3D] = []
	_collect(root, sources)
	var overlays := []
	for source in sources:
		var overlay := MeshInstance3D.new()
		overlay.set_meta(MARK, true)
		overlay.mesh = outline_mesh(source.mesh)
		overlay.skin = source.skin
		overlay.skeleton = source.skeleton
		overlay.transform = source.transform
		overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		overlay.extra_cull_margin = 0.05
		overlay.visibility_range_end = source.visibility_range_end
		overlay.set_meta(&"see_through", _is_transparent(source))
		overlay.visible = false
		source.get_parent().add_child(overlay)
		overlays.append(overlay)
	root.set_meta(OVERLAYS, overlays)
	return overlays


static func _collect(node: Node, result: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh != null and not child.has_meta(MARK):
			result.append(child as MeshInstance3D)
		_collect(child, result)


static func _is_transparent(source: MeshInstance3D) -> bool:
	for surface in source.get_surface_override_material_count():
		var material := source.get_active_material(surface)
		if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false


static func _material(style: Style, see_through: bool) -> Material:
	var key := "%d:%s" % [style, see_through]
	if _chains.has(key):
		return _chains[key]
	var rim := ShaderMaterial.new()
	rim.shader = RIM_SHADER
	var strength := FEEL.hover_rim_strength
	if style == Style.SOFT:
		strength = FEEL.hover_soft_rim_strength
	elif see_through:
		strength = FEEL.hover_see_through_rim_strength
	rim.set_shader_parameter("rim_strength", strength)
	var color := FEEL.hover_blocked_color if style == Style.BLOCKED else FEEL.hover_action_color
	rim.set_shader_parameter("rim_color", color)
	rim.set_shader_parameter("breath_hz", FEEL.hover_rim_hz)
	var head: Material = rim
	if style != Style.SOFT and not see_through:
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE_SHADER
		outline.set_shader_parameter("outline_color", color)
		outline.set_shader_parameter("width_px", FEEL.hover_outline_px)
		outline.set_shader_parameter("max_world_width", FEEL.hover_max_world_width)
		outline.set_shader_parameter("dash_px", FEEL.hover_blocked_dash_px if style == Style.BLOCKED else 0.0)
		var backing := ShaderMaterial.new()
		backing.shader = OUTLINE_SHADER
		backing.set_shader_parameter("outline_color", FEEL.hover_backing_color)
		backing.set_shader_parameter("width_px", FEEL.hover_outline_px + FEEL.hover_backing_px)
		backing.set_shader_parameter("max_world_width", FEEL.hover_max_world_width * 1.6)
		outline.next_pass = backing
		if style == Style.BLOCKED:
			head = outline
		else:
			rim.next_pass = outline
	_chains[key] = head
	return head
```

Finish it with two small functions:

- `_animate_width(style, reduced)`:
  1. Find the white `outline` material in each ACTION and BLOCKED chain. It is `head.next_pass` for ACTION and `head` for BLOCKED.
  2. Kill `_width_tween`.
  3. When reduced, set `width_px` straight to `FEEL.hover_outline_px` and the backing to rest plus backing.
  4. Otherwise create `(Engine.get_main_loop() as SceneTree).create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` and run `tween_method` 0 → `hover_outline_peak_px` (40% of `hover_in_seconds`, `TRANS_QUAD`/`EASE_OUT`), then → `hover_outline_px` (60%, `TRANS_BACK`/`EASE_OUT`). Write both outline and backing (+ `hover_backing_px`) each step.
- `_set_breath(material, reduced)`: walk the chain and set the rim's `breath_amount` to `0.0` when reduced, otherwise `FEEL.hover_rim_breath`.

Overlays stay children of the source mesh's parent, so they move with lifts and squashes, and they are freed with the object.

### 4. Use it in `WorldItem`

Replace the hover section of `scripts/items/world_item.gd`:

- Delete `HOVER_SHADER`, `_outline_material`, `_outline_overlays`, `_build_outline_overlays()` and `_collect_visible_meshes()`.
- Add `var _highlight_style := -1` and `var effects: ItemViewManager`. J04 uses `effects`; `ItemViewManager._spawn_view` sets it.
- Replace `set_highlighted`, `outline_overlay_count` and `pulse` with the following. `pulse` is unused and is replaced by J05.

```gdscript
func set_highlighted(value: bool, style: int = HoverHighlight.Style.ACTION, reduced_motion := false) -> void:
	if _highlighted == value and (not value or _highlight_style == style):
		return
	_highlighted = value
	_highlight_style = style if value else -1
	var see_through := definition != null and definition.material_tags.has(&"glass")
	HoverHighlight.set_active(visual_root, value, style, reduced_motion, see_through)
	_animate_hover(value and style == HoverHighlight.Style.ACTION and not reduced_motion)


func outline_overlay_count() -> int:
	return HoverHighlight.overlay_count(visual_root)


func _animate_hover(active: bool) -> void:
	var t := FeelMotion.replace(visual_root, &"hover", FeelMotion.tween(self))
	if not active:
		t.tween_property(visual_root, "scale", Vector3.ONE, FEEL.hover_out_seconds)
		t.parallel().tween_property(visual_root, "position", Vector3.ZERO, FEEL.hover_out_seconds)
		t.parallel().tween_property(visual_root, "rotation", Vector3.ZERO, FEEL.hover_out_seconds)
		return
	var large := definition != null and definition.collision_profile == ItemDefinition.CollisionProfile.LARGE
	var lift := FEEL.hover_lift_large if large else FEEL.hover_lift_small
	t.tween_property(visual_root, "scale", Vector3.ONE * lift, FEEL.hover_in_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not large:
		var wiggle := deg_to_rad(FEEL.hover_wiggle_degrees) * (1.0 if FeelMotion.cosmetic_random(item_id) > 0.5 else -1.0)
		t.parallel().tween_property(visual_root, "position:y", FEEL.hover_hop_height, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(visual_root, "rotation:z", wiggle, 0.06)
		t.chain().tween_property(visual_root, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(visual_root, "rotation:z", -wiggle * 0.5, 0.06)
		t.chain().tween_property(visual_root, "rotation:z", 0.0, 0.08)
```

Add `const FEEL := preload("res://data/feel/feel_tuning.tres")` at the top of the script. `is_highlighted()` stays as it is.

`travel_to()` already calls `set_highlighted(false)`. J04 also kills the `hover` channel and resets `visual_root.transform` before travelling. Until then, add `FeelMotion.replace(visual_root, &"hover", null)` and `visual_root.transform = Transform3D.IDENTITY` at the top of `travel_to()`.

### 5. Decide the style in `PlayerInteractor`

In `scripts/player/interactor.gd`:

1. Add `var _highlight_root: Node3D` and `var _highlight_kind := ""`. Keep `_highlighted_view` and `_highlighted_dirt`.
2. Add a public `style_for(result: Dictionary) -> int`. J02's reticle and label reuse it, so the three cues always agree:
   - An empty result returns -1 (no highlight).
   - `kind == "slot"` returns -1. The ghost is the cue; invalid slots have no outline.
   - `kind == "dirt_patch"` returns ACTION if `actions.has("clean")`, otherwise BLOCKED.
   - `kind == "station"`:
     - `actions.has("cut")` and the active tool is not `&"knife"`: BLOCKED.
     - `actions.has("cut")`: ACTION.
     - Otherwise SOFT.
   - Otherwise ACTION if `actions` contains any of `collect`, `hold`, `hold_bag`, `place`, `clean`, `carry_dirty`, `interact`. Otherwise BLOCKED.
3. Add `_highlight_root_for(result) -> Node3D`:
   - `WorldItem` and `DirtVisual` return null; they keep their own `set_highlighted`, which carries the lift.
   - A slotted target (`kind == "item"` and `result.has("slot_id")`) returns `session.placement_service.slotted_visual_root(StringName(str(result.id)))`.
   - `DisposalBag` returns the bag node itself.
   - A station (`kind == "station"`) returns `collider.get_meta(&"highlight_root")` if it is a valid `Node3D`. Otherwise it returns the collider when it is a `Node3D`, and null for an `Area3D` with no visual.
4. In `_set_target`:
   - Pass the style and reduced flag to `_highlighted_view.set_highlighted(true, style, reduced)` and `_highlighted_dirt.set_highlighted(true, style == HoverHighlight.Style.ACTION)`.
   - When the generic root changes, call `HoverHighlight.set_active(old_root, false)` on the previous one and `HoverHighlight.set_active(new_root, true, style, reduced)` on the new one.
   - Also re-apply when the same target changes style, for example when the bag becomes full while aiming. `current_target.reason` change already triggers `target_changed`, so compare styles there.
   - Get `reduced` from `(get_parent() as BeachPlayer).settings_store` through `FeelMotion.reduced`.
5. In the `station` branch of `_result_for_collider`, if `actions.has("cut")` and the active tool is not the knife, set `"reason": "Needs Rescue knife"`. This is display text only; `actions` and the routing in `player.gd` stay unchanged. The target label then shows the reason instead of "Cut with rescue knife".

### 6. Small owner hooks

- `PlacementService`:
  - Add `func slotted_visual_root(item_id: StringName) -> Node3D`. It returns `(slotted_views[item_id] as Node3D).get_node_or_null("VisualRoot")`, or null.
  - In `_collect_sweep_meshes`, skip meshes where `child.has_meta(HoverHighlight.MARK)`.
  - In `_remove_slotted_view`, if that root is currently highlighted, nothing else is needed: the overlays are freed with the body.
- `DirtVisual.set_highlighted(value, actionable := true)`:
  - Keep the 1.12 scale, but tween it over `hover_in_seconds` with `TRANS_BACK`.
  - Call `HoverHighlight.set_active(self, value, ACTION if actionable else BLOCKED)`.
  - Stains are thin boxes. If the hull looks wrong on them, set a SOFT rim instead and record the choice.
- Stations: set a `highlight_root` so the soft rim follows the visible model:

| Script | Where | Line to add |
|---|---|---|
| `SortingStation` | `configure` | `tabletop.set_meta(&"highlight_root", get_node("SyntyTable"))` |
| `WasteContainer` | `configure` | `set_meta(&"highlight_root", get_node("SyntyContainer"))`, and the same meta on `opening` |
| `CollectionCallPoint` | `configure` | `set_meta(&"highlight_root", get_node("SyntyPhone"))` |
| `EquipmentShop` | `configure` | `counter.set_meta(&"highlight_root", counter.get_node("SyntyCounter"))` and `rack.set_meta(&"highlight_root", rack.get_node("SyntyRack"))` |

### 7. Streaming safety

`ItemViewManager._refresh_stream` already avoids unloading a highlighted view, and `is_highlighted()` stays true for BLOCKED. Overlays of an unloaded view are freed with it. Nothing else changes.

## Tuning notes

- Start with the J00 defaults, then inspect:
  - small glass on bright sand
  - a can in hut shadow
  - a chair
  - the thin net
  - a stain
  - a slotted bucket
  - a disposal bag on the rack
  - the sorting table
- Inspect each at 0.8 m, 1.5 m and 2.5 m, at FOV 70 and 110.
- Keep the outline between 2 and 3 px at 1080p. Keep the rim subtle: it must not wash out category colour.
- If the welded hull still shows gaps on a specific wrapper (open meshes such as the net), set that item's style to rim-only through the same `see_through` path and record the item.

## Reduced motion

- The outline appears at rest width.
- No lift, hop, wiggle or breathing.
- The blocked dashes remain, because they carry meaning.

## Validation

1. Run `tests/validate_interaction.gd -- --capture` and keep `P08-interaction-lab.png` as the J01 still. The existing checks must pass unchanged:
   - `is_highlighted`
   - `outline_overlay_count() > 0`
   - the net still counts as highlighted, now in BLOCKED style
   - previous target cleaned
   - freed target clears its outline
2. In `scenes/main.tscn` with seed `first-shore`, use a probe or play by hand:
   - hover the listed objects
   - fill the bag to 20 and re-hover a can (BLOCKED)
   - hover a slotted prop in the arrival hut
   - aim at the table, phone, containers, shop counter and rack (SOFT)
   - hover underwater litter while submerged

   Record stills at 1080p for: action, blocked, glass, slotted, station and underwater.
3. Watch the log for shader errors on first hover.
4. Confirm that a hover never shows through a wall: stand behind the hut wall aimed at a can inside.
5. Re-run the checks: `validate_interaction.gd`, `validate_dirt.gd`, `validate_placement.gd` (the sweep mesh filter) and `validate_carry.gd`.

Optional small check (keep it only if it catches a real regression): in `validate_interaction.gd`, assert that the full-bag glass is highlighted and its overlay `material_override` differs from the one used for a collectable can. This protects the "blocked never looks actionable" invariant.

## Done when

- Actionable, blocked, soft and see-through styles are visibly distinct in the listed places.
- The outline is continuous on Synty hard edges and the same width near and far.
- No through-wall hover.
- The listed checks pass.
- Reduced motion is observed.
- Stills are in J-feel.
