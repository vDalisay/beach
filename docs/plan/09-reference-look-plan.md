# Reference look — Godot implementation specification

**Included in [the finishing phase](11-finishing-phase.md):** V00–V03 are FIN-06, V04–V06 are FIN-07, and V07 visual/presentation acceptance is FIN-08, with final target-device certification in FIN-10. Use that master checklist for progress; this document remains the technical source for the rendering work. Its revised shader/resource instructions and starting values supersede older C06 colour suggestions. Completed V evidence is linked once, not repeated as a second completion phase.

Revised 24 September 2026. This replaces the earlier descriptive plan with a concrete build specification for Godot 4.6.1 Compatibility. The values below are **first implementation values**, chosen for this scene; they have not yet been rendered or accepted. Code blocks describe the code to write and are not complete compiled shaders.

The target is the first reference's golden sand, shaped warm sunlight, pastel shade and broken turquoise surf, with the second reference's distant haze and layered bay. Implement the lighting and shader work below as C06, with the existing C04 composition and C05 clutter work feeding final acceptance. Use the approximately 160 m beach and current gameplay state. Inspect the latest [C04 along-shore](../handoffs/images/C04-v64/along-shore-restored.png) and [C04 aerial](../handoffs/images/C04-v64/aerial-restored.png), rather than treating the older reference captures as the current build.

## 1. Concrete findings that determine the work

| Existing code | Consequence | Required edit |
|---|---|---|
| `Environment_beach.ambient_light_source = 3`, sky contribution defaults to 1 | The saturated sky supplies the fill; changing the stored ambient color cannot provide the intended neutral pastel shade | Select Color ambient explicitly, set sky contribution to 0, retain sky separately for reflections |
| `art/synty/shaders/polygon.gdshader` unconditionally writes `NORMAL = normalize(NORMAL + vec3(0, ..., 0))` | With both normal features disabled it still subtracts 1 from the view-space normal's Y component; lighting can change incorrectly with the camera | Supply a corrected project shader and point staged materials at it |
| `beach_water.gdshader` uses `specular_disabled` | Smoothness cannot produce the sun glints needed by the references | Enable GGX specular and supply valid normals |
| Water assigns sampled RGB directly to `NORMAL`; its normal texture has `source_color` | A normal data texture is treated as color and its values are used in the wrong coordinate space | Decode linear RG data and transform a world normal into view space |
| Water colors use opaque scene depth minus water eye depth | Looking at the same shallow patch from a different angle changes its depth color; foreground objects can alter the apparent water palette | Use authored bed depth for the base palette and camera-ray thickness only for opacity/contact foam |
| Water has only two vertex rows from shore to Z=800 | Long narrow triangles constrain shoreline attributes and atmospheric interpolation | Add a small set of cross-shore rows, retaining a single surface |
| `seabed_caustics.tres` is declared in `beach.tscn` but not assigned to a mesh | Tuning the current caustics shader does not affect the rendered sand | Add a shared caustics function to the actual sand and reef materials |
| The paired capture creates a fresh SubViewport with no MSAA assignment | Project viewport AA changes will not necessarily appear in the reference captures | Copy the gameplay viewport's AA settings into that existing capture viewport |

These are code observations. Their contribution to the final image must be confirmed with the matching captures.

## 2. Files to create or change

All new paths here are proposed implementation deliverables.

