extends Node
# Autoload: AdManager
# Phase 7 — AdMob banner, Android only.
# Banner sits at top of screen, adaptive width.
# Hidden during READY/PREPARING gameplay states; shown on HOME, PAUSE, GAME_OVER.
# All calls fire-and-forget — failure must never block gameplay.
#
# Plugin classes (AdView, MobileAds, etc.) are loaded dynamically via load()
# inside the Android guard so this file parses cleanly in headless/test mode.

const BANNER_AD_UNIT_ID: String = "ca-app-pub-8297579382369512/5828422617"
const INTERSTITIAL_AD_UNIT_ID: String = "ca-app-pub-8297579382369512/7768190242"
const INTERSTITIAL_EVERY_N_GAMES: int = 5

var _ad_view = null
var _banner_loaded: bool = false
var _interstitial_ad = null
var _interstitial_loaded: bool = false

# Loaded dynamically on Android only — null on all other platforms
var _AdView = null
var _AdSize = null
var _AdPosition = null
var _AdListener = null
var _AdRequest = null
var _MobileAds = null
var _OnInitListener = null
var _UMP = null
var _ConsentInfo = null
var _ConsentRequestParams = null
var _ConsentForm = null
var _InterstitialAdLoader = null
var _InterstitialAdLoadCallback = null
var _FullScreenContentCallback = null

func _ready() -> void:
	if not OS.has_feature("android"):
		return
	_load_plugin_classes()
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_request_consent_then_init()

func _load_plugin_classes() -> void:
	var base := "res://addons/admob/gdscript/src/"
	_AdView           = load(base + "api/AdView.gd")
	_AdSize           = load(base + "api/core/AdSize.gd")
	_AdPosition       = load(base + "api/core/AdPosition.gd")
	_AdListener       = load(base + "api/listeners/AdListener.gd")
	_AdRequest        = load(base + "api/core/AdRequest.gd")
	_MobileAds        = load(base + "api/MobileAds.gd")
	_OnInitListener   = load(base + "api/listeners/OnInitializationCompleteListener.gd")
	_UMP              = load(base + "ump/api/UserMessagingPlatform.gd")
	_ConsentInfo      = load(base + "ump/api/ConsentInformation.gd")
	_ConsentRequestParams = load(base + "ump/core/ConsentRequestParameters.gd")
	_InterstitialAdLoader      = load(base + "api/InterstitialAdLoader.gd")
	_InterstitialAdLoadCallback = load(base + "api/listeners/InterstitialAdLoadCallback.gd")
	_FullScreenContentCallback  = load(base + "api/listeners/FullScreenContentCallback.gd")

# ---------------------------------------------------------------------------
# GDPR / UMP consent — required before loading ads in EU
# ---------------------------------------------------------------------------

func _request_consent_then_init() -> void:
	var params = _ConsentRequestParams.new()
	_UMP.consent_information.update(
		params,
		_on_consent_update_success,
		_on_consent_update_failure
	)

func _on_consent_update_success() -> void:
	if _UMP.consent_information.get_is_consent_form_available():
		_UMP.load_consent_form(_on_consent_form_loaded, _on_consent_form_failed)
	else:
		_init_mobile_ads()

func _on_consent_update_failure(error) -> void:
	print("AdManager: consent update failed [%d] %s — proceeding" % [error.error_code, error.message])
	_init_mobile_ads()

func _on_consent_form_loaded(form) -> void:
	var REQUIRED = _ConsentInfo.ConsentStatus.REQUIRED
	if _UMP.consent_information.get_consent_status() == REQUIRED:
		form.show(_on_consent_form_dismissed)
	else:
		_init_mobile_ads()

func _on_consent_form_failed(error) -> void:
	print("AdManager: consent form failed [%d] %s — proceeding" % [error.error_code, error.message])
	_init_mobile_ads()

func _on_consent_form_dismissed(error) -> void:
	if error:
		print("AdManager: consent dismissal error: ", error.message)
	_init_mobile_ads()

# ---------------------------------------------------------------------------
# MobileAds init → load banner
# ---------------------------------------------------------------------------

