extends GutTest

# AudioManager music rotation.
#
# play_music() indexes MUSIC_TRACKS and MUSIC_TRACK_NAMES with the same
# counter, so a length mismatch is an out-of-bounds read on whichever array is
# shorter — and only on the run that reaches that index, which is exactly the
# kind of thing that survives a smoke test. These are cheap invariants that
# would have caught it when a track was removed from one array and not both.

func test_track_arrays_are_the_same_length() -> void:
	assert_eq(AudioManager.MUSIC_TRACKS.size(), AudioManager.MUSIC_TRACK_NAMES.size(),
		"play_music() indexes both arrays with one counter")

func test_at_least_one_track() -> void:
	# rotation does `% MUSIC_TRACKS.size()` — an empty array is a divide by zero.
	assert_gt(AudioManager.MUSIC_TRACKS.size(), 0, "rotation modulo needs a non-empty array")

func test_every_track_file_exists() -> void:
	for path in AudioManager.MUSIC_TRACKS:
		assert_true(ResourceLoader.exists(path), "missing music resource: %s" % path)

func test_every_sfx_file_exists() -> void:
	for path in [AudioManager.SFX_BUTTON, AudioManager.SFX_JUMP, AudioManager.SFX_SMASH,
			AudioManager.SFX_SWOOSH, AudioManager.SFX_LIGHTNING]:
		assert_true(ResourceLoader.exists(path), "missing sfx resource: %s" % path)

func test_no_vgmusic_track_ships() -> void:
	# Regression guard: VGMusic.com hosts fan arrangements of copyrighted game
	# music. Attribution in the HUD is not a licence, and Newgrounds removes
	# submissions that carry it.
	for i in AudioManager.MUSIC_TRACKS.size():
		assert_false(AudioManager.MUSIC_TRACK_NAMES[i].to_lower().contains("vgmusic"),
			"unlicensed VGMusic track back in the rotation: %s" % AudioManager.MUSIC_TRACK_NAMES[i])
		assert_false(String(AudioManager.MUSIC_TRACKS[i]).contains("vg_bt_music"),
			"unlicensed VGMusic file back in the rotation: %s" % AudioManager.MUSIC_TRACKS[i])
