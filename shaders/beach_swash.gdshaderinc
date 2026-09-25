// The swash: every few seconds a wave breaks in the shallows, rolls in as a line of white water,
// runs up the sand as a thin sheet with a lacy foam edge, and drains back, leaving darker, glossy
// sand that dries again. The sand and water shaders share this file so the surf, the run-up and
// the wet sand stay in step. Distances are metres from the waterline (Coastline.shore_z) along the
// beach normal: `p` landward on the sand, `s` seaward on the water. Presentation only.

const float SWASH_PERIOD = 8.5;        // seconds per wave
const float SWASH_RUNUP = 0.28;        // share of a cycle spent running up the sand
const float SWASH_GONE = 0.86;         // share at which the backwash has drained
const float SWASH_BORE_START = 0.42;   // share at which the next wave starts in from the surf
const float SWASH_BORE_DISTANCE = 11.0;
const float SWASH_REACH = 3.0;         // farthest run-up in metres; litter starts beyond it
const float SWASH_DRY_SECONDS = 4.0;   // how quickly uncovered sand loses its shine

float swash_hash(float n) {
	return fract(sin(n * 91.3458) * 47453.5453);
}

// Cycle index (x) and phase in the cycle (y) of the wave at this point of the beach. Waves arrive
// at an angle and in uneven sets, so the phase drifts along the shore.
vec2 swash_cycle(float x, float time) {
	float t = time / SWASH_PERIOD + x * 0.027 + 0.4 * sin(x * 0.021 + 1.7) + 0.12 * sin(x * 0.083);
	return vec2(floor(t), fract(t));
}

// How far the wave of `cycle` runs up here: beach cusps along the shore, big and small waves.
float swash_reach(float x, float cycle) {
	float along = 0.72 + 0.16 * sin(x * 0.19 + 0.4) + 0.12 * sin(x * 0.61 + 2.1);
	return SWASH_REACH * along * (0.5 + 0.5 * swash_hash(cycle));
}

// The farthest any wave reaches here, for the band of sand that never quite dries.
float swash_reach_max(float x) {
	return SWASH_REACH * (0.72 + 0.16 * sin(x * 0.19 + 0.4) + 0.12 * sin(x * 0.61 + 2.1));
}

// Front of the sheet at phase u: a quick run-up that slows, then a longer draining backwash.
float swash_front(float u, float reach) {
	if (u < SWASH_RUNUP) {
		float t = 1.0 - u / SWASH_RUNUP;
		return reach * (1.0 - t * t);
	}
	float back = clamp((u - SWASH_RUNUP) / (SWASH_GONE - SWASH_RUNUP), 0.0, 1.0);
	return reach * pow(1.0 - back, 1.7);
}

// Phase at which the backwash uncovers a point p metres up the sand (p below the reach).
float swash_uncovered_at(float p, float reach) {
	return SWASH_RUNUP + (SWASH_GONE - SWASH_RUNUP) * (1.0 - pow(clamp(p / reach, 0.0, 1.0), 1.0 / 1.7));
}

// Sand p metres above the waterline: x = sheet cover, y = foam, z = wetness, w = sheet depth.
vec4 swash_sand(float x, float p, float time) {
	vec2 cycle = swash_cycle(x, time);
	float u = cycle.y;
	float reach = swash_reach(x, cycle.x);
	float front = swash_front(u, reach);
	float edge = front - p;
	// The sheet starts at the waterline and thins in over its first 15 cm, where the water surface
	// turns transparent, so the two meet without a seam.
	float cover = smoothstep(-0.02, 0.05, edge) * smoothstep(0.0, 0.15, p);
	// Foam rides the front: a thick roll on the run-up, thin lace as the sheet drains.
	float running = 1.0 - smoothstep(SWASH_RUNUP * 0.75, SWASH_RUNUP + 0.12, u);
	float foam_width = mix(0.14, 0.4, running);
	float foam = (1.0 - smoothstep(0.0, foam_width, abs(edge - foam_width * 0.4))) * mix(0.4, 1.0, running) * smoothstep(0.0, 0.3, front) * smoothstep(0.0, 0.1, p);
	// Wet under the sheet; once the backwash leaves, the shine fades over a few seconds.
	float wet = cover;
	for (int back = 0; back < 3; back++) {
		float c = cycle.x - float(back);
		float r = swash_reach(x, c);
		if (p >= r) {
			continue;
		}
		float left = swash_uncovered_at(p, r);
		if (back == 0 && u < left) {
			continue;
		}
		float since = (u + float(back) - left) * SWASH_PERIOD;
		wet = max(wet, exp(-max(since, 0.0) / SWASH_DRY_SECONDS));
	}
	return vec4(cover, foam, wet, clamp(edge / 0.3, 0.0, 1.0));
}

// Water s metres out from the waterline: x = white water of the incoming wave, y = foam at the
// water's edge while the sheet is out on the sand.
vec2 swash_water(float x, float s, float time) {
	vec2 cycle = swash_cycle(x, time);
	float u = cycle.y;
	float bore = 0.0;
	if (u > SWASH_BORE_START) {
		float travel = (u - SWASH_BORE_START) / (1.0 - SWASH_BORE_START);
		float at = SWASH_BORE_DISTANCE * (1.0 - travel);
		// The wave peaks, breaks and turns white as it comes in.
		float grow = smoothstep(0.0, 0.35, travel);
		float width = mix(0.22, 0.6, travel);
		bore = (1.0 - smoothstep(0.0, width, abs(s - at))) * grow;
		// A trail of spent white water behind the breaking crest.
		bore = max(bore, (1.0 - smoothstep(0.0, 2.5, s - at)) * step(at, s) * grow * 0.3);
	}
	// As the wave reaches the sand its white water lingers in the inner surf, continuing exactly
	// from where the incoming line ended so there is no seam between one wave and the next.
	float landed = max(1.0 - smoothstep(0.0, 0.6, s), (1.0 - smoothstep(0.0, 2.5, s)) * 0.3);
	float wash = (1.0 - smoothstep(0.0, 0.18, u)) * landed;
	// Foam at the water's edge is busiest while the sheet runs up and drains.
	float busy = smoothstep(0.0, 0.1, u) * (1.0 - smoothstep(0.5, SWASH_GONE, u));
	float edge = (1.0 - smoothstep(0.0, 0.8, s)) * (0.3 + 0.45 * busy);
	return vec2(max(bore, wash), edge);
}