func _init_mobile_ads() -> void:
	var listener = _OnInitListener.new()
	listener.on_initialization_complete = _on_mobile_ads_ready
	_MobileAds.initialize(listener)

func _on_mobile_ads_ready(_status) -> void:
	print("AdManager: MobileAds initialized — loading banner + interstitial")
	_load_banner()
	_load_interstitial()

func _load_banner() -> void:
	if _ad_view != null:
		_ad_view.destroy()
		_ad_view = null
	var ad_size = _AdSize.new(728, 90)
	_ad_view = _AdView.new(BANNER_AD_UNIT_ID, ad_size, _AdPosition.Values.TOP)
	var listener = _AdListener.new()
	listener.on_ad_loaded = _on_banner_loaded
	listener.on_ad_failed_to_load = _on_banner_failed
	_ad_view.ad_listener = listener
	_ad_view.load_ad(_AdRequest.new())

func _on_banner_loaded() -> void:
	_banner_loaded = true
	print("AdManager: banner loaded — w=%d h=%d px=%dx%d" % [
		_ad_view.get_width(), _ad_view.get_height(),
		_ad_view.get_width_in_pixels(), _ad_view.get_height_in_pixels()
	])
	var state: GameManager.GameState = GameManager.game_state
	if state not in [GameManager.GameState.READY, GameManager.GameState.PREPARING]:
		_ad_view.show()

func _on_banner_failed(error) -> void:
	print("AdManager: banner failed to load: ", error.message)
	_banner_loaded = false

# ---------------------------------------------------------------------------
# Interstitial — shown every INTERSTITIAL_EVERY_N_GAMES games
# ---------------------------------------------------------------------------

func _load_interstitial() -> void:
	if _interstitial_ad != null:
		_interstitial_ad.destroy()
		_interstitial_ad = null
	_interstitial_loaded = false
	var loader = _InterstitialAdLoader.new()
	var callback = _InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _on_interstitial_loaded
	callback.on_ad_failed_to_load = _on_interstitial_failed
	loader.load(INTERSTITIAL_AD_UNIT_ID, _AdRequest.new(), callback)

func _on_interstitial_loaded(ad) -> void:
	_interstitial_ad = ad
	_interstitial_loaded = true
	var cb = _FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = _on_interstitial_dismissed
	cb.on_ad_failed_to_show_full_screen_content = func(_err): _load_interstitial()
	_interstitial_ad.full_screen_content_callback = cb
	print("AdManager: interstitial loaded")

func _on_interstitial_failed(error) -> void:
	print("AdManager: interstitial failed to load: ", error.message)
	_interstitial_loaded = false

func _on_interstitial_dismissed() -> void:
	print("AdManager: interstitial dismissed — reloading")
	_interstitial_ad = null
	_interstitial_loaded = false
	_load_interstitial()

func try_show_interstitial() -> void:
	if not OS.has_feature("android"):
		return
	var total: int = SaveManager.get_total_games_played()
	if total < INTERSTITIAL_EVERY_N_GAMES or total % INTERSTITIAL_EVERY_N_GAMES != 0:
		return
	if not _interstitial_loaded or _interstitial_ad == null:
		print("AdManager: interstitial due (game %d) but not ready" % total)
		return
	print("AdManager: showing interstitial (game %d)" % total)
	_interstitial_loaded = false
	_interstitial_ad.show()

# ---------------------------------------------------------------------------
# State-driven show / hide
# ---------------------------------------------------------------------------

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.READY, GameManager.GameState.PREPARING:
			hide_banner()
		GameManager.GameState.PAUSED, GameManager.GameState.FINISH, GameManager.GameState.END:
			show_banner()

func show_banner() -> void:
	if _ad_view == null or not _banner_loaded:
		return
	_ad_view.show()

func hide_banner() -> void:
	if _ad_view == null:
		return
	_ad_view.hide()

# Called from main_controller when HomeScreen is shown (no GameState maps to HOME)
func on_home_screen_shown() -> void:
	show_banner()
