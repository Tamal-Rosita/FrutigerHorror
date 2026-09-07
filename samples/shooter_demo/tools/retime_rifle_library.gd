extends SceneTree

## Rifle library retime tool.
##
## The rifle-shooting-mvc animations were authored at 60 FPS tempo while the
## rest of the character animations play at 30 FPS, so every rifle clip runs
## at half speed. This tool retimes the whole library in place by halving all
## keyframe times and clip lengths (motion preserved, tempo doubled).
##
## Re-run whenever a new 60-FPS rifle library is added:
##   godot --headless --path . -s res://samples/shooter_demo/tools/retime_rifle_library.gd

const LIB_PATH := "res://visual-novel/animations/rifle-shooting-mvc.res"
const SPEED_FACTOR := 0.5 # 60 FPS content -> 30 FPS playback


func _init() -> void:
	var lib: AnimationLibrary = load(LIB_PATH)
	if lib == null:
		push_error("Cannot load " + LIB_PATH)
		quit(1)
		return

	var copy: AnimationLibrary = lib.duplicate(true) as AnimationLibrary
	var total_keys := 0
	for anim_name in copy.get_animation_list():
		var anim: Animation = copy.get_animation(anim_name)
		for track in anim.get_track_count():
			for key in anim.track_get_key_count(track):
				anim.track_set_key_time(track, key, anim.track_get_key_time(track, key) * SPEED_FACTOR)
				total_keys += 1
		anim.length *= SPEED_FACTOR
		print("Retimed '", anim_name, "' -> length ", anim.length, "s")

	var err := ResourceSaver.save(copy, LIB_PATH)
	if err != OK:
		push_error("Save failed: ", err)
		quit(1)
		return
	print("Saved retimed library (", total_keys, " keyframes) to ", LIB_PATH)
	quit(0)
