extends SceneTree
## Builds the project-owned sand detail textures the beach sand shader reads:
##   art/textures/sand/sand_detail.png   RGBA, tileable over 2 m of beach:
##       R grain brightness, G wind-ripple height, B specks (dark grit below 0.5, pale shell grit
##       above), A sparkle grains.
##   art/textures/sand/sand_normals.png  RGBA, tileable, same 2 m: RG wind-ripple slope and BA
##       grain slope, each packed as 0.5 + slope * 0.5, so the shader can fade them separately.
##   art/textures/sand/shell_atlas.png   RGBA, 4×4 cells: scallops, cockles, mussels, whelks, a
##       sand dollar, a starfish, pebbles, shell shards and a seaweed scrap, lit from above with a
##       soft contact halo, for the shells the shader scatters across the sand.
##
##   godot --headless --path . -s res://tools/build_sand_detail.gd
##   godot --headless --path . --editor --import
##
## Deterministic: the same script always writes the same pixels.

const OUT := "res://art/textures/sand/"
const SIZE := 1024
const RIPPLES := 20
const ATLAS := 512
const CELL := 128

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_rng.seed = 20260925
	var started := Time.get_ticks_msec()
	_build_detail()
	_build_atlas()
	for file in ["sand_detail.png", "sand_normals.png", "shell_atlas.png"]:
		_configure_import(OUT + file)
	print("build_sand_detail: wrote %s in %d ms" % [OUT, Time.get_ticks_msec() - started])
	quit()


func _build_detail() -> void:
	var ripple := PackedFloat32Array()
	var grain := PackedFloat32Array()
	ripple.resize(SIZE * SIZE)
	grain.resize(SIZE * SIZE)
	var lattices := {}
	for period in [4, 16, 64, 128, 256, 512]:
		lattices[period] = _lattice(period)
	for y in SIZE:
		var v := float(y) / SIZE
		for x in SIZE:
			var u := float(x) / SIZE
			# Wind ripples: crests run along u and wander, with the steep lee face on one side.
			var warp := _value(lattices[4], 4, u, v) * 1.7 + _value(lattices[16], 16, u, v) * 0.35 + _value(lattices[64], 64, u, v) * 0.06
			var s := fposmod(v * RIPPLES + warp, 1.0)
			var profile := smoothstep(0.0, 0.72, s) if s < 0.72 else 1.0 - smoothstep(0.72, 1.0, s)
			var fade := 0.55 + 0.45 * _value(lattices[4], 4, u + 0.37, v + 0.61)
			ripple[y * SIZE + x] = profile * fade
			grain[y * SIZE + x] = _value(lattices[512], 512, u, v) * 0.5 + _value(lattices[256], 256, u, v) * 0.3 + _value(lattices[128], 128, u, v) * 0.2
	var detail := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var specks := PackedFloat32Array()
	specks.resize(SIZE * SIZE)
	specks.fill(0.5)
	# Dark grit and pale shell grit, a few millimetres across.
	for index in 5200:
		var dark := index < 3400
		_speck(specks, grain, _rng.randi_range(0, SIZE - 1), _rng.randi_range(0, SIZE - 1), _rng.randf_range(0.8, 2.6), 0.08 if dark else 0.95)
	var sparkle := PackedByteArray()
	sparkle.resize(SIZE * SIZE)
	for index in 9000:
		sparkle[_rng.randi_range(0, SIZE - 1) * SIZE + _rng.randi_range(0, SIZE - 1)] = 255
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			detail.set_pixel(x, y, Color(grain[i], ripple[i], specks[i], float(sparkle[i]) / 255.0))
	detail.save_png(ProjectSettings.globalize_path(OUT + "sand_detail.png"))
	# Slopes: ripples are a few millimetres tall over 10 cm; grain is rougher but finer.
	var normals := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var r_dx := (ripple[y * SIZE + (x + 1) % SIZE] - ripple[y * SIZE + (x + SIZE - 1) % SIZE]) * 1.2
			var r_dy := (ripple[((y + 1) % SIZE) * SIZE + x] - ripple[((y + SIZE - 1) % SIZE) * SIZE + x]) * 1.2
			var g_dx := (grain[y * SIZE + (x + 1) % SIZE] - grain[y * SIZE + (x + SIZE - 1) % SIZE]) * 2.5 + (specks[y * SIZE + (x + 1) % SIZE] - specks[y * SIZE + (x + SIZE - 1) % SIZE]) * 0.6
			var g_dy := (grain[((y + 1) % SIZE) * SIZE + x] - grain[((y + SIZE - 1) % SIZE) * SIZE + x]) * 2.5 + (specks[((y + 1) % SIZE) * SIZE + x] - specks[((y + SIZE - 1) % SIZE) * SIZE + x]) * 0.6
			normals.set_pixel(x, y, Color(_pack(r_dx), _pack(r_dy), _pack(g_dx), _pack(g_dy)))
	normals.save_png(ProjectSettings.globalize_path(OUT + "sand_normals.png"))