| File | Work to implement |
|---|---|
| `shaders/beach_polygon.gdshader` | Project variant of supplied polygon shader; correct normal handling while preserving its atlas/material interface and license notice |
| `shaders/beach_foliage.gdshader` | Project variant retaining supplied wind/leaf masks; correct world-normal transform and normal-map strength |
| `tools/stage_assets.gd` | Rewrite the two known shader resource declarations to project variants; stage one explicit additional caustic texture |
| `data/asset_manifest.json` | Record the extra `caustic_height.png` dependency; keep staging reproducible |
| `scenes/world/beach_environment.tres`, `scenes/world/beach_sky.tres` | Extract the existing environment/sky and set the numeric lighting/post values below |
| `scenes/world/beach.tscn` | Assign those resources, edit Sun, assign the new sand material |
| `shaders/beach_sand.gdshader`, `shaders/beach_sand.tres` | World-space sand texture, macro variation, wet strip, below-water caustics |
| `scripts/world/coastline.gd` | Expose current shore slope and bed-height profile for both visible meshes; do not change the profile during this extraction |
| `scripts/world/shore_dressing.gd` | Add shoreline attributes and real slope normals; accept ShaderMaterial instead of casting to StandardMaterial3D |
| `shaders/beach_water.gdshader`, `shaders/beach_water.tres` | Replace current depth/normal/foam calculations with section 5 |
| `scripts/world/water_surface.gd` | Add cross-shore rows and bake shoreline/bed data into vertex attributes |
| `shaders/beach_clouds.gdshader`, `shaders/beach_clouds.tres` | Author controlled cream tops and blue-grey undersides using face normals |
| `scripts/world/city_backdrop.gd` | Apply cloud material; remove unshaded finishes from visible land/paving so they receive scene light |
| `shaders/beach_caustics.gdshaderinc` | Shared two-sample caustic function |
| `shaders/seabed_caustics.gdshader`, `shaders/seabed_caustics.tres` | Use that include for the existing reef rock material role |
| `scripts/world/reef_dressing.gd` | Replace its local StandardMaterial3D stone material with the above shared ShaderMaterial |
| `tools/build_beach_grade.gd`, `art/look/beach_grade.res` | Generate a small 3D color LUT offline and assign it to the Environment |
| `scenes/world/underwater_environment.tres`, `scripts/player/swim.gd` | Matching surface/underwater grade and a short visual transition |
| `project.godot` | Explicit MSAA and directional-shadow settings |
| `tests/validate_full_run.gd` | Only align the existing capture viewport and log with active render settings |
| `docs/handoffs/C06.md` | Settings, matching captures, playable observations and effect cost |

Keep asset changes reproducible: copy the supplied shader variants with attribution; redirect only their known `[ext_resource]` paths during staging. Preserve the source package. Reuse the existing dependency walker and hash output; do not add a runtime material-replacement pass across thousands of objects. Both full item scenes and their distant MultiMeshes must load the same corrected material resources. Add the caustic texture to an explicit extra-resource list consumed by the existing pending dependency queue.

## 3. V01 — Repair material lighting, then establish the light rig

### 3.1 Correct the supplied material shaders

In `beach_polygon.gdshader` remove the unconditional normal offset. For ordinary atlas materials with no valid normal map, leave the incoming mesh `NORMAL` untouched. For a valid tangent-space map:

~~~glsl
// normal_texture: hint_normal, repeat_enable, filter_linear_mipmap
if (enable_normal_texture) {
    NORMAL_MAP = texture(normal_texture, uv_panned * normal_tiling + normal_offset).rgb;
    NORMAL_MAP_DEPTH = normal_intensity;
}
~~~

Do not combine a single normal channel with the view-space normal. Inspect staged materials using `enable_triplanar_normals`; turn that feature off for this low-poly look until an actual world-space triplanar normal blend is implemented. Preserve texture colors, alpha cutouts, atlas UVs, metalness and roughness. Verify normals on a chair, can, building panel and pier rail while orbiting the camera with the sun fixed.

In `beach_foliage.gdshader` replace the vertex calculation `MODEL_MATRIX * vec4(NORMAL, 0.1)` with `normalize(MODEL_NORMAL_MATRIX * NORMAL)`. Translation must not affect a normal, and the normal matrix handles scaled palms. Replace multiplication of encoded normal RGB by strength with `NORMAL_MAP_DEPTH`. Retain the leaf/trunk mask and existing back-face handling. Start with leaf roughness 0.8, trunk roughness 0.95 and emission disabled. Keep the existing wind logic, with only the gentle breeze enabled if movement is needed; maximum leaf-tip movement should remain about 5–10 cm. Check a palm from below and across the sun before changing its green tint.

### 3.2 Set a deterministic starting light rig

Use ordinary Godot light energy units; keep physical light units disabled. These color values are **sRGB Inspector colors**, not linear constants to paste into shader arithmetic. Shader color uniforms use `source_color`.

