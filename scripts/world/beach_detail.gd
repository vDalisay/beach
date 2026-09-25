class_name BeachDetail
extends RefCounted
## The Beach detail graphics setting on the shared sand and water materials, so the title backdrop
## and the run both follow it live:
##   0 Off     plain sand, a still wet strip at the waterline, only edge foam on the water;
##   1 Low     waves run up the sand and leave it wet; one layer of sand grain and grit;
##   2 Medium  adds a second grain layer, wind ripples, grain relief, shells and lacy foam;
##   3 High    adds glinting grains.
## Sand detail reaches as far as the View distance setting allows. This script loads only the two
## materials, so SettingsStore can call it without pulling in the run's scripts.

const SAND := preload("res://shaders/beach_sand.tres")
const WATER := preload("res://shaders/beach_water.tres")
const DETAIL_DISTANCE := 32.0


static func apply(level: int, view_distance: float) -> void:
	SAND.set_shader_parameter("detail_level", clampi(level, 0, 3))
	SAND.set_shader_parameter("detail_distance", DETAIL_DISTANCE * view_distance)
	WATER.set_shader_parameter("surf_level", 1 if level > 0 else 0)