func _speck(specks: PackedFloat32Array, grain: PackedFloat32Array, cx: int, cy: int, radius: float, value: float) -> void:
	var reach := ceili(radius + 1.0)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var d := sqrt(float(dx * dx + dy * dy))
			var cover := clampf(radius + 0.5 - d, 0.0, 1.0)
			if cover <= 0.0:
				continue
			var i := ((cy + dy + SIZE) % SIZE) * SIZE + (cx + dx + SIZE) % SIZE
			specks[i] = lerpf(specks[i], value, cover)
			grain[i] = minf(1.0, grain[i] + cover * 0.08)


func _build_atlas() -> void:
	var atlas := Image.create(ATLAS, ATLAS, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var kinds := [
		["scallop", Color("f4e8d6"), Color("e0a98a")], ["scallop", Color("f7b3aa"), Color("d9645b")],
		["scallop", Color("f5c26e"), Color("e07b2c")], ["scallop", Color("d3c6ec"), Color("8f7cc0")],
		["cockle", Color("f0dcc0"), Color("a8764a")], ["cockle", Color("f3c9a2"), Color("bf6532")],
		["mussel", Color("3b4660"), Color("6b7a9e")], ["mussel", Color("4a3d5c"), Color("8a74a8")],
		["whelk", Color("f2dcc0"), Color("d08a54")], ["whelk", Color("f5ece0"), Color("b8a58e")],
		["dollar", Color("e8e2d2"), Color("c7bda6")], ["star", Color("f29a5e"), Color("d9683a")],
		["pebble", Color("a59f97"), Color("7d7770")], ["pebble", Color("b79d82"), Color("8a735d")],
		["shard", Color("f7f1e6"), Color("d8c9b4")], ["weed", Color("6f7a3e"), Color("4f5a2c")],
	]
	for index in kinds.size():
		var kind: Array = kinds[index]
		var ox := (index % 4) * CELL
		var oy := (index / 4) * CELL
		for y in CELL:
			for x in CELL:
				# Cell space: -1..1 with a margin so mip levels do not bleed into neighbours.
				var p := Vector2((float(x) + 0.5) / CELL * 2.0 - 1.0, (float(y) + 0.5) / CELL * 2.0 - 1.0) * 1.12
				var sample := _shell(str(kind[0]), p, kind[1] as Color, kind[2] as Color, index)
				atlas.set_pixel(ox + x, oy + y, sample)
	atlas.save_png(ProjectSettings.globalize_path(OUT + "shell_atlas.png"))


## One atlas pixel: the shape's colour with baked top light, or a faint contact halo around it.
func _shell(kind: String, p: Vector2, base: Color, accent: Color, index: int) -> Color:
	var d := 1.0
	var shade := 1.0
	var tint := base
	match kind:
		"scallop":

			# A rounded valve with a scalloped rim and ribs radiating from the hinge, plus two ears.
			var hinge := Vector2(0, 0.7)
			var q := p - hinge
			var angle := atan2(q.x, -q.y)
			var rib := 0.5 + 0.5 * cos(angle * 13.0)
			var body := (p - Vector2(0, -0.08)).length() - (0.74 + 0.035 * rib)
			var cone := absf(angle) * q.length() - 0.9 * q.length() * 0.95
			d = maxf(body, minf(cone, body + 0.4))
			d = minf(d, _box(p - Vector2(0, 0.68), Vector2(0.3, 0.09)))
			shade = 0.78 + 0.22 * rib
			tint = base.lerp(accent, 0.35 * (1.0 - rib) + 0.3 * smoothstep(0.2, 0.9, q.length()))
		"cockle":
			var q := p * Vector2(1.0, 1.08)
			d = q.length() - 0.72
			var angle := atan2(p.x, -(p.y - 0.7))
			var rib := 0.5 + 0.5 * cos(angle * 22.0)
			shade = 0.78 + 0.22 * rib
			tint = base.lerp(accent, 0.45 * smoothstep(0.1, 0.72, q.length()) + 0.2 * (1.0 - rib))
		"mussel":
			# An elongated, slightly bent teardrop with a blue-violet sheen.
			var q := Vector2(p.x - 0.12 * p.y * p.y, p.y) * Vector2(1.9, 0.95)
			d = q.length() - 0.78 + 0.18 * p.y
			var band := 0.5 + 0.5 * sin(q.length() * 18.0)
			shade = 0.85 + 0.15 * band
			tint = base.lerp(accent, clampf(0.6 - q.x * 0.5, 0.0, 1.0) * 0.6)
		"whelk":
			# A small spiral cone: stacked whorls narrowing to a tip.
			# A small spiral shell: a rounded body tapering to a pointed tip, banded by whorls.
			var q := p.rotated(0.5)
			var spire := maxf(absf(q.x) - 0.46 * clampf((q.y + 0.92) / 1.1, 0.0, 1.0), maxf(-q.y - 0.92, q.y - 0.3))
			var body := (q - Vector2(0.04, 0.34)).length() - 0.46
			d = minf(spire, body)
			var whorl := 0.5 + 0.5 * sin((q.y - absf(q.x) * 0.55) * 15.0)
			var aperture := 1.0 - smoothstep(0.0, 0.12, (q - Vector2(0.14, 0.44)).length() - 0.16)
			shade = (0.74 + 0.26 * whorl) * (1.0 - 0.35 * aperture)
			tint = base.lerp(accent, 0.55 * whorl * (1.0 - aperture))
		"dollar":
			d = p.length() - 0.7
			var petal := 0.5 + 0.5 * cos(atan2(p.y, p.x) * 5.0)
			var ring := smoothstep(0.18, 0.45, p.length()) * (1.0 - smoothstep(0.45, 0.55, p.length()))
			shade = 1.0 - 0.18 * petal * ring
			tint = base.lerp(accent, 0.5 * petal * ring)
		"star":
			var angle := atan2(p.y, p.x)
			var arm := 0.5 + 0.5 * cos(angle * 5.0)
			d = p.length() - (0.32 + 0.55 * pow(arm, 3.0))
			shade = 0.8 + 0.2 * (1.0 - p.length())
			tint = base.lerp(accent, 0.4 * smoothstep(0.2, 0.8, p.length()))
		"pebble":
			var q := p * Vector2(1.0, 1.35 if index % 2 == 0 else 1.15)
			d = q.length() - 0.62
			shade = 0.85 + 0.15 * (1.0 - q.length())
		"shard":
			var q := p.rotated(0.7)
			d = maxf(maxf(q.y - 0.35, -q.y - 0.45), maxf(q.x * 0.9 + q.y * 0.4 - 0.5, -q.x * 1.1 + q.y * 0.3 - 0.45))
			shade = 0.9
		"weed":
			# A wavy strand of dried seaweed.
			var along := p.x
			var centre := 0.28 * sin(along * 3.4)
			d = maxf(absf(p.y - centre) - 0.1 * (1.0 - absf(along)), absf(along) - 0.92)
			shade = 0.8 + 0.2 * sin(along * 20.0)
	# Soft top light: brighter toward the upper-left rim, darker toward the lower edge.
	var light := clampf(1.0 - (p.y * 0.18) - (p.x * 0.06), 0.8, 1.1)
	var edge := clampf(0.5 - d * CELL * 0.5, 0.0, 1.0)
	var rim := smoothstep(-0.14, 0.0, d) * edge
	var colour := tint * shade * light
	colour = colour.darkened(0.4 * rim)
	# Contact halo: a faint dark ring that settles the shape into the sand.
	var halo := (1.0 - smoothstep(0.0, 0.2, d)) * 0.55 * (1.0 - edge)
	if edge <= 0.0:
		return Color(0.18, 0.13, 0.08, halo)
	return Color(colour.r, colour.g, colour.b, clampf(edge + halo, 0.0, 1.0))


func _box(p: Vector2, half: Vector2) -> float:
	var q := p.abs() - half
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)