| Node/resource property | Starting value | Purpose |
|---|---|---|
| Sun `rotation_degrees` | `(-42, -43, 0)` | Diagonal shadows with readable palm/chair forms |
| Sun `light_color` | `#FFF0D2` | Warm daylight, with enough blue to keep whites cream |
| Sun `light_energy` | `1.05` | Main key; tune within 0.85–1.20 after normal fixes |
| Sun `shadow_enabled` | `true` | Ground the props and palms |
| Sun `shadow_opacity` | `0.90` | Small warm contribution in cast shade; inexpensive approximation of bounced light |
| Sun `directional_shadow_mode` | `SHADOW_PARALLEL_4_SPLITS` | Foreground detail plus coast coverage |
| Sun `directional_shadow_max_distance` | `150 m` | Reduce the current 180 m range without immediately losing the pier |
| Sun splits 1 / 2 / 3 | `0.08 / 0.22 / 0.50` | Put detail near the player |
| Sun `directional_shadow_blend_splits` | `true` | Hide cascade transitions |
| Sun `shadow_bias / shadow_normal_bias` | `0.04 / 0.8` | Initial contact settings; raise only enough to remove acne |
| Sun `shadow_blur` | `1.2` | Slight filtered softness |
| Environment `ambient_light_source` | `AMBIENT_SOURCE_COLOR` | Explicit art control of fill |
| Environment `ambient_light_sky_contribution` | `0.0` | Remove saturated sky from diffuse fill |
| Environment `ambient_light_color / energy` | `#B8BDCF / 0.42` | Low-saturation cool fill, replacing cyan shade |
| Environment `reflected_light_source` | `REFLECTION_SOURCE_SKY` | Keep a sky reflection on water and glass |
| Sky top / horizon | `#299BCB / #C5E5E6` | Blue overhead and pale horizon |
| Sky ground bottom / horizon | `#C9AC85 / #C5E5E6` | Neutral warm lower reflection; avoid a dark horizon band |
| Environment `tonemap_mode / tonemap_exposure` | `TONE_MAPPER_FILMIC / 1.0` | Stable initial response while lights/materials are tuned |
| Project `rendering/anti_aliasing/quality/msaa_3d` | `2` = 4× | Smooth silhouette edges at 1080p |
| Project `rendering/lights_and_shadows/directional_shadow/size` | `4096` | Initial shadow-map resolution |
| Project directional `soft_shadow_filter_quality` | `2` | Initial filter cost |

Use the actual Sun settings, not the old `MainLightDirection` global, for any new shader needing its direction. Direction **toward** the sun is `Sun.global_basis.z.normalized()` because emitted rays follow local -Z.

This pass uses colored ambient, filtered shadows, a small shadow-opacity adjustment and later SSAO to approximate bounce/contact. It does not require a GI bake. Static LightmapGI would require the runtime-generated shore/city meshes to be authored and UV2-unwrapped before baking; turning on a GI node cannot bake the current `_ready()` geometry. Keep that as a separately scoped upgrade only if the hut/cafe still cannot be lit convincingly. First retain the existing hut lamps, reduce any clipped table highlights, and check their shadows with the new fill.

Tune in this order: fix normals → sun direction → key energy → fill energy/color → shadow bias → material brightness. During these steps keep AO, glow, fog and color adjustments disabled. Do not brighten every material to compensate for a wrongly directed normal.

