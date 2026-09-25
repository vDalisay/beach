class_name PresentationLOD
extends RefCounted
## Update rate for presentation-only animation (fish flocks, turtle poses, wing flaps): every frame
## near the camera, every second or fourth frame farther away, and not at all while off-screen or
## out of range. Skipped animation simply holds its last pose; nothing here affects gameplay.

const NEAR := 20.0
const MID := 40.0


## 0 skips this frame's update; otherwise update once every N frames with the accumulated time.
static func interval(camera: Camera3D, center: Vector3, radius: float, max_distance := INF) -> int:
	if camera == null:
		return 1
	var distance := camera.global_position.distance_to(center)
	if distance - radius > max_distance:
		return 0
	if distance > radius:
		# Frustum planes face outward: fully beyond any of them means off-screen.
		for plane in camera.get_frustum():
			if plane.distance_to(center) > radius:
				return 0
	return 1 if distance < NEAR else (2 if distance < MID else 4)


## Whether an object that runs every `interval` frames updates on this frame. `phase` staggers
## objects so they do not all update together.
static func due(interval_frames: int, phase: int) -> bool:
	return interval_frames > 0 and (Engine.get_process_frames() + phase) % interval_frames == 0