func _lattice(period: int) -> PackedFloat32Array:
	var values := PackedFloat32Array()
	values.resize(period * period)
	for index in values.size():
		values[index] = _rng.randf()
	return values


## Tileable value noise with `period` lattice cells across the tile.
func _value(lattice: PackedFloat32Array, period: int, u: float, v: float) -> float:
	var fx := fposmod(u, 1.0) * period
	var fy := fposmod(v, 1.0) * period
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var x1 := (ix + 1) % period
	var y1 := (iy + 1) % period
	var a := lattice[iy * period + ix]
	var b := lattice[iy * period + x1]
	var c := lattice[y1 * period + ix]
	var d := lattice[y1 * period + x1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _pack(slope: float) -> float:
	return clampf(0.5 + slope * 0.5, 0.0, 1.0)


## Lossless and linear: these textures carry data (slopes, masks) as much as colour.
func _configure_import(path: String) -> void:
	var settings := ConfigFile.new()
	settings.load(ProjectSettings.globalize_path(path) + ".import")
	settings.set_value("remap", "importer", "texture")
	settings.set_value("remap", "type", "CompressedTexture2D")
	settings.set_value("params", "compress/mode", 0)
	settings.set_value("params", "mipmaps/generate", true)
	settings.set_value("params", "detect_3d/compress_to", 0)
	settings.save(ProjectSettings.globalize_path(path) + ".import")