**Pass condition:** rotating the camera does not rotate the apparent shading of fixed objects; chair shade reads cool grey/purple instead of teal; palm and chair contacts are connected without thick black borders. Inspect a neutral white prop in sun and shade. Native property behavior: [Environment](https://docs.godotengine.org/en/4.6/classes/class_environment.html), [Light3D](https://docs.godotengine.org/en/4.6/classes/class_light3d.html), [directional cascades](https://docs.godotengine.org/en/4.6/classes/class_directionallight3d.html).

## 4. V02 — Write the sand shader and shared shoreline data

### 4.1 Keep one definition of the coast

Add `Coastline.shore_slope(x)` using a central difference, `(shore_z(x+0.25)-shore_z(x-0.25))/0.5`. Extract `Coastline.surface_y(x,z)` from the **existing** sand cross-section: dry sand to `shore_z-2` at Y=0.012, slope to `shore_z+28` at Y=-2.5, then `shore_z+55` at Y=-3.2 and flat beyond. Preserve those positions and collision when extracting this function.

For each sand/water vertex store `UV2 = vec2(shore_z(x), shore_slope(x))`. This gives an approximate perpendicular shore distance near the curve:

~~~glsl
float shore_distance = (world_position.z - UV2.x) / sqrt(1.0 + UV2.y * UV2.y);
// Negative: inland. Positive: water side.
~~~

Use metre-based world coordinates for texture detail. Replace the sand mesh's all-UP normals with normals computed from its actual triangles; retain deliberate hard edges on dune meshes. The water remains planar, with UP mesh normals.

### 4.2 Write `beach_sand.gdshader`

Use `render_mode diffuse_lambert, specular_schlick_ggx`. Keep geometry displacement off. Supply `sand_texture` from the existing `Sand_01.png`, `macro_noise` from `Noise_Small.png`, dry color `#E6C48B`, wet color `#AD996F` and `surface_y=0.08`.

The fragment calculation is:

~~~glsl
vec3 grain = texture(sand_texture, world_position.xz * 0.18).rgb;
float detail = dot(grain, vec3(0.2126, 0.7152, 0.0722));
float macro = texture(macro_noise, world_position.xz * 0.035).r;
float variation = 1.0 + (detail - 0.5) * 0.12 + (macro - 0.5) * 0.06;
float wet = smoothstep(-1.2, 0.35, shore_distance);
ALBEDO = mix(dry_color, wet_color, wet) * variation;
ROUGHNESS = mix(0.96, 0.65, wet);
SPECULAR = mix(0.12, 0.25, wet);
~~~

The color texture is a color input; noise/height/normal maps are data inputs and must not use `source_color`. Set mipmaps and repeat on the repeating maps. Add the caustics multiplier from section 7 only below `surface_y`. Add a gentle seabed color change over 0–3 m depth, capped at 15% towards a muted green-grey, so absorption is primarily carried by water rather than tinting the same sand twice.

In `shore_dressing.gd` remove the `as StandardMaterial3D` cast and `vertex_color_use_as_albedo` assignment. Set the new shared ShaderMaterial on the sand ArrayMesh. Existing underwater vertex tints must no longer multiply the new palette. The OuterDunes already take `sand_material`; use the same shader with a `use_shore_data=false` material variant for meshes without the baked UV2 data, keeping those decorative dry dunes dry. The sand collider continues to come from the unchanged mesh positions.

**Pass condition:** the shore has a 1–1.5 m darker wet band; close sand detail is visible without stripes; the sand texture retains the same scale in the aerial and eye-height shots. Shoreline tint follows the curve continuously.

## 5. V03 — Replace the water shader's core calculations

Use a single alpha-blended lit surface, the existing normal texture and native sky reflection. This build does not sample scene color for refraction: that avoids copying the screen and keeps transparent pickup objects easier to handle. Remove the dormant screen-color/distortion/flipbook/voronoi branches from the project water variant once no material uses them; preserve the supplied shader separately.

### 5.1 Mesh attributes

Keep the current X samples at 2.5 m intervals. Replace the two Z rows with offsets from `Coastline.shore_z(x)` of:

~~~text
0, 0.5, 1, 2, 4, 8, 16, 28, 55, 90, 150, 250, 450
plus a final row at world Z=800
~~~

At 401 columns this is 5,614 vertices and 10,400 triangles. Preserve the current upward-facing winding. Store `UV2` as above and `COLOR.r = clamp((surface_y - Coastline.surface_y(x,z))/8, 0, 1)`. This is physical seabed depth divided by 8 m; assign vertex colors as data without color-to-linear conversion. Use world XZ for texture lookup, not mesh-size-dependent UV tiling.

Start with zero vertex displacement. Two scrolling normal samples and animated surf supply the calm reference motion without changing the relationship between the visible surface and swimming.

### 5.2 Depth reconstruction: distinguish bed depth and viewing thickness

Declare the depth sampler as `hint_depth_texture, filter_nearest, repeat_disable`. Keep both renderer branches, even though Compatibility is the delivery target:

~~~glsl
vec3 reconstruct_view(vec2 uv, float raw_depth) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth * 2.0 - 1.0);
#else
    vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
#endif
    vec4 p = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    return p.xyz / p.w;
}

// Inside fragment(), VERTEX is water position in view space.
vec3 opaque_view = reconstruct_view(SCREEN_UV, texture(depth_texture, SCREEN_UV).r);
float path_length = clamp(length(opaque_view - VERTEX), 0.0, 30.0);
float contact_depth = max(0.0, -opaque_view.z + VERTEX.z);
float bed_depth = COLOR.r * 8.0;
~~~

