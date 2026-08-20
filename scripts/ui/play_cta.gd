class_name PlayStoreCta
extends RefCounted

# "Get it on Google Play" button, built in code and shared by the home, pause,
# and game-over screens.
#
# In code rather than in the .tscn files on purpose: on Android the player is
# already in the app, and on a CrazyGames / GameDistribution build an outbound
# store link is against portal rules (docs/WEB_PORTALS.md §4). A scene node
# would have to be found and hidden in three of the four build targets, and a
# missed one is a QA rejection. `attach()` returns null and adds nothing at all
# unless WebPortal says the CTA is allowed.
#
# The web build's whole job is getting people to install the Android version,
# so the CTA sits on every screen a player can idle on — not just game-over,
# which a player who never finishes a run would never reach.

const NODE_NAME: StringName = &"PlayStoreCTA"

const _FONT_PATH: String = "res://resources/fonts/Carton_Six.ttf"

# Carton_Six is a 194-glyph display face: no arrows, no guillemets, not even
# ">". A decorative leading glyph renders as fallback tofu, so the labels are
# plain text. test_web_portal.gd asserts every character here is in the font.
const TEXT_LONG:  String = "Get the full game on Google Play"
const TEXT_SHORT: String = "Get it on Google Play"

const _COLOR_NORMAL:  Color = Color(0.18, 0.60, 0.24)
const _COLOR_HOVER:   Color = Color(0.22, 0.70, 0.29)
const _COLOR_PRESSED: Color = Color(0.14, 0.48, 0.19)


# Adds the CTA to `parent` at `rect` (viewport coordinates, 1024x768) and
# returns it — or returns null, having added nothing, on Android, on desktop,
# and on portal web builds.
static func attach(parent: Node, rect: Rect2, text: String, font_size: int = 26) -> Button:
	if not WebPortal.show_play_cta():
		return null

	var btn := Button.new()
	btn.name = NODE_NAME
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_text = true

	btn.offset_left   = rect.position.x
	btn.offset_top    = rect.position.y
	btn.offset_right  = rect.position.x + rect.size.x
	btn.offset_bottom = rect.position.y + rect.size.y

	btn.add_theme_font_override("font", load(_FONT_PATH))
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color(0.85, 0.95, 0.85))

	btn.add_theme_stylebox_override("normal",  _style(_COLOR_NORMAL))
	btn.add_theme_stylebox_override("hover",   _style(_COLOR_HOVER))
	btn.add_theme_stylebox_override("pressed", _style(_COLOR_PRESSED))

	btn.pressed.connect(func():
		AudioManager.play_sfx(AudioManager.SFX_BUTTON)
		WebPortal.open_play_store())

	parent.add_child(btn)
	return btn


static func _style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.35)
	return sb