Detect a clear/far depth sample and use `path_length=30` with no contact foam instead of reconstructing an unstable far point. Clamp divisions and thickness. The palette uses `bed_depth`; the transparency uses `path_length`. The existing seabed is only about 3.2 m deep, so offshore color is an explicit artistic distance transition, not a false claim of deeper collision geometry. Depth reconstruction follows [Godot's depth-texture guidance](https://docs.godotengine.org/en/4.6/tutorials/shaders/advanced_postprocessing.html).

### 5.3 Normals and specular

Use `render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_lambert, specular_schlick_ggx`. `depth_draw_opaque` does not make alpha water an opaque depth occluder. Do not add an alpha depth prepass for this surface.

Sample `WaterNormals_01.png` as `hint_normal, repeat_enable, filter_linear_mipmap`. Decode its RG channels, avoiding dependence on blue-channel compression:

~~~glsl
vec2 uv_a = world_position.xz * 0.18 + TIME * vec2(0.018, 0.006);
vec2 uv_b = world_position.xz * 0.11 + TIME * vec2(-0.009, 0.012);
vec2 perturb = (texture(normal_texture, uv_a).rg * 2.0 - 1.0
             + texture(normal_texture, uv_b).rg * 2.0 - 1.0) * 0.06;
float distance_fade = 1.0 - smoothstep(45.0, 140.0, length(VERTEX));
vec3 n_world = normalize(vec3(perturb.x * distance_fade, 1.0,
                              perturb.y * distance_fade));
if (!FRONT_FACING) n_world = -n_world;
NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
ROUGHNESS = 0.28;
SPECULAR = 0.25;
METALLIC = 0.0;
~~~

Use a world-position varying calculated in `vertex()`. Verify the texture's Y convention by viewing a glint from two camera headings; invert its second perturbation component if the imported map needs it. Native sky reflection and direct sun specular now have valid normals. Do not add a second manually computed reflection term on top of native specular. See [spatial shader normal spaces](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html).

### 5.4 Color, opacity and foam

Initial color uniforms: shallow `#80CBBE`, deeper `#2D9FAA`, offshore `#236D89`, foam `#F4F6DE`. Treat them as proposed sRGB material values. Use:

~~~glsl
vec3 body_color = mix(shallow_color, deep_color, smoothstep(0.25, 3.2, bed_depth));
body_color = mix(body_color, offshore_color,
                 smoothstep(55.0, 230.0, shore_distance) * 0.75);
float facet = texture(noise_texture, world_position.xz * 0.09).r;
body_color *= 1.0 + (facet - 0.5) * 0.12;

float absorption = 1.0 - exp(-0.20 * path_length);
float f = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
float opacity = clamp(max(absorption, 0.65 * f), 0.04, 0.92);
opacity *= smoothstep(0.0, 0.35, shore_distance);
~~~

At 1 m ray thickness, absorption is about 18%; at 5 m it is about 63%. This lets shallow sand show through while making oblique/distant water read as water.

Author the shore surf from the **shore coordinate**, so an unrelated submerged object cannot become a large shoreline:

~~~glsl
float noise = texture(noise_texture, world_position.xz * 0.8
                       + TIME * vec2(0.02, -0.01)).r;
float advance = 0.55 + 0.40 * sin(TIME * 1.25 + world_position.x * 0.08);
float band = 1.0 - smoothstep(0.08, 0.24,
                              abs(shore_distance - advance));
float breakup = smoothstep(0.28, 0.62, noise);
float shore_foam = band * breakup;
float contact_foam = (1.0 - smoothstep(0.02, 0.18, contact_depth))
                     * breakup * 0.25;
float foam = max(shore_foam, contact_foam);
ALBEDO = mix(body_color, foam_color, foam);
ALPHA = max(opacity, foam * 0.9);
~~~

Soften the narrow mask edges by at least `fwidth(shore_distance)` at distance to prevent flashing pixels. Keep contact foam much weaker than surf. Fade contact foam away beyond 25 m and when depth is invalid. Foam replaces color instead of repeatedly adding to ALBEDO and clipping white. There is no separate shore-strip mesh unless a demonstrated coverage defect remains.

For the underside, branch on `FRONT_FACING`: face the normal downward, suppress shore/contact foam, use a restrained constant alpha near 0.2 and the underwater tint; do not apply the above-water absorption equation to the air above the camera. Test the underside against the shared sky reflection and underwater Environment.

**Pass condition:** one stationary patch keeps its base palette when the camera tilts; foam follows the bay at player height and above; the sun makes broad moving glints; clear shallows reveal sand without turning the whole sea opaque. A glass bottle, floating prop, pier pile and rescue attachment remain visible through the surface. Alpha blending cannot perfectly sort intersecting transparent meshes; document any residual case and adjust the affected glass material, not gameplay ownership.

## 6. V04 — Controlled clouds, horizon haze and contact shading

### 6.1 Cloud material

Write `beach_clouds.gdshader` as `unshaded, cull_disabled` on the existing low-poly cloud ring. Unshaded is intentional here: shade the facets analytically and leave the native sky independent of cloud-mesh normals.

~~~glsl
vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
float top = smoothstep(-0.45, 0.65, n_world.y);
vec3 cloud = mix(underside_color, top_color, top);
cloud += vec3(0.025) * max(dot(n_world, sun_direction), 0.0);
ALBEDO = cloud;
~~~

Use top `#FFF4DF` and underside `#BACBDF`, no emission, and no shadow casting. Set `sun_direction` from the actual Sun once when `city_backdrop.gd` constructs the clouds. Preserve the supplied facet normals. Reduce the current cloud Y scale from 4 to 2.5, retaining X/Z 2.2 initially; adjust only enough to show layered flat clouds with open blue sky. This removes the current strongly cyan undersides without forcing all world shadows warm.

### 6.2 Native atmosphere and AO

Enable these on `beach_environment.tres` after V01–V03:

| Property | First value |
|---|---|
| `fog_enabled / fog_mode` | `true / FOG_MODE_DEPTH` |
| `fog_depth_begin / end / curve` | `45 m / 500 m / 1.1` |
| `fog_density` | `0.55`, maximum blend in depth mode |
| `fog_light_color / energy` | `#C5E5E6 / 1.0` |
| `fog_sky_affect` | `0.05` |
| `fog_height_density / fog_sun_scatter` | `0 / 0.05` |
| `ssao_enabled / radius / intensity` | `true / 0.45 / 0.6` |

Fog uses the native depth mode, with a long transition and capped blend. It must soften the offshore mountain while preserving nearby chairs. Because Compatibility interpolates scene fog from geometry, inspect large ocean/land triangles; the water subdivisions above help prevent broad wedge-shaped haze.

Compatibility's SSAO is a screen-space approximation. Radius/intensity are its art controls; do not promise a world-space 45 cm radius or use Forward+ detail/power controls. Tune down if chair legs acquire halos, the first-person hand darkens the beach behind it, or the bright waterline gets an outline. Inspect panning motion as well as screenshots. [Godot 4.6 environment effects](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html).

Set the visible inland support land/paver materials in `city_backdrop.gd` to normal shaded materials, roughness 0.95 and subdued sand/concrete albedo. C04 still owns closing the exposed land boundary, arranging the bay silhouette and placing the skyline: fog does not remove a rectangular or floating land edge.

**Pass condition:** foreground contrast is stable, mountain contrast is reduced, lighthouse bands remain readable, cloud undersides are pastel blue-grey, and chair contacts are grounded without a screen-space dark halo.

## 7. V05 — Actually connect caustics and the underwater treatment

Stage the already supplied `Assets/Synty/POLYGON_Palm_City/textures/caustic_height.png`. Inspection shows a single broad cellular texture, not an 8×8 animation atlas. Use two slowly moving samples of its red data channel; do not invoke the old water shader's flipbook branch.

Write `beach_caustics.gdshaderinc` with a function accepting world position, world normal, water height, texture and time:

~~~glsl
float caustic_pattern(vec3 p, vec3 n, float water_y, float time,
                      sampler2D caustic_tex) {
    float depth = water_y - p.y;
    float submerged = smoothstep(0.08, 0.30, depth);
    float fade = 1.0 - smoothstep(2.5, 5.0, depth);
    float upward = smoothstep(0.15, 0.75, n.y);
    float a = texture(caustic_tex, p.xz * 0.35 + time * vec2(0.015, 0.008)).r;
    float b = texture(caustic_tex, p.xz * 0.43 + time * vec2(-0.01, 0.013)).r;
    float pattern = smoothstep(0.16, 0.46, min(a, b));
    return pattern * submerged * fade * upward;
}
~~~

Expose the two thresholds in the actual material so the supplied texture's channel range can be tuned. Use this function in the **sand shader** and the **reef shader**. Apply `ALBEDO *= 1.0 + 0.22 * pattern` on sand and 0.12 on reef stone, with albedo kept below 1. Caustics then participate in normal lighting rather than glowing through shade via emission. Use this single receiver treatment when viewing from above or below; remove the water-surface caustic contribution to avoid double intensity. Place the actual `seabed_caustics.tres` on the ridge/mound MultiMeshes in `reef_dressing.gd`.

Create the underwater Environment from the surface setup with these overrides:

| Property | First value |
|---|---|
| Background/sky | Same Sky resource as the surface |
| Ambient source / sky contribution | Color / 0 |
| Ambient color / energy | `#A0C0CA / 0.38` |
| Fog mode | Depth, matching the surface mode |
| Fog begin / end / curve / density | `0.4 m / 22 m / 0.85 / 0.95` |
| Fog color / sky affect | `#397F92 / 1.0` |
| Glow / SSAO | Off initially |
| Tonemap / exposure / LUT | Same as surface |

The current underwater resource selects Sky ambient without a Sky resource; correct that explicitly. Keep the existing oxygen/submerged-state decisions in `SwimService`. Add a visual-only environment copy per player camera and update it only during a 0.18 s transition after the existing submerged flag changes. Interpolate ambient energy/color and fog parameters between the two resources, which use the same fog mode. Retain the camera override through the exit fade, then set it to null to restore WorldEnvironment. Never interpolate the shared resource used by every camera, and never delay oxygen/physics transitions for the visual fade. On load or player reconfiguration initialize the visual state immediately from the real submerged state.

**Pass condition:** caustics appear on the actual sand and upper rock faces, with no dry-shore patterns; entering/leaving the sea causes one short color transition without flicker. Swim to the existing reef objectives and perform a rescue and pickup using the normal HUD.

## 8. V06 — Finish with native glow and a reproducible grade

Apply post processing only after the preceding shaders and lighting pass the raw-render comparison.

Set `glow_enabled=true`, `glow_intensity=0.12`, `glow_bloom=0.0`, `glow_hdr_threshold=0.95`, `glow_hdr_scale=1.0` and `glow_hdr_luminance_cap=2.0`. Tune threshold within 0.9–1.1 so it catches sunlit cream/cloud/foam highlights without putting a haze over all sand. Compatibility uses its own screen-blended glow path; `glow_strength`, levels, mix and glow map are not useful controls here. Keep bloom at zero; raise intensity to at most 0.20 only after checking the ungraded frame.

Use a 32×32×32 native `ImageTexture3D` LUT, generated once by `tools/build_beach_grade.gd` and saved to `art/look/beach_grade.res`. No runtime texture generation or custom fullscreen pass is required. The offline tool should make 32 RGB half-float slices, fill texels with `grade(Vector3(r,g,b)/31.0)`, create the Texture3D and save through ResourceSaver. Preserve an identity option in the same tool for an A/B check.

Initial display-space grading function:

~~~glsl
vec3 grade(vec3 c) {
    float y = dot(c, vec3(0.2126, 0.7152, 0.0722)); // display-space luma proxy
    float neutral = 1.0 - smoothstep(0.10, 0.35,
                         max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b)));
    float shadow = 1.0 - smoothstep(0.08, 0.45, y);
    float highlight = smoothstep(0.55, 0.95, y);
    vec3 tint = shadow * vec3(0.004, 0.0, 0.010)
              + highlight * vec3(0.010, 0.004, -0.010);
    tint *= smoothstep(0.0, 0.08, y) * (1.0 - smoothstep(0.95, 1.0, y));
    return clamp(c + neutral * tint, vec3(0.0), vec3(1.0));
}
~~~

Implement the equivalent in GDScript. This puts a little violet into neutral shade and cream into neutral highlights while mostly sparing colorful props. It deliberately preserves black and white detail; reduce the tint if material colors shift too much. Set `adjustment_enabled=true`, brightness/contrast/saturation all 1.0 and assign the LUT. Do not also bake brightness/contrast into the LUT and apply them again in the Environment.

The 4.6.1 Compatibility [post shader](https://raw.githubusercontent.com/godotengine/godot/4.6.1-stable/drivers/gles3/shaders/effects/post.glsl) applies color correction after conversion to sRGB. Generate the LUT for that domain; do not apply another gamma transform or tonemapper inside it. Verify the identity LUT does not introduce a color cast; allow for finite LUT interpolation at the extremes.

Keep the existing CanvasLayer HUD outside world post processing. Inspect white hover outlines, cyan water, yellow sand and red/green/blue sorting colors with the effect on/off. Retain native MSAA for silhouettes; do not add blur, depth of field, film grain, chromatic aberration or lens dirt to achieve softness.

**Pass condition:** the graded capture gains the references' gentle warmth and highlight spread while preserving cloud faces, sand detail, prop colors and HUD legibility. Glow-off and LUT-off comparisons must demonstrate their individual contribution.

## 9. Execution order and acceptance evidence

| Packet | Depends on | Concrete output | Evidence to keep |
|---|---|---|---|
| V00 | Current C04/C05 snapshot | Baseline with actual engine/settings recorded; existing capture viewport copies gameplay MSAA and camera clip values | Current dirty/restored pair at 1080p, representative HUD capture and frame profile |
| V01 | V00 | Corrected polygon/foliage shaders, staged references, light/sky resources and shadow settings | Fixed-object camera orbit, chair contact, palm underside, hut/table |
| V02 | V01 | Shared coast attributes and connected sand shader | Dry/wet/underwater sand from along-shore and aerial |
| V03 | V02 | Water grid and new normal/depth/palette/foam code | Stationary-patch tilt, walking surf, glass/prop/pier intersection, underside |
| V04 | V01–V03 | Cloud shader, native haze/AO, shaded backdrop support geometry | Coast pan, mountain/lighthouse silhouette, AO on/off |
| V05 | V02–V04 | Staged caustic data, actual receivers, underwater transition | Surface crossing, reef pickup and rescue with HUD |
| V06 | V01–V05 | Glow settings and generated LUT | Raw / glow-only / grade-only / final at matching cameras |
| V07 | V06 and current C04/C05/C07 content | Visual and performance handoff | Matching reference review, dirty and restored gameplay, target-device status |

Use the existing `tests/validate_pier_art.gd -- --review-pair --review-output=...` entry point, which delegates to the real full-run scene. In its existing `validate_full_run.gd` capture method set `viewport.msaa_3d = main.get_viewport().msaa_3d` and copy the player's near/far clip values into the capture camera. Keep FOV 85 and the existing transforms. For effect A/B images hold the shader animation time constant through a material debug-time uniform or capture the same point in the cycle; do not compare different foam phases as a lighting improvement. A short ordinary gameplay recording must also show moving water/shadows and UI.

During iteration, use the existing temporary run and cameras to inspect each effect without repeatedly running accelerated full completion for every slider. Save the full dirty/restored pair at V00, after water/lighting, and at final acceptance. The paired run is accelerated state setup and is not evidence of a human-paced completed game.

Recheck the affected play flow with real state: select/pick up a shadowed can, collect through shallow water, carry a chair into/out of shade, enter each hut and sort mixed material, swim/cut an attachment, and save/reload with the correct underwater appearance. Preserve ownership, payment, completion and save integrity. Reuse existing checks when their protected behavior is touched; update the old exact `facet_color_strength == 0.6` assertion to verify the new material contract rather than fixing an art-tuning constant. Follow [project verification guidance](05-verification.md); no new test framework or feature-per-scene suite.

### Performance gate and reductions

Initial effect budget to measure, not a promised benchmark: keep added GPU time around 2 ms at 1080p on the target device. Measure V01–V06 separately by toggling one effect at a time on the same route; record full-frame median/p95, CPU/GPU where available, draws and memory. The latest C04 record is already about 14.44 ms p95 on an RTX 3070, so spare target-hardware capacity cannot be inferred from its average. Final requirement remains 60 fps with p95 ≤18 ms on GTX 980-class hardware.

If needed, reduce in this order: disable SSAO → MSAA 4× to 2× → glow off → shadow range 150 to 110 m and resolution 4096 to 2048. Lowering effect intensity alone does not remove its GPU cost. Preserve the normal fixes, warm key/cool fill, water depth colors, thin surf and wet-sand palette; those create the main reference identity. Do not add settings UI until the measured result warrants another quality preset.

Compatibility is the implementation target for this specification. A Forward+ experiment is justified only if the accepted raw image specifically requires a larger soft-shadow penumbra or indirect lighting that this setup cannot supply. That experiment must migrate and compare the same materials, captures and target-device cost; enabling SDFGI/SSR alone is not an acceptance criterion. Supported renderer differences are documented in [Godot 4.6's comparison](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html).

### Finish criteria

The final C06 handoff must show the same cameras with warmer shaped sand light, muted cool shade, separated turquoise/blue water, narrow irregular surf, pastel cloud faces, softened distance, and readable underwater objectives. Record the values actually retained, shader/resource paths, gameplay observations and effect costs. Keep remaining C04 composition gaps visible in the handoff; no lighting grade can supply a missing landform, foreground prop cluster or coherent resort edge.

Planning validation for this revision covers inspected code, source documentation and local links. The proposed settings and shader blocks still require implementation, shader compilation and rendered play validation.
