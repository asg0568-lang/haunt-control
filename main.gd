extends Node2D

# --- Base values (abilities modify these) ---
const BASE_MAX_FEAR := 100.0
const BASE_SCARE_COST := 25.0
const BASE_WALL_COST := 50.0
const BASE_REGEN := 8.0

# --- Tuning (change these to adjust the feel) ---
const SCARE_COOLDOWN := 0.9
const SCARE_DAMAGE := 25.0
const SCARE_RANGE := 140.0
const STUN_TIME := 1.2
const FLASH_RADIUS := 150.0
const GHOST_RADIUS := 12.0
const SCREAM_COURAGE_PCT := 0.10   # scream removes 10% of each visitor's max courage
const SCREAM_SLOW := 0.8           # scream makes visitors walk 20% slower
const RELOCATE_MIN_DIST := 480.0   # how far the remains should jump

# --- Lighting quality tuning ---
const LOWMEM_GB := 4.0             # devices reporting this much RAM or less count as low-memory
const AUTO_LOWMEM_TIER := "lite"   # what Auto picks on low-memory devices: "lite" or "medium"
const SHADOW_TEX_FULL := 2048      # shadow texture size in Full lighting
const SHADOW_TEX_LOW := 512        # shadow texture size in Medium lighting (looks the same, far less memory)

# --- Energy refill penalties ---
const RELOCATE_REGEN_MULT := 0.9   # owning Soul Shift: refill 10% slower
const SCREAM_REGEN_MULT := 0.75    # after screaming: refill 25% slower for the rest of the level
const COMBO_REGEN_MULT := 0.6      # used BOTH scream and Soul Shift in one level: refill 40% slower

# --- Priest (chaser) tuning ---
const CHASER_SIGHT := 280.0          # how far he can see you
const CHASER_SPEED := 135.0          # chase speed
const CHASER_WAVE_RANGE := 130.0     # he starts charging when this close
const CHASER_WINDUP := 0.8           # seconds to charge the shockwave
const CHASER_WAVE_RADIUS := 200.0    # size of the shockwave
const CHASER_WAVE_COOLDOWN := 10.0   # seconds before he can chase again
const CHASER_ENERGY_DRAIN := 0.6     # fraction of MAX energy you lose

# --- Dodge and counter (priest level) ---
const DODGE_TIME := 0.6              # seconds you are phased out
const DODGE_COOLDOWN := 1.6          # seconds before you can dodge again
const COUNTER_WINDOW := 1.0          # seconds to scare him after a perfect dodge
const COUNTER_DAMAGE_PCT := 0.35     # counter hit removes 35% of his max courage

# --- Touch control layout (game screen is 1152 x 648) ---
const JOY_RADIUS := 70.0
const JOY_REST := Vector2(150, 520)
const SKIP_RECT := Rect2(990, 76, 150, 50)

# --- Progress and settings that survive level reloads ---
static var current_level: int = 0
static var owned: Array = []
static var offered: Array = ["energy", "cheap_scare", "cheap_wall"]
static var rewarded_levels: Array = []
static var menu_shown: bool = true
static var master_volume: float = 1.0
static var settings_loaded: bool = false
static var touch_mode: bool = false
static var light_quality: int = 0     # 0 = Auto, 1 = Full, 2 = Lite, 3 = Medium

# Which new ability gets added to the reward pool after each level
var new_ability_for_level: Dictionary = {1: "scream", 2: "relocate"}

var ability_info: Dictionary = {
	"energy": {
		"name": "Spectral Surge",
		"desc": "Max energy +25% (from the next level)."
	},
	"cheap_scare": {
		"name": "Whisper Mastery",
		"desc": "Scares cost 10% less energy."
	},
	"cheap_wall": {
		"name": "Phase Shift",
		"desc": "Passing through walls costs 25% less energy."
	},
	"scream": {
		"name": "Banshee Scream",
		"desc": "Once per level (E key / SCREAM button): visitors inside lose 10% courage and walk slower. But your energy refills 25% slower for the rest of that level."
	},
	"relocate": {
		"name": "Soul Shift",
		"desc": "Once per level (Q key / SOUL button): your remains jump far away. Your energy always refills 10% slower, and using BOTH Soul Shift and Scream in one level makes it 40% slower."
	}
}

# Things visitors say when you scream
var scream_lines: Array = [
	"WTF was that?!",
	"I'm really scared...",
	"Did you hear that scream?!",
	"What the hell was that?!",
	"I want to get out of here!",
	"That sounded like it was right next to me!"
]

# ---------------------------------------------------------------
# LEVEL DATA: edit visitors, speeds and dialogue here
# ---------------------------------------------------------------
var levels: Array = [
	{
		"title": "LEVEL 1 - Tutorial",
		"intro": "Learn how to haunt. One nervous visitor, no pressure.",
		"tutorial": true,
		"notice_range": 170.0, "destroy_time": 9.0, "panic": 0.0,
		"shout": false, "rain": false, "search": false,
		"visitors": [
			{
				"name": "Rohan", "courage": 60.0, "speed": 45.0, "delay": 0.0,
				"color": Color(1.0, 0.85, 0.3),
				"enter": ["Okay. Just a quick look inside."],
				"idle": ["So this is the famous haunted house...", "Hello? Anyone home?", "Creepy... but kind of cool.", "I'll just take a quick look around.", "Was that a draft? Or something else?"],
				"notice": ["What's that glowing thing?", "Is that... someone's remains?!"],
				"destroy": ["I'd better get rid of this thing!", "Whatever this is, it ends now."],
				"scared": ["Wh-what was that?!", "Something just touched me!", "Okay, I don't like this."],
				"flee": ["NOPE! I'm out of here!"]
			}
		]
	},
	{
		"title": "LEVEL 2 - Ghost Hunters",
		"intro": "Two kids sneak in to prove ghosts are real. One is braver than the other.",
		"notice_range": 230.0, "destroy_time": 5.0, "panic": 20.0,
		"shout": true, "rain": false, "search": false,
		"visitors": [
			{
				"name": "Aarav", "courage": 80.0, "speed": 72.0, "delay": 0.0,
				"color": Color(0.4, 0.7, 1.0),
				"enter": ["Ghost hunting time!"],
				"idle": ["Ghosts aren't real. I'll prove it!", "Come out, ghost! We're not scared!", "Meera, stop hiding behind me."],
				"notice": ["Found it! That's the ghost's stuff!"],
				"destroy": ["Let's smash it! No more ghost!", "This will stop it for good!"],
				"scared": ["Th-that was just the wind. Right?", "I'm NOT scared! ...okay maybe."],
				"flee": ["RUN!"]
			},
			{
				"name": "Meera", "courage": 55.0, "speed": 66.0, "delay": 1.2,
				"color": Color(1.0, 0.6, 0.8),
				"enter": ["I want to go home..."],
				"idle": ["I don't like this, Aarav...", "What if it's actually real?", "Did you hear that?"],
				"notice": ["Aarav! Over here! Hurry!"],
				"destroy": ["Break it! Please just break it!"],
				"scared": ["AAAH! It's real!", "I want my mom!"],
				"flee": ["MUMMYYY!"]
			}
		]
	},
	{
		"title": "LEVEL 3 - Storm Shelter",
		"intro": "Three strangers duck in out of the rain, and start searching every room.",
		"notice_range": 250.0, "destroy_time": 5.5, "panic": 15.0,
		"shout": false, "rain": true, "search": true,
		"visitors": [
			{
				"name": "Vikram", "courage": 85.0, "speed": 70.0, "delay": 0.0,
				"color": Color(0.5, 0.9, 0.5),
				"enter": ["Finally, shelter from the storm!"],
				"idle": ["Let's wait out the rain in here.", "Spread out and check every room.", "Whose house is this anyway?"],
				"notice": ["Hey! Come look at this!"],
				"destroy": ["Something's wrong here. Break it!"],
				"scared": ["Who's there?!", "Stay calm, everyone. Stay calm!"],
				"flee": ["Forget the rain, RUN!"]
			},
			{
				"name": "Nisha", "courage": 70.0, "speed": 66.0, "delay": 1.5,
				"color": Color(0.8, 0.6, 1.0),
				"enter": ["I'm soaked. Is there a towel?"],
				"idle": ["My phone has no signal...", "Why is it so cold in here?", "Is anyone else seeing this?"],
				"notice": ["Is that thing... glowing?"],
				"destroy": ["Get rid of it. Now!"],
				"scared": ["Did something just whisper?!", "I felt something behind me!"],
				"flee": ["I'm leaving! Storm or not!"]
			},
			{
				"name": "Imran", "courage": 60.0, "speed": 62.0, "delay": 3.0,
				"color": Color(1.0, 0.6, 0.35),
				"enter": ["Ugh, the rain is brutal."],
				"idle": ["This place gives me the creeps.", "Did the lights just flicker?", "I hate old houses."],
				"notice": ["That's NOT normal. Look!"],
				"destroy": ["Smash it before it smashes us!"],
				"scared": ["Nope. Nope. Nope!", "Something's in here with us!"],
				"flee": ["I'd rather drown in the rain!"]
			}
		]
	},
	{
		"title": "LEVEL 4 - The Exorcist",
		"intro": "The priest from the church has come to cleanse the house. He fights back. Dodge his shockwave, then strike!",
		"notice_range": 250.0, "destroy_time": 5.0, "panic": 0.0,
		"shout": false, "rain": false, "search": true,
		"visitors": [
			{
				"name": "Father Joseph", "courage": 200.0, "speed": 55.0, "delay": 0.0,
				"color": Color(0.9, 0.9, 1.0),
				"chaser": true,
				"enter": ["Peace be upon this house. I have come to cleanse it."],
				"idle": ["Lord, banish the darkness from this place.", "I sense a restless spirit here...", "Be gone, wandering soul. Find your rest.", "This house shall be clean before sunrise.", "The air is heavy here. Something dwells within."],
				"notice": ["There! The source of the haunting!", "So this is what binds you here."],
				"spot": ["I see you, spirit!", "There you are!", "You cannot hide from the light!"],
				"wave": ["BEGONE, SPIRIT!", "BY HOLY LIGHT!", "BE CAST OUT!"],
				"hurt": ["ARGH!", "How... how did you dodge that?!", "Impossible! You struck me?!", "You will pay for that, spirit!"],
				"destroy": ["By the power of faith, this ends today!", "Return to dust, restless one!"],
				"scared": ["I am not afraid of you, spirit!", "Lord, give me strength!", "Your tricks will not drive me out!", "Stand firm, Father... stand firm."],
				"flee": ["I... I must regroup! Forgive me, Lord!"]
			}
		]
	}
]

# ---------------------------------------------------------------
# TUTORIAL TEXT
# {MOVE}, {SCARE}, {SCARE_CAP}, {NEXT} change depending on keyboard or touch.
# The intro pages pause the game once at the start. The tips never pause it.
# ---------------------------------------------------------------
var tut_text: Dictionary = {
	"welcome": [
		"WELCOME TO HAUNT CONTROL\n\nYou are a ghost haunting this old house.\n\n{MOVE}",
		"YOUR GOAL\n\nA visitor is about to walk in. Scare him until the green COURAGE bar above his head hits zero, and he will run out the front door.",
		"YOUR REMAINS\n\nThe glowing PURPLE SQUARE hidden in the house is your REMAINS. If he finds them, he will start destroying them. When the red bar at the top fills up, you lose.",
		"SCARING\n\n{SCARE_CAP} when you are close to him with no wall in between. It costs 25 energy and has a short cooldown, so don't spam it.\n\nHis FLASHLIGHT drains your energy. Stay out of the light. Walls block it.",
		"WALLS\n\nYou can pass through walls, but it costs 50 energy (the white mark on the energy bar). With less than that, use the doorways.\n\nGood luck!"
	]
}

var tip_text: Dictionary = {
	"near": "Get close and {SCARE} to scare him!",
	"light": "You're in his flashlight! Step out of the light, or hide behind a wall.",
	"hit": "Nice! Scares drain his courage and stun him. Keep going!",
	"destroying": "He's destroying your remains! Rush over and scare him!"
}

# --- Visitor data ---
class Visitor:
	var vname: String = ""
	var data: Dictionary = {}
	var pos: Vector2 = Vector2.ZERO
	var entry_target: Vector2 = Vector2.ZERO
	var color: Color = Color(1.0, 0.85, 0.3)
	var courage: float = 100.0
	var max_courage: float = 100.0
	var speed: float = 60.0
	var delay: float = 0.0
	var started: bool = false
	var entered: bool = false
	var noticed: bool = false
	var fleeing: bool = false
	var gone: bool = false
	var at_remains: bool = false
	var destroy_said: bool = false
	var stun: float = 0.0
	var idle: float = 0.0
	var chat_cd: float = 3.0
	var need_repath: bool = true
	var path: PackedVector2Array = PackedVector2Array()
	var path_i: int = 0
	var room_queue: Array = []
	var say_text: String = ""
	var shown_text: String = ""
	var say_timer: float = 0.0
	var light: PointLight2D
	var bubble: Label
	# Chaser (priest) only
	var chaser: bool = false
	var chase_state: String = "none"   # "none", "chase" or "windup"
	var windup_t: float = 0.0
	var wave_cd: float = 0.0
	var repath_cd: float = 0.0
	var lose_t: float = 0.0

# --- Map ---
const CELL := 16
const GRID_W := 72
const GRID_H := 41
const VISITOR_RADIUS := 14.0
const START_POS := Vector2(580, 640)    # outside the front door
const ENTRY_TARGET := Vector2(580, 540)  # just inside the front door
const EXIT_POS := Vector2(580, 636)
var walls: Array = []
var furniture: Array = []
var solids: Array = []
var doors: Array = []
var room_centers: Array = []
var remain_rooms: Array = []
var astar: AStarGrid2D
# Floor colours by [column][row]
var floor_cols: Array = [
	[Color(0.52, 0.42, 0.46), Color(0.32, 0.5, 0.6)],    # bedroom, bathroom
	[Color(0.6, 0.45, 0.3), Color(0.5, 0.5, 0.53)],      # living room, entrance hall
	[Color(0.75, 0.72, 0.55), Color(0.5, 0.38, 0.3)]     # kitchen, study
]

# --- Level settings (filled from the level data) ---
var level_data: Dictionary = {}
var notice_range: float = 230.0
var destroy_time: float = 5.0
var panic_amount: float = 0.0
var shout_mode: bool = false
var rain_on: bool = false
var search_mode: bool = false
var tutorial_mode: bool = false
var has_chaser: bool = false

# --- Lighting quality ---
var light_tier: String = "full"     # "full", "medium" or "lite"
var lite_lighting: bool = false     # true = no shadows at all
var medium_lighting: bool = false   # true = cheaper shadows
var device_mem: float = 0.0         # approximate RAM in GB (browser only, 0 = unknown)
var quality_changed: bool = false

# --- Ghost stats (calculated from the abilities you own) ---
var max_fear: float = 100.0
var scare_cost: float = 25.0
var wall_cost: float = 50.0

# --- Touch controls ---
var joy_id: int = -1
var joy_origin: Vector2 = Vector2.ZERO
var joy_vec: Vector2 = Vector2.ZERO
var touch_scare_queued: bool = false
var touch_node: Node2D
var rotate_layer: CanvasLayer
var hint_label: Label

# --- Main menu ---
var menu_active: bool = false
var menu_layer: CanvasLayer
var main_box: VBoxContainer
var settings_box: VBoxContainer
var start_btn: Button
var vol_slider: HSlider
var vol_label: Label
var light_opt: OptionButton
var light_note: Label
var menu_note: Label

# --- Reward screen ---
var reward_active: bool = false
var reward_choices: Array = []
var reward_panel: PanelContainer
var reward_box: VBoxContainer

# --- Ability state (resets every level) ---
var scream_used: bool = false
var relocate_used: bool = false
var scream_t: float = -1.0
var scream_origin: Vector2 = Vector2.ZERO
var info_text: String = ""
var info_timer: float = 0.0
var abil_label: Label

# --- Dodge and counter state (priest level) ---
var dodge_t: float = 0.0
var dodge_cd: float = 0.0
var counter_t: float = 0.0
var counter_fx_t: float = -1.0
var counter_fx_pos: Vector2 = Vector2.ZERO
var dodge_hint_shown: bool = false

# --- Priest shockwave effects ---
var wave_t: float = -1.0
var wave_origin: Vector2 = Vector2.ZERO
var shock_flash: float = 0.0

# --- Tutorial intro pop-up (game is paused only while this is open) ---
var tut_active: bool = false
var tut_pages: Array = []
var tut_idx: int = 0
var tut_shown: Dictionary = {}
var tut_label: Label

# --- Tutorial tips (never pause the game) ---
var tip_label: Label
var tip_shown: Dictionary = {}
var tip_timer: float = 0.0

# --- Game state: "play", "won", "lost" ---
var game_state := "play"
var end_timer := 0.0
var title_timer := 4.0

# --- Ghost ---
var ghost_pos := Vector2(300, 250)
var ghost_speed := 220.0
var fear_energy := 100.0
var scare_cd := 0.0
var scare_flash := 0.0
var exposed := false
var shake := 0.0
var ghost_in_wall := false
var wall_msg_timer := 0.0

# --- Visitors ---
var visitors: Array[Visitor] = []

# --- Remains ---
var remains_pos := Vector2.ZERO
var remains_light: PointLight2D
var destroy_progress := 0.0

# --- Rain ---
var rain_node: Node2D
var flash := 0.0
var flash_cd := 4.0

# --- Effects layer (drawn above the darkness so rings are visible) ---
var fx_node: Node2D

# --- Nodes created in code ---
var hud: CanvasLayer
var ghost_light: PointLight2D
var fear_bar: ProgressBar
var destroy_bar: ProgressBar
var msg: Label
var title_label: Label
var left_label: Label
var snd_scare: AudioStreamPlayer
var snd_flee: AudioStreamPlayer
var snd_ambience: AudioStreamPlayer
var snd_scream: AudioStreamPlayer
var snd_shock: AudioStreamPlayer
var snd_dodge: AudioStreamPlayer

func _ready():
	# Scale the game to any screen size, keeping the 16:9 shape
	var win := get_window()
	win.content_scale_size = Vector2i(1152, 648)
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	# Only real phones/tablets start in touch mode. Desktops switch on at the first real touch.
	if not touch_mode:
		if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
			touch_mode = true

	# Settings (volume, lighting) are loaded once
	if not settings_loaded:
		_load_settings()
		settings_loaded = true
	_apply_volume()

	# Decide the lighting tier: Full (shadows), Medium (cheaper shadows) or Lite (no shadows)
	light_tier = _resolve_tier()
	lite_lighting = light_tier == "lite"
	medium_lighting = light_tier == "medium"
	RenderingServer.canvas_set_shadow_texture_size(SHADOW_TEX_FULL if light_tier == "full" else SHADOW_TEX_LOW)

	_build_map()

	# Level settings
	level_data = levels[current_level]
	notice_range = level_data["notice_range"]
	destroy_time = level_data["destroy_time"]
	panic_amount = level_data["panic"]
	shout_mode = level_data["shout"]
	rain_on = level_data["rain"]
	search_mode = level_data["search"]
	tutorial_mode = level_data.get("tutorial", false)

	# Ghost stats from the abilities you've earned
	_compute_stats()

	# Darkness
	var dark := CanvasModulate.new()
	dark.color = Color(0.1, 0.1, 0.18)
	add_child(dark)

	# Walls block light (furniture does not). Skipped in Lite lighting (no shadows).
	if not lite_lighting:
		for r in walls:
			var occ := LightOccluder2D.new()
			var poly := OccluderPolygon2D.new()
			poly.polygon = PackedVector2Array([
				r.position,
				Vector2(r.end.x, r.position.y),
				r.end,
				Vector2(r.position.x, r.end.y)])
			occ.occluder = poly
			add_child(occ)

	ghost_light = _make_light(Color(0.6, 0.8, 1.0), 90.0, 1.3, false)

	# Remains: hidden in a random room (not the entrance hall), never inside furniture
	remain_rooms = []
	for c in room_centers:
		if c.distance_to(Vector2(580, 491)) > 10.0:
			remain_rooms.append(c)
	remains_pos = _pick_remains_spot(Vector2.ZERO, 0.0)
	# The remains' glow casts shadows only in Full lighting on non-touch devices
	remains_light = _make_light(Color(0.7, 0.3, 1.0), 50.0, 0.9, light_tier == "full" and not touch_mode)
	remains_light.position = remains_pos

	# Rain (on its own layer, so the darkness doesn't dim it)
	if rain_on:
		var rain_layer := CanvasLayer.new()
		add_child(rain_layer)
		rain_node = Node2D.new()
		rain_layer.add_child(rain_node)
		rain_node.draw.connect(_draw_rain)

	# Effects layer for rings and flashes (above the darkness, below the HUD)
	var fx_layer := CanvasLayer.new()
	add_child(fx_layer)
	fx_node = Node2D.new()
	fx_layer.add_child(fx_node)
	fx_node.draw.connect(_draw_fx)

	_build_hud()

	# Touch controls layer (joystick and buttons)
	var touch_layer := CanvasLayer.new()
	touch_layer.layer = 5
	add_child(touch_layer)
	touch_node = Node2D.new()
	touch_layer.add_child(touch_node)
	touch_node.draw.connect(_draw_touch)

	_build_rotate_notice()
	_spawn_visitors()
	_update_abil_label()
	hint_label.visible = not touch_mode

	# Sounds (optional: only play if the files exist in res://sfx/)
	snd_scare = _load_sound("scare")
	snd_flee = _load_sound("flee")
	snd_ambience = _load_sound("ambience")
	snd_scream = _load_sound("scream")
	snd_shock = _load_sound("shockwave")
	snd_dodge = _load_sound("dodge")
	snd_ambience.finished.connect(func(): snd_ambience.play())
	_play(snd_ambience)

	# Main menu (only when the game is first opened, or when you open the menu)
	menu_active = menu_shown
	if menu_active:
		_build_menu()

	# Tutorial: skip the title card; the intro pop-up appears once the game starts
	if tutorial_mode:
		title_timer = 0.0
		if not menu_active:
			_tut("welcome")

func _compute_stats():
	max_fear = BASE_MAX_FEAR * (1.25 if owned.has("energy") else 1.0)
	scare_cost = BASE_SCARE_COST * (0.9 if owned.has("cheap_scare") else 1.0)
	wall_cost = BASE_WALL_COST * (0.75 if owned.has("cheap_wall") else 1.0)
	fear_energy = max_fear

# How fast your energy refills right now (changes when you use abilities)
func _current_regen() -> float:
	var r: float = BASE_REGEN
	if owned.has("relocate"):
		r *= RELOCATE_REGEN_MULT
	if scream_used:
		r *= SCREAM_REGEN_MULT
	if scream_used and relocate_used:
		r = BASE_REGEN * COMBO_REGEN_MULT   # both used this level: 40% slower
	return r

# Picks the keyboard text or the touch text
func _k(desktop: String, touch: String) -> String:
	return touch if touch_mode else desktop

# Fills in the {PLACEHOLDERS} in tutorial text
func _t(s: String) -> String:
	if touch_mode:
		return s.replace("{MOVE}", "Drag your thumb on the LEFT side of the screen to move (a joystick appears).") \
			.replace("{SCARE_CAP}", "Tap the SCARE button") \
			.replace("{SCARE}", "tap the SCARE button") \
			.replace("{NEXT}", "TAP anywhere: continue   |   SKIP button: skip")
	return s.replace("{MOVE}", "Move with the ARROW KEYS.") \
		.replace("{SCARE_CAP}", "Press SPACE") \
		.replace("{SCARE}", "press SPACE") \
		.replace("{NEXT}", "ENTER: continue   ESC: skip")

# Called the first time a touch is detected
func _enable_touch():
	touch_mode = true
	hint_label.visible = false
	_update_abil_label()

# ---------------------------------------------------------------
# LIGHTING QUALITY (Auto / Full / Medium / Lite)
#   Full   = wall shadows on the flashlights (best looking)
#   Medium = wall shadows, but with a much smaller shadow texture (looks the same, far cheaper)
#   Lite   = no shadows at all (works on the weakest phones)
# ---------------------------------------------------------------
func _resolve_tier() -> String:
	device_mem = 0.0
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("navigator.deviceMemory || 0", true)
		if r != null:
			device_mem = float(r)
	match light_quality:
		1:
			return "full"
		2:
			return "lite"
		3:
			return "medium"
	# Auto: low-memory devices use the cheaper tier
	if device_mem > 0.0 and device_mem <= LOWMEM_GB:
		return AUTO_LOWMEM_TIER
	return "full"

func _light_info_text() -> String:
	var names := {"full": "Full", "medium": "Medium", "lite": "Lite"}
	var why := "chosen by you"
	if light_quality == 0:
		why = "auto"
		if device_mem > 0.0:
			why += ", about %d GB device" % int(device_mem)
	var gpu: String = RenderingServer.get_video_adapter_name()
	return "Now using: %s lighting (%s)\nGPU: %s\nIf the flashlights don't show, try Medium, then Lite." % [names[light_tier], why, gpu]

# ---------------------------------------------------------------
# SETTINGS (sound volume, lighting)
# ---------------------------------------------------------------
func _apply_volume():
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))

func _load_settings():
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		master_volume = float(cf.get_value("audio", "volume", 1.0))
		light_quality = int(cf.get_value("video", "lighting", 0))
		if light_quality < 0 or light_quality > 3:
			light_quality = 0

func _save_settings():
	var cf := ConfigFile.new()
	cf.set_value("audio", "volume", master_volume)
	cf.set_value("video", "lighting", light_quality)
	cf.save("user://settings.cfg")

# ---------------------------------------------------------------
# MAIN MENU
# ---------------------------------------------------------------
func _menu_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 54)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(callback)
	return b

func _build_menu():
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "HAUNT CONTROL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.3, 0.6))
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "You are the ghost. Scare them all out of your house."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.modulate = Color(1, 1, 1, 0.7)
	col.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)

	# --- Main buttons ---
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 12)
	main_box.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(main_box)
	start_btn = _menu_button("Start Game", _on_start)
	main_box.add_child(start_btn)
	main_box.add_child(_menu_button("Settings", _on_settings))
	main_box.add_child(_menu_button("Quit Game", _on_quit))

	# --- Settings panel (hidden until Settings is pressed) ---
	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 18)
	settings_box.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_box.visible = false
	col.add_child(settings_box)

	var set_title := Label.new()
	set_title.text = "SETTINGS"
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_title.add_theme_font_size_override("font_size", 36)
	settings_box.add_child(set_title)

	# Sound slider
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_box.add_child(row)
	var snd_lbl := Label.new()
	snd_lbl.text = "Sound"
	snd_lbl.add_theme_font_size_override("font_size", 22)
	row.add_child(snd_lbl)
	vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.step = 1.0
	vol_slider.value = master_volume * 100.0
	vol_slider.custom_minimum_size = Vector2(320, 40)
	vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(vol_slider)
	vol_label = Label.new()
	vol_label.text = "%d%%" % int(round(master_volume * 100.0))
	vol_label.custom_minimum_size = Vector2(60, 0)
	vol_label.add_theme_font_size_override("font_size", 22)
	row.add_child(vol_label)
	vol_slider.value_changed.connect(_on_volume_changed)
	vol_slider.drag_ended.connect(func(_changed: bool): _play(snd_scare))

	# Lighting option (Auto / Full / Medium / Lite)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 16)
	lrow.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_box.add_child(lrow)
	var light_lbl := Label.new()
	light_lbl.text = "Lighting"
	light_lbl.add_theme_font_size_override("font_size", 22)
	lrow.add_child(light_lbl)
	light_opt = OptionButton.new()
	light_opt.add_item("Auto", 0)
	light_opt.add_item("Full (best)", 1)
	light_opt.add_item("Medium (cheaper)", 3)
	light_opt.add_item("Lite (no shadows)", 2)
	light_opt.select(light_opt.get_item_index(light_quality))
	light_opt.custom_minimum_size = Vector2(280, 44)
	light_opt.add_theme_font_size_override("font_size", 20)
	light_opt.get_popup().add_theme_font_size_override("font_size", 20)
	light_opt.item_selected.connect(_on_light_changed)
	lrow.add_child(light_opt)

	light_note = Label.new()
	light_note.text = _light_info_text()
	light_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	light_note.add_theme_font_size_override("font_size", 16)
	light_note.modulate = Color(1, 1, 1, 0.75)
	settings_box.add_child(light_note)

	settings_box.add_child(_menu_button("Back", _on_back))

	# Message line (used by the Quit button in a browser)
	menu_note = Label.new()
	menu_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_note.add_theme_font_size_override("font_size", 18)
	menu_note.modulate = Color(1, 1, 1, 0.8)
	col.add_child(menu_note)

	start_btn.grab_focus()

func _on_start():
	menu_active = false
	menu_shown = false
	# Phones: try to go fullscreen (allowed because the player just tapped)
	if touch_mode and OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# A lighting change needs the level to be rebuilt first
	if quality_changed:
		quality_changed = false
		get_tree().reload_current_scene()
		return
	menu_layer.visible = false
	if tutorial_mode:
		_tut("welcome")

func _on_settings():
	main_box.visible = false
	settings_box.visible = true
	vol_slider.grab_focus()

func _on_back():
	# A lighting change needs the level to be rebuilt (the menu comes back by itself)
	if quality_changed:
		quality_changed = false
		get_tree().reload_current_scene()
		return
	settings_box.visible = false
	main_box.visible = true
	start_btn.grab_focus()

func _on_quit():
	if OS.has_feature("web"):
		menu_note.text = "Thanks for playing! You can close this browser tab now."
	else:
		get_tree().quit()

func _on_volume_changed(v: float):
	master_volume = v / 100.0
	vol_label.text = "%d%%" % int(round(v))
	_apply_volume()
	_save_settings()

func _on_light_changed(index: int):
	light_quality = light_opt.get_item_id(index)
	quality_changed = true
	_save_settings()
	light_note.text = "Lighting changes apply when you press Back (or Start Game)."

# ---------------------------------------------------------------
# "ROTATE YOUR DEVICE" NOTICE (phones held upright)
# ---------------------------------------------------------------
func _build_rotate_notice():
	rotate_layer = CanvasLayer.new()
	rotate_layer.layer = 30
	add_child(rotate_layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_layer.add_child(bg)
	var lbl := Label.new()
	lbl.text = "Please rotate your device\nto landscape mode"
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
	rotate_layer.add_child(lbl)
	rotate_layer.visible = false

# ---------------------------------------------------------------
# HUD
# ---------------------------------------------------------------
func _build_hud():
	var s := get_viewport_rect().size
	hud = CanvasLayer.new()
	add_child(hud)

	var fear_label := Label.new()
	fear_label.text = "FEAR ENERGY  (white mark = enough to cross a wall)"
	fear_label.position = Vector2(230, 14)
	hud.add_child(fear_label)
	fear_bar = ProgressBar.new()
	fear_bar.position = Vector2(20, 20)
	fear_bar.size = Vector2(200, 16)
	fear_bar.show_percentage = false
	fear_bar.max_value = max_fear
	hud.add_child(fear_bar)

	# Tick mark at the wall-crossing cost
	var tick := ColorRect.new()
	tick.color = Color(1, 1, 1, 0.9)
	tick.position = Vector2(20.0 + 200.0 * wall_cost / max_fear - 1.0, 17)
	tick.size = Vector2(2, 22)
	hud.add_child(tick)

	var destroy_label := Label.new()
	destroy_label.text = "YOUR REMAINS BEING DESTROYED"
	destroy_label.position = Vector2(230, 44)
	hud.add_child(destroy_label)
	destroy_bar = ProgressBar.new()
	destroy_bar.position = Vector2(20, 50)
	destroy_bar.size = Vector2(200, 16)
	destroy_bar.show_percentage = false
	destroy_bar.max_value = 100.0
	destroy_bar.modulate = Color(1.0, 0.3, 0.3)
	hud.add_child(destroy_bar)

	msg = Label.new()
	msg.position = Vector2(20, 78)
	msg.add_theme_font_size_override("font_size", 24)
	hud.add_child(msg)

	# Level info (top right)
	var lvl_label := Label.new()
	var t: String = level_data["title"]
	lvl_label.text = t
	lvl_label.position = Vector2(760, 14)
	hud.add_child(lvl_label)
	left_label = Label.new()
	left_label.position = Vector2(760, 40)
	hud.add_child(left_label)
	hint_label = Label.new()
	hint_label.text = "Arrows move | Space scare | E scream | Q soul shift\nShift/X dodge (priest level) | R restart | M menu\nEnter next level | 1-4 jump to level | 0 reset progress"
	hint_label.position = Vector2(760, 64)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.modulate = Color(1, 1, 1, 0.6)
	hud.add_child(hint_label)

	# Abilities you own (top right, under the hints)
	abil_label = Label.new()
	abil_label.position = Vector2(760, 118)
	abil_label.add_theme_font_size_override("font_size", 14)
	abil_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
	hud.add_child(abil_label)

	# Big level title card (fades out, wraps on small screens)
	title_label = Label.new()
	var intro: String = level_data["intro"]
	title_label.text = t + "\n" + intro
	title_label.position = Vector2(40, 290)
	title_label.size = Vector2(s.x - 80.0, 100)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	title_label.add_theme_constant_override("outline_size", 8)
	hud.add_child(title_label)

	# Tutorial tip line (does NOT pause the game)
	tip_label = Label.new()
	tip_label.position = Vector2(0, 118)
	tip_label.size = Vector2(s.x, 30)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.add_theme_font_size_override("font_size", 22)
	tip_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	tip_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tip_label.add_theme_constant_override("outline_size", 8)
	tip_label.visible = false
	hud.add_child(tip_label)

	# Tutorial intro pop-up box (hidden until needed)
	tut_label = Label.new()
	tut_label.custom_minimum_size = Vector2(640, 0)
	tut_label.position = Vector2((s.x - 640.0) / 2.0, 200)
	tut_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_label.add_theme_font_size_override("font_size", 20)
	tut_label.add_theme_stylebox_override("normal", _panel_style(Color(0.6, 0.8, 1.0)))
	tut_label.visible = false
	hud.add_child(tut_label)

	# Reward panel (shown after a level is cleared; has tappable buttons)
	reward_panel = PanelContainer.new()
	reward_panel.custom_minimum_size = Vector2(860, 0)
	reward_panel.position = Vector2((s.x - 860.0) / 2.0, 70)
	reward_panel.add_theme_stylebox_override("panel", _panel_style(Color(1.0, 0.85, 0.4)))
	reward_panel.visible = false
	reward_box = VBoxContainer.new()
	reward_box.add_theme_constant_override("separation", 10)
	reward_panel.add_child(reward_box)
	hud.add_child(reward_panel)

func _panel_style(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.12, 0.95)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	return sb

func _spawn_visitors():
	var vlist: Array = level_data["visitors"]
	var n: int = vlist.size()
	for i in n:
		var vd: Dictionary = vlist[i]
		var v := Visitor.new()
		v.data = vd
		v.vname = vd["name"]
		v.courage = vd["courage"]
		v.max_courage = v.courage
		v.speed = vd["speed"]
		v.delay = vd["delay"]
		v.color = vd["color"]
		v.chaser = vd.get("chaser", false)
		if v.chaser:
			v.wave_cd = 2.0
			has_chaser = true
		var spread: float = (i - (n - 1) / 2.0)
		v.pos = START_POS + Vector2(spread * 14.0, 0)
		v.entry_target = ENTRY_TARGET + Vector2(spread * 36.0, 0)
		v.chat_cd = randf_range(3.0, 6.0) + i * 2.0

		# Flashlight (wall shadows in Full and Medium lighting, none in Lite)
		v.light = _make_light(Color(1.0, 0.9, 0.6), FLASH_RADIUS + 30.0, 1.4, not lite_lighting)
		v.light.visible = false

		# Speech bubble (in the HUD layer so it stays readable in the dark)
		var bl := Label.new()
		bl.add_theme_font_size_override("font_size", 15)
		bl.add_theme_color_override("font_color", Color(0.05, 0.05, 0.08))
		var sb := StyleBoxFlat.new()
		sb.bg_color = v.color.lightened(0.6)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		bl.add_theme_stylebox_override("normal", sb)
		bl.visible = false
		hud.add_child(bl)
		v.bubble = bl

		visitors.append(v)

# ---------------------------------------------------------------
# REMAINS PLACEMENT
# ---------------------------------------------------------------
# Picks a random spot in a room (never inside furniture).
# Prefers spots at least min_dist away from from_pos; falls back to the farthest found.
func _pick_remains_spot(from_pos: Vector2, min_dist: float) -> Vector2:
	var best := Vector2.ZERO
	var best_d := -1.0
	for i in 200:
		var rc: Vector2 = remain_rooms[randi() % remain_rooms.size()]
		var p := rc + Vector2(randf_range(-80, 80), randf_range(-70, 70))
		if _inside_solid(p, 40.0):
			continue
		var d := p.distance_to(from_pos)
		if d >= min_dist:
			return p
		if d > best_d:
			best = p
			best_d = d
	if best_d < 0.0:
		var fb: Vector2 = remain_rooms[0]
		return fb
	return best

# ---------------------------------------------------------------
# ABILITIES: scream (E), soul shift (Q), dodge (Shift / X)
# ---------------------------------------------------------------
func _info(text: String):
	info_text = text
	info_timer = 3.0

func _say_text(v: Visitor, text: String):
	v.say_text = text
	v.say_timer = 2.8 + text.length() * 0.03

func _update_abil_label():
	if owned.is_empty() and not has_chaser:
		abil_label.text = "ABILITIES: none yet"
		return
	var lines := PackedStringArray()
	lines.append("ABILITIES")
	for a in owned:
		var info: Dictionary = ability_info[a]
		var nm: String = info["name"]
		if a == "scream":
			lines.append(_k("[E] ", "") + nm + ": " + ("used" if scream_used else "READY"))
		elif a == "relocate":
			lines.append(_k("[Q] ", "") + nm + ": " + ("used" if relocate_used else "READY"))
		else:
			lines.append(nm + " (passive)")
	if has_chaser:
		lines.append(_k("[Shift] ", "") + "Dodge: " + ("READY" if dodge_cd <= 0.0 else "recharging"))
	var pct: int = int(round((1.0 - _current_regen() / BASE_REGEN) * 100.0))
	if pct > 0:
		lines.append("Energy refill: %d%% slower" % pct)
	abil_label.text = "\n".join(lines)

func _try_scream():
	if menu_active or tut_active or game_state != "play" or reward_active:
		return
	if not owned.has("scream"):
		return
	if scream_used:
		_info("You already used your scream this level!")
		return
	var targets: Array = []
	for v in visitors:
		if _active(v):
			targets.append(v)
	if targets.is_empty():
		_info("No one is inside yet. Wait for the visitors to enter!")
		return
	scream_used = true
	scream_t = 0.0
	scream_origin = ghost_pos
	shake = 20.0
	_play(snd_scream)
	for v in targets:
		v.courage -= v.max_courage * SCREAM_COURAGE_PCT
		v.speed *= SCREAM_SLOW
		_say_text(v, scream_lines[randi() % scream_lines.size()])
	if relocate_used:
		_info("Scream + Soul Shift together: your energy now refills 40% slower this level!")
	else:
		_info("AAAAAH! They're shaken, but your energy now refills 25% slower this level.")
	_update_abil_label()

func _try_relocate():
	if menu_active or tut_active or game_state != "play" or reward_active:
		return
	if not owned.has("relocate"):
		return
	if relocate_used:
		_info("You already moved your remains this level!")
		return
	relocate_used = true
	var old_pos := remains_pos
	remains_pos = _pick_remains_spot(old_pos, RELOCATE_MIN_DIST)
	remains_light.position = remains_pos
	# Visitors lose track of the remains, and the destruction progress resets
	destroy_progress = 0.0
	for v in visitors:
		v.noticed = false
		v.destroy_said = false
		v.at_remains = false
		v.need_repath = true
	shake = 12.0
	if scream_used:
		_info("Soul Shift + Scream together: your energy now refills 40% slower this level!")
	else:
		_info("Your remains vanished and reappeared far away!")
	_update_abil_label()

func _try_dodge():
	if menu_active or tut_active or game_state != "play" or reward_active:
		return
	if not has_chaser:
		return
	if dodge_cd > 0.0:
		return
	dodge_t = DODGE_TIME
	dodge_cd = DODGE_COOLDOWN
	_play(snd_dodge)
	_update_abil_label()

# ---------------------------------------------------------------
# REWARDS (tap/click a button, or press 1-3)
# ---------------------------------------------------------------
func _clear_reward_box():
	for c in reward_box.get_children():
		reward_box.remove_child(c)
		c.queue_free()

func _reward_label(text: String, size_px: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(800, 0)
	return l

# Called when a level is won. Sets reward_active if a reward is offered.
func _begin_reward():
	if current_level >= levels.size() - 1 or rewarded_levels.has(current_level):
		return
	var new_a: String = new_ability_for_level.get(current_level, "")
	if new_a != "" and not offered.has(new_a) and not owned.has(new_a):
		offered.append(new_a)
	if offered.is_empty():
		return
	reward_choices = offered.duplicate()
	reward_active = true

	_clear_reward_box()
	reward_box.add_child(_reward_label("LEVEL CLEARED!   " + _k("CHOOSE ONE REWARD (click it, or press 1-3)", "CHOOSE ONE REWARD (tap it)"), 22))
	for i in reward_choices.size():
		var a: String = reward_choices[i]
		var info: Dictionary = ability_info[a]
		var b := Button.new()
		b.text = "[%d]  %s\n%s" % [i + 1, info["name"], info["desc"]]
		b.custom_minimum_size = Vector2(0, 84)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_pick_reward.bind(i))
		reward_box.add_child(b)
	if current_level >= levels.size() - 2:
		reward_box.add_child(_reward_label("This is your last reward.", 16))
	else:
		reward_box.add_child(_reward_label("The abilities you don't pick will be offered again after the next level.", 16))
	reward_panel.visible = true
	reward_panel.reset_size()

func _pick_reward(i: int):
	if not reward_active:
		return
	var a: String = reward_choices[i]
	var info: Dictionary = ability_info[a]
	owned.append(a)
	offered.erase(a)
	rewarded_levels.append(current_level)
	reward_active = false

	_clear_reward_box()
	reward_box.add_child(_reward_label("REWARD GAINED!\n\n%s\n%s" % [info["name"], info["desc"]], 20))
	var cont := Button.new()
	cont.text = "Continue to the next level"
	cont.custom_minimum_size = Vector2(0, 60)
	cont.focus_mode = Control.FOCUS_NONE
	cont.add_theme_font_size_override("font_size", 20)
	cont.pressed.connect(_next_level)
	reward_box.add_child(cont)
	reward_panel.reset_size()
	msg.text = "Reward chosen!  " + _k("Press ENTER or click Continue  (R to replay)", "Tap Continue")
	_update_abil_label()

func _next_level():
	if current_level < levels.size() - 1:
		current_level += 1
	else:
		current_level = 0
	get_tree().reload_current_scene()

# ---------------------------------------------------------------
# TUTORIAL: intro pop-up (pauses) and tips (don't pause)
# ---------------------------------------------------------------
func _tut(key: String):
	if not tutorial_mode or tut_shown.has(key) or tut_active:
		return
	tut_shown[key] = true
	tut_pages = tut_text[key]
	tut_idx = 0
	tut_active = true
	_show_tut_page()

func _show_tut_page():
	var page: String = _t(tut_pages[tut_idx])
	tut_label.text = page + "\n\n[ " + _t("{NEXT}") + " ]   " + str(tut_idx + 1) + " / " + str(tut_pages.size())
	tut_label.size = Vector2(640, 0)
	tut_label.visible = true

func _advance_tut():
	tut_idx += 1
	if tut_idx >= tut_pages.size():
		tut_active = false
		tut_label.visible = false
	else:
		_show_tut_page()

func _skip_tut():
	tut_active = false
	tut_label.visible = false

# Shows a short tip line once (does not pause the game)
func _tip(key: String):
	if not tutorial_mode or tip_shown.has(key):
		return
	tip_shown[key] = true
	tip_label.text = _t(tip_text[key])
	tip_label.visible = true
	tip_timer = 4.0

func _check_tutorial():
	var v: Visitor = visitors[0]
	if v.entered and not v.fleeing and not v.gone \
			and ghost_pos.distance_to(v.pos) < 220.0 \
			and not _line_blocked(ghost_pos, v.pos):
		_tip("near")
	if exposed:
		_tip("light")
	if v.at_remains:
		_tip("destroying")

# ---------------------------------------------------------------
# MAP
# ---------------------------------------------------------------
func _add(x: float, y: float, w: float, h: float, c: Color, kind := "box", solid := true):
	furniture.append({"r": Rect2(x, y, w, h), "c": c, "kind": kind, "solid": solid})
	if solid:
		solids.append(Rect2(x, y, w, h))

func _build_map():
	walls = [
		# Outer walls (front door gap in the bottom wall, x 540-620)
		Rect2(52, 112, 1048, 16),
		Rect2(52, 612, 488, 16),
		Rect2(620, 612, 480, 16),
		Rect2(52, 112, 16, 516),
		Rect2(1084, 112, 16, 516),
		# Vertical wall at x=400 (doors at y 200-280 and 450-530)
		Rect2(392, 128, 16, 72),
		Rect2(392, 280, 16, 170),
		Rect2(392, 530, 16, 82),
		# Vertical wall at x=760 (doors at y 200-280 and 450-530)
		Rect2(752, 128, 16, 72),
		Rect2(752, 280, 16, 170),
		Rect2(752, 530, 16, 82),
		# Horizontal wall at y=370 (doors at x 180-260, 520-600, 880-960)
		Rect2(68, 362, 112, 16),
		Rect2(260, 362, 260, 16),
		Rect2(600, 362, 280, 16),
		Rect2(960, 362, 124, 16),
	]

	# Doorways (drawn as thresholds)
	doors = [
		Rect2(392, 200, 16, 80), Rect2(392, 450, 16, 80),
		Rect2(752, 200, 16, 80), Rect2(752, 450, 16, 80),
		Rect2(180, 362, 80, 16), Rect2(520, 362, 80, 16), Rect2(880, 362, 80, 16),
		Rect2(540, 612, 80, 16),
	]

	room_centers = []
	for cx in [234, 580, 922]:
		for cy in [249, 491]:
			room_centers.append(Vector2(cx, cy))

	# ---- Furniture (kept away from doorways) ----
	furniture = []
	solids = []
	# Bedroom
	_add(100, 270, 120, 50, Color(0.45, 0.3, 0.45), "rug", false)
	_add(84, 144, 130, 120, Color(0.35, 0.45, 0.75), "bed")
	_add(222, 144, 34, 34, Color(0.5, 0.38, 0.28))
	_add(290, 136, 90, 34, Color(0.4, 0.3, 0.22))
	# Living room
	_add(470, 205, 170, 90, Color(0.55, 0.25, 0.3), "rug", false)
	_add(470, 140, 150, 48, Color(0.75, 0.2, 0.2))
	_add(690, 136, 46, 46, Color(0.75, 0.2, 0.2))
	_add(505, 222, 80, 46, Color(0.82, 0.82, 0.85), "round")
	_add(640, 326, 90, 24, Color(0.15, 0.15, 0.18))
	_add(420, 318, 30, 30, Color(0.2, 0.6, 0.25), "round")
	# Kitchen
	_add(780, 136, 220, 34, Color(0.85, 0.85, 0.8))
	_add(1006, 136, 64, 40, Color(0.78, 0.8, 0.85))
	_add(820, 141, 50, 24, Color(0.55, 0.65, 0.75), "box", false)
	_add(930, 141, 60, 24, Color(0.15, 0.15, 0.17), "stove", false)
	_add(900, 232, 100, 64, Color(0.8, 0.2, 0.2))
	_add(876, 248, 20, 32, Color(0.5, 0.35, 0.2), "box", false)
	_add(1004, 248, 20, 32, Color(0.5, 0.35, 0.2), "box", false)
	# Bathroom
	_add(80, 540, 150, 58, Color(0.9, 0.92, 0.95), "tub")
	_add(326, 556, 40, 44, Color(0.92, 0.92, 0.95))
	_add(300, 388, 56, 30, Color(0.92, 0.92, 0.95))
	# Entrance hall
	_add(545, 583, 70, 24, Color(0.5, 0.2, 0.2), "box", false)
	_add(430, 558, 72, 28, Color(0.4, 0.3, 0.22))
	_add(660, 390, 70, 26, Color(0.4, 0.3, 0.22))
	_add(700, 568, 30, 30, Color(0.2, 0.6, 0.25), "round")
	# Study / storage
	_add(980, 392, 92, 46, Color(0.45, 0.3, 0.2))
	_add(1010, 444, 30, 30, Color(0.2, 0.2, 0.25), "round", false)
	_add(790, 578, 150, 26, Color(0.35, 0.25, 0.18))
	_add(1000, 480, 52, 42, Color(0.55, 0.45, 0.3))
	_add(1020, 548, 50, 50, Color(0.3, 0.45, 0.6), "round")

	# Pathfinding grid: cells near walls and solid furniture are blocked
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GRID_W, GRID_H)
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = Vector2(CELL / 2.0, CELL / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var blockers: Array = walls + solids
	for x in GRID_W:
		for y in GRID_H:
			var center := Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0)
			for r in blockers:
				if r.grow(18.0).has_point(center):
					astar.set_point_solid(Vector2i(x, y), true)
					break

func _to_cell(p: Vector2) -> Vector2i:
	return Vector2i(
		clampi(int(floor(p.x / CELL)), 0, GRID_W - 1),
		clampi(int(floor(p.y / CELL)), 0, GRID_H - 1))

func _nearest_free(c: Vector2i) -> Vector2i:
	for r in range(0, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c2 := Vector2i(c.x + dx, c.y + dy)
				if astar.region.has_point(c2) and not astar.is_point_solid(c2):
					return c2
	return c

func _inside_solid(p: Vector2, pad: float) -> bool:
	for r in solids:
		if r.grow(pad).has_point(p):
			return true
	return false

func _hits_wall(p: Vector2) -> bool:
	var blockers: Array = walls + solids
	for r in blockers:
		var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if p.distance_to(closest) < VISITOR_RADIUS:
			return true
	return false

# Ghost-only check: just the walls (furniture is free to pass through)
func _ghost_hits_wall(p: Vector2) -> bool:
	for r in walls:
		var closest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if p.distance_to(closest) < GHOST_RADIUS:
			return true
	return false

func _try_move(v: Visitor, offset: Vector2):
	var nx := v.pos + Vector2(offset.x, 0)
	if not _hits_wall(nx):
		v.pos = nx
	var ny := v.pos + Vector2(0, offset.y)
	if not _hits_wall(ny):
		v.pos = ny

# True if any wall is between points a and b
func _line_blocked(a: Vector2, b: Vector2) -> bool:
	for r in walls:
		if r.has_point(a) or r.has_point(b):
			return true
		var c_tl: Vector2 = r.position
		var c_tr := Vector2(r.end.x, r.position.y)
		var c_bl := Vector2(r.position.x, r.end.y)
		var c_br: Vector2 = r.end
		if Geometry2D.segment_intersects_segment(a, b, c_tl, c_tr) != null: return true
		if Geometry2D.segment_intersects_segment(a, b, c_tr, c_br) != null: return true
		if Geometry2D.segment_intersects_segment(a, b, c_br, c_bl) != null: return true
		if Geometry2D.segment_intersects_segment(a, b, c_bl, c_tl) != null: return true
	return false

# ---------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------
func _make_light(color: Color, radius: float, energy: float, shadows: bool) -> PointLight2D:
	# Lower tiers use a smaller glow image (same look, less memory)
	var tex_size := 256 if light_tier == "full" else 128
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = tex_size
	tex.height = tex_size
	var l := PointLight2D.new()
	l.texture = tex
	l.color = color
	l.energy = energy
	l.texture_scale = radius / (tex_size / 2.0)
	l.shadow_enabled = shadows
	add_child(l)
	return l

func _load_sound(sound_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://sfx/%s.%s" % [sound_name, ext]
		if ResourceLoader.exists(path):
			p.stream = load(path)
			break
	return p

func _play(p: AudioStreamPlayer):
	if p.stream:
		p.play()

func _active(v: Visitor) -> bool:
	return v.started and not v.gone and not v.fleeing and v.courage > 0.0

func _say(v: Visitor, key: String, chance: float = 1.0):
	if randf() > chance:
		return
	var lines: Array = v.data.get(key, [])
	if lines.is_empty():
		return
	var t: String = lines[randi() % lines.size()]
	v.say_text = t
	v.say_timer = 2.8 + t.length() * 0.03

func _goto_level(i: int):
	if i >= 0 and i < levels.size():
		current_level = i
		get_tree().reload_current_scene()

func _reset_progress():
	owned.clear()
	offered = ["energy", "cheap_scare", "cheap_wall"]
	rewarded_levels.clear()
	current_level = 0
	get_tree().reload_current_scene()

# ---------------------------------------------------------------
# TOUCH CONTROLS
# ---------------------------------------------------------------
func _touch_buttons() -> Array:
	var list: Array = []
	list.append({"id": "scare", "pos": Vector2(1030, 520), "r": 74.0, "label": "SCARE"})
	if owned.has("scream"):
		list.append({"id": "scream", "pos": Vector2(880, 585), "r": 46.0, "label": "SCREAM"})
	if owned.has("relocate"):
		list.append({"id": "relocate", "pos": Vector2(1060, 380), "r": 46.0, "label": "SOUL"})
	if has_chaser:
		list.append({"id": "dodge", "pos": Vector2(880, 470), "r": 46.0, "label": "DODGE"})
	list.append({"id": "restart", "pos": Vector2(1048, 34), "r": 26.0, "label": "RESET"})
	list.append({"id": "menu", "pos": Vector2(1110, 34), "r": 26.0, "label": "MENU"})
	return list

func _touch_button_at(p: Vector2) -> String:
	for b in _touch_buttons():
		var bp: Vector2 = b["pos"]
		var br: float = b["r"]
		if p.distance_to(bp) <= br + 10.0:
			return b["id"]
	return ""

func _press_button(id: String):
	match id:
		"scare":
			if game_state == "play" and not tut_active and not reward_active:
				touch_scare_queued = true
		"scream":
			_try_scream()
		"relocate":
			_try_relocate()
		"dodge":
			_try_dodge()
		"restart":
			get_tree().reload_current_scene()
		"menu":
			menu_shown = true
			get_tree().reload_current_scene()

func _handle_touch(st: InputEventScreenTouch):
	if not st.pressed:
		# Finger lifted: stop the joystick if it was this finger
		if st.index == joy_id:
			joy_id = -1
			joy_vec = Vector2.ZERO
		return

	# Tutorial pop-up: tap = next page, SKIP button = skip
	if tut_active:
		if SKIP_RECT.has_point(st.position):
			_skip_tut()
		else:
			_advance_tut()
		return

	# Reward screen uses its own buttons
	if reward_active:
		return

	# On-screen buttons
	var id := _touch_button_at(st.position)
	if id != "":
		_press_button(id)
		return

	# After a win or loss: tap anywhere
	if game_state == "lost" and end_timer > 0.8:
		get_tree().reload_current_scene()
		return
	if game_state == "won" and end_timer > 1.0:
		_next_level()
		return

	# Otherwise: start the floating joystick on the left side of the screen
	if game_state == "play" and st.position.x < 576.0 and joy_id == -1:
		joy_id = st.index
		joy_origin = st.position
		joy_vec = Vector2.ZERO

func _handle_drag(sd: InputEventScreenDrag):
	if sd.index != joy_id:
		return
	var d := sd.position - joy_origin
	joy_vec = (d / JOY_RADIUS).limit_length(1.0)

func _draw_touch():
	if not touch_mode or menu_active:
		return
	var font := ThemeDB.fallback_font

	# Joystick (shows a faint ring when idle)
	if joy_id != -1:
		touch_node.draw_circle(joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.08))
		touch_node.draw_arc(joy_origin, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		touch_node.draw_circle(joy_origin + joy_vec * 55.0, 32.0, Color(1, 1, 1, 0.35))
	else:
		touch_node.draw_arc(JOY_REST, JOY_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.12), 3.0)
		touch_node.draw_circle(JOY_REST, 30.0, Color(1, 1, 1, 0.08))

	# Buttons
	for b in _touch_buttons():
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		var id: String = b["id"]
		var a := 0.30
		if id == "scream" and scream_used:
			a = 0.12
		if id == "relocate" and relocate_used:
			a = 0.12
		if id == "dodge" and dodge_cd > 0.0:
			a = 0.12
		if id == "scare" and (fear_energy < scare_cost or scare_cd > 0.0):
			a = 0.16
		touch_node.draw_circle(p, r, Color(0.5, 0.7, 1.0, a))
		touch_node.draw_arc(p, r, 0, TAU, 48, Color(1, 1, 1, a + 0.25), 3.0)
		if id == "scare" and scare_cd > 0.0:
			var frac := 1.0 - scare_cd / SCARE_COOLDOWN
			touch_node.draw_arc(p, r - 6.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 48, Color(1.0, 1.0, 0.6, 0.8), 5.0)
		if id == "dodge" and dodge_cd > 0.0:
			var dfrac := 1.0 - dodge_cd / DODGE_COOLDOWN
			touch_node.draw_arc(p, r - 5.0, -PI / 2.0, -PI / 2.0 + TAU * dfrac, 48, Color(0.6, 0.9, 1.0, 0.8), 4.0)
		var fs := 22
		if r < 60.0:
			fs = 15
		if r < 40.0:
			fs = 11
		touch_node.draw_string(font, p + Vector2(-r, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, Color(1, 1, 1, minf(1.0, a + 0.55)))

	# SKIP button while the tutorial intro is open
	if tut_active:
		touch_node.draw_rect(SKIP_RECT, Color(0.5, 0.7, 1.0, 0.3))
		touch_node.draw_rect(SKIP_RECT, Color(1, 1, 1, 0.6), false, 3.0)
		touch_node.draw_string(font, SKIP_RECT.position + Vector2(0, 33), "SKIP", HORIZONTAL_ALIGNMENT_CENTER, SKIP_RECT.size.x, 24, Color(1, 1, 1, 0.9))

# ---------------------------------------------------------------
# INPUT
# ---------------------------------------------------------------
func _input(event: InputEvent):
	# Touch events (phones and tablets)
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not touch_mode:
			_enable_touch()
		if menu_active:
			return   # menu buttons work through the emulated mouse
		if event is InputEventScreenTouch:
			_handle_touch(event as InputEventScreenTouch)
		else:
			_handle_drag(event as InputEventScreenDrag)
		return

	# The main menu handles its own keys and mouse
	if menu_active:
		return

	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return

	# While the tutorial intro is open: ENTER = next page, ESC = skip it
	if tut_active:
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER:
			_advance_tut()
			return
		if ke.keycode == KEY_ESCAPE:
			_skip_tut()
			return

	# Reward screen: number keys pick a reward
	if reward_active:
		var idx: int = int(ke.keycode) - int(KEY_1)
		if idx >= 0 and idx < reward_choices.size():
			_pick_reward(idx)
			return

	match ke.keycode:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_M:
			menu_shown = true
			get_tree().reload_current_scene()
		KEY_E:
			_try_scream()
		KEY_Q:
			_try_relocate()
		KEY_SHIFT, KEY_X:
			_try_dodge()
		KEY_0:
			_reset_progress()
		KEY_1:
			_goto_level(0)
		KEY_2:
			_goto_level(1)
		KEY_3:
			_goto_level(2)
		KEY_4:
			_goto_level(3)
		KEY_ENTER, KEY_KP_ENTER:
			if game_state == "won" and end_timer > 1.0 and not reward_active:
				_next_level()

# ---------------------------------------------------------------
# MAIN LOOP
# ---------------------------------------------------------------
func _process(delta: float):
	var size := get_viewport_rect().size

	# Phone held upright: show "rotate your device" and pause
	var ws := DisplayServer.window_get_size()
	var portrait: bool = touch_mode and ws.y > ws.x
	rotate_layer.visible = portrait
	touch_node.queue_redraw()
	if portrait:
		return

	# PAUSED while the main menu is open
	if menu_active:
		return

	# PAUSED only while the tutorial intro is open
	if tut_active:
		return

	fx_node.queue_redraw()

	# Title card fades out
	title_timer = max(0.0, title_timer - delta)
	title_label.modulate.a = clampf(title_timer, 0.0, 1.0)

	_update_rain(delta)

	# Effect timers and info message timer
	if scream_t >= 0.0:
		scream_t += delta
		if scream_t > 0.8:
			scream_t = -1.0
	if wave_t >= 0.0:
		wave_t += delta
		if wave_t > 0.6:
			wave_t = -1.0
	if counter_fx_t >= 0.0:
		counter_fx_t += delta
		if counter_fx_t > 0.6:
			counter_fx_t = -1.0
	shock_flash = max(0.0, shock_flash - delta * 1.5)
	info_timer = max(0.0, info_timer - delta)

	# Game over: wait for restart or next level
	if game_state != "play":
		end_timer += delta
		shake = max(0.0, shake - 40.0 * delta)
		position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
		_update_bubbles(delta)
		queue_redraw()
		return

	# Ghost movement: keyboard, or the touch joystick. Walls cost energy to cross
	var input: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if joy_id != -1 and joy_vec.length() > 0.12:
		input = joy_vec
	var move: Vector2 = input * ghost_speed * delta
	var lo := Vector2(20, 20)
	var hi: Vector2 = size - Vector2(20, 20)
	var new_pos: Vector2 = (ghost_pos + move).clamp(lo, hi)
	var now_in := _ghost_hits_wall(new_pos)

	if now_in and not ghost_in_wall:
		if fear_energy >= wall_cost:
			# Pay once to phase through this wall
			fear_energy -= wall_cost
			ghost_in_wall = true
			ghost_pos = new_pos
			shake = max(shake, 6.0)
		else:
			# Blocked: slide along the wall instead
			wall_msg_timer = 1.5
			var nx: Vector2 = Vector2(ghost_pos.x + move.x, ghost_pos.y).clamp(lo, hi)
			if not _ghost_hits_wall(nx):
				ghost_pos = nx
			var ny: Vector2 = Vector2(ghost_pos.x, ghost_pos.y + move.y).clamp(lo, hi)
			if not _ghost_hits_wall(ny):
				ghost_pos = ny
	else:
		ghost_pos = new_pos
		ghost_in_wall = now_in

	wall_msg_timer = max(0.0, wall_msg_timer - delta)

	# Energy refill (slower after using scream / soul shift)
	fear_energy = min(max_fear, fear_energy + _current_regen() * delta)
	scare_cd = max(0.0, scare_cd - delta)

	# Dodge and counter timers
	var prev_dodge_cd := dodge_cd
	dodge_t = max(0.0, dodge_t - delta)
	dodge_cd = max(0.0, dodge_cd - delta)
	counter_t = max(0.0, counter_t - delta)
	if prev_dodge_cd > 0.0 and dodge_cd <= 0.0:
		_update_abil_label()

	# THREAT: any visitor's flashlight drains you, but walls block it
	exposed = false
	for v in visitors:
		if _active(v) and ghost_pos.distance_to(v.pos) < FLASH_RADIUS \
				and not _line_blocked(ghost_pos, v.pos):
			exposed = true
			break
	if exposed:
		fear_energy = max(0.0, fear_energy - 22.0 * delta)
		shake = max(shake, 2.0)

	# Scare (Space, or the SCARE button): hits EVERY visitor in range with a clear line
	var want_scare: bool = Input.is_action_just_pressed("ui_accept") or touch_scare_queued
	touch_scare_queued = false
	var landed_hit := false
	if want_scare and fear_energy >= scare_cost and scare_cd <= 0.0:
		fear_energy -= scare_cost
		scare_cd = SCARE_COOLDOWN
		scare_flash = 0.3
		shake = 10.0
		_play(snd_scare)
		for v in visitors:
			if _active(v) and ghost_pos.distance_to(v.pos) < SCARE_RANGE \
					and not _line_blocked(ghost_pos, v.pos):
				var is_counter: bool = v.chaser and counter_t > 0.0
				if is_counter:
					# COUNTER HIT: scare right after a perfect dodge
					v.courage -= v.max_courage * COUNTER_DAMAGE_PCT
					counter_t = 0.0
					counter_fx_t = 0.0
					counter_fx_pos = v.pos
					shock_flash = 0.35
					shake = 22.0
					_info("COUNTER HIT! The priest lost 35% of his courage!")
					_say(v, "hurt")
				else:
					v.courage -= SCARE_DAMAGE
					shake = 16.0
					_say(v, "scared")
				v.stun = STUN_TIME
				landed_hit = true
				var push := (v.pos - ghost_pos).normalized()
				for i in 5:
					_try_move(v, push * 9.0)

	scare_flash = max(0.0, scare_flash - delta)
	shake = max(0.0, shake - 40.0 * delta)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake

	# Visitors think and move
	for v in visitors:
		_update_visitor(v, delta)

	# Destroying the remains (more destroyers = faster)
	var destroyers := 0
	for v in visitors:
		if v.at_remains and _active(v):
			destroyers += 1
	if destroyers > 0:
		destroy_progress += (100.0 / destroy_time) * (1.0 + 0.5 * (destroyers - 1)) * delta
		shake = max(shake, 3.0)
	else:
		destroy_progress = max(0.0, destroy_progress - 5.0 * delta)

	if game_state == "play" and destroy_progress >= 100.0:
		game_state = "lost"
		end_timer = 0.0
		shake = 25.0
		joy_id = -1
		joy_vec = Vector2.ZERO
		msg.text = "YOUR REMAINS WERE DESTROYED - you lose  (" + _k("press R to restart", "tap to restart") + ")"

	# Lights and HUD follow the action
	ghost_light.position = ghost_pos
	ghost_light.energy = 1.3 + scare_flash * 8.0
	ghost_light.color = Color(1.0, 0.3, 0.3) if exposed else Color(0.6, 0.8, 1.0)
	var left := 0
	for v in visitors:
		v.light.position = v.pos
		v.light.visible = v.started and not v.gone
		if v.fleeing:
			v.light.energy = randf_range(0.2, 1.4)
		if not v.gone:
			left += 1
	left_label.text = "VISITORS LEFT: %d" % left
	fear_bar.value = fear_energy
	destroy_bar.value = destroy_progress

	if game_state == "play":
		var any_windup := false
		var any_chase := false
		for v in visitors:
			if v.chase_state == "windup":
				any_windup = true
			elif v.chase_state == "chase":
				any_chase = true
		if counter_t > 0.0:
			msg.text = "COUNTER WINDOW! SCARE HIM NOW!"
		elif info_timer > 0.0:
			msg.text = info_text
		elif any_windup:
			msg.text = "HOLY SHOCKWAVE! " + _k("Press SHIFT to DODGE", "Tap DODGE") + ", leave the ring, or scare him!"
		elif any_chase:
			msg.text = "The priest sees you! RUN or scare him!"
		elif wall_msg_timer > 0.0:
			msg.text = "Need %d energy to pass through a wall!" % int(ceil(wall_cost))
		elif exposed:
			msg.text = "You're in his light!"
		else:
			var any_noticed := false
			for v in visitors:
				if _active(v) and v.noticed:
					any_noticed = true
			msg.text = "They found your remains! Scare them!" if any_noticed else ""

	# Tutorial tips (these do NOT pause the game)
	if tutorial_mode and game_state == "play":
		if landed_hit:
			_tip("hit")
		_check_tutorial()
		tip_timer = max(0.0, tip_timer - delta)
		if tip_timer <= 0.0:
			tip_label.visible = false

	_update_bubbles(delta)
	queue_redraw()

# ---------------------------------------------------------------
# SPEECH BUBBLES
# ---------------------------------------------------------------
func _update_bubbles(delta: float):
	var s := get_viewport_rect().size
	for v in visitors:
		v.say_timer = max(0.0, v.say_timer - delta)
		var visible_now: bool = v.say_timer > 0.0 and v.started and not v.gone
		if visible_now:
			if v.shown_text != v.say_text:
				v.shown_text = v.say_text
				v.bubble.text = v.say_text
				v.bubble.size = Vector2.ZERO
			var bs := v.bubble.size
			var bx := clampf(v.pos.x - bs.x / 2.0, 4.0, s.x - bs.x - 4.0)
			var by := v.pos.y - 74.0 - bs.y
			if by < 110.0:
				by = v.pos.y + 28.0   # near the top: show below him instead
			v.bubble.position = Vector2(bx, by)
		v.bubble.visible = visible_now

# ---------------------------------------------------------------
# RAIN (level 3)
# ---------------------------------------------------------------
func _update_rain(delta: float):
	if not rain_on:
		return
	flash_cd -= delta
	if flash_cd <= 0.0:
		flash = 0.22
		flash_cd = randf_range(6.0, 12.0)
	flash = max(0.0, flash - delta * 1.2)
	rain_node.queue_redraw()

func _draw_rain():
	var s := get_viewport_rect().size
	var t := Time.get_ticks_msec() / 1000.0
	# Fewer raindrops on the lighter lighting tiers
	var drops := 140 if light_tier == "full" else 70
	for i in drops:
		var x := fmod(i * 97.3 + t * 60.0, s.x)
		var y := fmod(i * 53.7 + t * 650.0 + float(i % 7) * 40.0, s.y)
		rain_node.draw_line(Vector2(x, y), Vector2(x - 5.0, y + 16.0), Color(0.65, 0.75, 1.0, 0.28), 1.5)
	if flash > 0.0:
		rain_node.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, flash))

# ---------------------------------------------------------------
# EFFECTS LAYER: flashlight ring (Lite), scream, priest shockwave, dodge, counter
# ---------------------------------------------------------------
func _draw_fx():
	var s := get_viewport_rect().size

	# Lite lighting: always-visible flashlight range ring (works even if lights fail)
	if lite_lighting:
		for v in visitors:
			if _active(v):
				fx_node.draw_circle(v.pos, FLASH_RADIUS, Color(1.0, 0.9, 0.6, 0.07))
				fx_node.draw_arc(v.pos, FLASH_RADIUS, 0, TAU, 48, Color(1.0, 0.9, 0.6, 0.35), 2.0)

	# Ghost scream shockwave
	if scream_t >= 0.0:
		var fade := 1.0 - scream_t / 0.8
		fx_node.draw_arc(scream_origin, scream_t * 1300.0, 0, TAU, 96, Color(1, 1, 1, fade), 8.0)
		fx_node.draw_arc(scream_origin, scream_t * 900.0, 0, TAU, 96, Color(0.7, 0.9, 1.0, fade * 0.7), 5.0)

	# Priest charging: danger ring plus a growing inner ring
	for v in visitors:
		if v.chase_state == "windup" and not v.gone:
			var prog := 1.0 - v.windup_t / CHASER_WINDUP
			fx_node.draw_circle(v.pos, CHASER_WAVE_RADIUS * prog, Color(1.0, 0.9, 0.5, 0.10))
			fx_node.draw_arc(v.pos, CHASER_WAVE_RADIUS, 0, TAU, 96, Color(1.0, 0.85, 0.3, 0.6), 4.0)
			fx_node.draw_arc(v.pos, CHASER_WAVE_RADIUS * prog, 0, TAU, 96, Color(1.0, 0.95, 0.7, 0.9), 6.0)

	# Priest shockwave expanding after it fires
	if wave_t >= 0.0:
		var f := wave_t / 0.6
		fx_node.draw_arc(wave_origin, CHASER_WAVE_RADIUS * (0.4 + f * 1.1), 0, TAU, 96, Color(1.0, 0.95, 0.7, 1.0 - f), 10.0)

	# Dodge: a blue ring around the ghost while phased out
	if dodge_t > 0.0:
		var dr := 28.0 + (DODGE_TIME - dodge_t) * 40.0
		fx_node.draw_arc(ghost_pos, dr, 0, TAU, 48, Color(0.6, 0.9, 1.0, 0.85), 4.0)

	# Counter window: a gold timer arc around the priest
	if counter_t > 0.0:
		for v in visitors:
			if v.chaser and not v.gone:
				var cf := counter_t / COUNTER_WINDOW
				fx_node.draw_arc(v.pos, 46.0, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.25), 3.0)
				fx_node.draw_arc(v.pos, 46.0, -PI / 2.0, -PI / 2.0 + TAU * cf, 48, Color(1.0, 0.85, 0.3, 0.95), 7.0)

	# Counter hit burst
	if counter_fx_t >= 0.0:
		var cb := counter_fx_t / 0.6
		fx_node.draw_arc(counter_fx_pos, 30.0 + cb * 170.0, 0, TAU, 64, Color(1.0, 0.85, 0.3, 1.0 - cb), 9.0)

	# Screen flash when a shockwave or counter goes off
	if shock_flash > 0.0:
		fx_node.draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.95, 0.7, shock_flash * 0.6))

# ---------------------------------------------------------------
# VISITOR BRAIN
# ---------------------------------------------------------------
func _set_path(v: Visitor, target: Vector2):
	var a := _nearest_free(_to_cell(v.pos))
	var b := _nearest_free(_to_cell(target))
	v.path = astar.get_point_path(a, b)
	v.path_i = 0

# Moves along the current path. Returns true when the path is finished.
func _follow_path(v: Visitor, speed: float, delta: float) -> bool:
	if v.path_i >= v.path.size():
		return true
	var target: Vector2 = v.path[v.path_i]
	var to: Vector2 = target - v.pos
	var step: float = speed * delta
	if to.length() <= step:
		v.pos = target
		v.path_i += 1
	else:
		v.pos += to.normalized() * step
	return v.path_i >= v.path.size()

func _pick_wander_target(v: Visitor):
	var c: Vector2
	if search_mode:
		# Searching: visits every room, each visitor in a different order
		if v.room_queue.is_empty():
			v.room_queue = room_centers.duplicate()
			v.room_queue.shuffle()
		c = v.room_queue.pop_back()
	else:
		c = room_centers[randi() % room_centers.size()]
	_set_path(v, c + Vector2(randf_range(-70, 70), randf_range(-50, 50)))

func _notice(v: Visitor, from_shout: bool = false):
	v.noticed = true
	v.need_repath = true
	_say(v, "notice")
	# Kids call each other over
	if shout_mode and not from_shout:
		for o in visitors:
			if o != v and _active(o) and not o.noticed:
				_notice(o, true)

func _check_win():
	for v in visitors:
		if not v.gone:
			return
	game_state = "won"
	end_timer = 0.0
	joy_id = -1
	joy_vec = Vector2.ZERO
	_begin_reward()
	if reward_active:
		msg.text = "LEVEL CLEARED!  Choose your reward"
	elif tutorial_mode:
		msg.text = "TUTORIAL COMPLETE!  " + _k("Press ENTER to start the real game  (R to replay)", "Tap the screen to start the real game")
	elif current_level < levels.size() - 1:
		msg.text = "LEVEL CLEARED!  " + _k("Press ENTER for the next level  (R to replay)", "Tap the screen for the next level")
	else:
		msg.text = "ALL LEVELS CLEARED! The house is yours.  " + _k("Press ENTER to play again  (R to replay)", "Tap the screen to play again")

# --- Priest: chase the ghost, charge a shockwave, then go back to searching ---
func _update_chase(v: Visitor, delta: float):
	# Charging: stands still until the wave goes off
	if v.chase_state == "windup":
		v.windup_t -= delta
		if v.windup_t <= 0.0:
			_fire_wave(v)
		return

	var d := ghost_pos.distance_to(v.pos)
	var clear := not _line_blocked(v.pos, ghost_pos)

	# Lost sight of the ghost for too long: give up and go back to searching
	if clear:
		v.lose_t = 0.0
	else:
		v.lose_t += delta
	if v.lose_t > 4.0 or d > CHASER_SIGHT * 1.8:
		v.chase_state = "none"
		v.wave_cd = 3.0
		v.need_repath = true
		return

	# Close enough: start charging the shockwave
	if d < CHASER_WAVE_RANGE and clear:
		v.chase_state = "windup"
		v.windup_t = CHASER_WINDUP
		return

	# Otherwise run toward the ghost (re-plans the route every so often)
	v.repath_cd -= delta
	if v.repath_cd <= 0.0:
		_set_path(v, ghost_pos)
		v.repath_cd = 0.35
	_follow_path(v, CHASER_SPEED, delta)

func _fire_wave(v: Visitor):
	v.chase_state = "none"
	v.wave_cd = CHASER_WAVE_COOLDOWN
	v.need_repath = true      # goes back to searching for the remains
	wave_t = 0.0
	wave_origin = v.pos
	shake = 24.0
	shock_flash = 0.5
	_say(v, "wave")
	_play(snd_shock)
	var in_wave: bool = ghost_pos.distance_to(v.pos) < CHASER_WAVE_RADIUS and not _line_blocked(v.pos, ghost_pos)
	if in_wave and dodge_t > 0.0:
		# PERFECT DODGE: no damage, and a short window to counter-attack
		counter_t = COUNTER_WINDOW
		_info("PERFECT DODGE! Scare him within 1 second for a COUNTER HIT!")
	elif in_wave:
		var lost: float = max_fear * CHASER_ENERGY_DRAIN
		fear_energy = max(0.0, fear_energy - lost)
		_info("HOLY SHOCKWAVE! You lost %d%% of your energy!" % int(round(CHASER_ENERGY_DRAIN * 100.0)))
	else:
		_info("You dodged the holy shockwave!")

func _update_visitor(v: Visitor, delta: float):
	if v.gone:
		return

	# Waiting outside until it's his turn to arrive
	if not v.started:
		v.delay -= delta
		if v.delay > 0.0:
			return
		v.started = true

	v.at_remains = false

	# Terrified: runs out the front door
	if v.courage <= 0.0:
		if not v.fleeing:
			v.fleeing = true
			v.chase_state = "none"
			_play(snd_flee)
			_say(v, "flee")
			_set_path(v, EXIT_POS)
			# His panic shakes the others
			for o in visitors:
				if o != v and _active(o) and panic_amount > 0.0:
					o.courage -= panic_amount
					_say(o, "scared")
		if _follow_path(v, 220.0, delta):
			v.gone = true
			_check_win()
		return

	# Stunned by a scare: stumbles away from the ghost (this also cancels a shockwave)
	if v.stun > 0.0:
		if v.chase_state != "none":
			v.chase_state = "none"
			v.wave_cd = 4.0
		v.stun -= delta
		var away := (v.pos - ghost_pos).normalized()
		_try_move(v, away * 140.0 * delta)
		if v.stun <= 0.0:
			v.need_repath = true
		return

	# Just arrived: walks in through the front door
	if not v.entered:
		if v.need_repath:
			_set_path(v, v.entry_target)
			v.need_repath = false
		if _follow_path(v, v.speed * 1.3, delta):
			v.entered = true
			v.need_repath = true
			_say(v, "enter")
		return

	# Priest: spots the ghost and hunts it
	if v.chaser:
		v.wave_cd = max(0.0, v.wave_cd - delta)
		if v.chase_state == "none" and v.wave_cd <= 0.0 \
				and ghost_pos.distance_to(v.pos) < CHASER_SIGHT \
				and not _line_blocked(v.pos, ghost_pos):
			v.chase_state = "chase"
			v.repath_cd = 0.0
			v.lose_t = 0.0
			_say(v, "spot")
			if not dodge_hint_shown:
				dodge_hint_shown = true
				_info(_k("Press SHIFT just before his shockwave lands to DODGE it!", "Tap DODGE just before his shockwave lands!"))
		if v.chase_state != "none":
			_update_chase(v, delta)
			return

	# He notices the remains if he's close AND can see them
	if not v.noticed and v.pos.distance_to(remains_pos) < notice_range \
			and not _line_blocked(v.pos, remains_pos):
		_notice(v)

	if v.noticed:
		# Walk to the remains, then destroy them
		if v.need_repath:
			_set_path(v, remains_pos)
			v.need_repath = false
		var close_enough := v.pos.distance_to(remains_pos) <= 32.0
		if not close_enough:
			var path_done := _follow_path(v, v.speed * 1.5, delta)
			close_enough = path_done and v.pos.distance_to(remains_pos) < 70.0
		if close_enough:
			v.at_remains = true
			if not v.destroy_said:
				v.destroy_said = true
				_say(v, "destroy")
	else:
		# Calm: wanders, or searches room by room
		if v.need_repath:
			_pick_wander_target(v)
			v.need_repath = false
		if _follow_path(v, v.speed, delta):
			v.idle -= delta
			if v.idle <= 0.0:
				v.idle = randf_range(0.5, 1.2) if search_mode else randf_range(1.0, 2.5)
				_pick_wander_target(v)
		# Occasional muttering
		v.chat_cd -= delta
		if v.chat_cd <= 0.0 and v.say_timer <= 0.0:
			_say(v, "idle")
			v.chat_cd = randf_range(6.0, 10.0)

# ---------------------------------------------------------------
# DRAWING
# ---------------------------------------------------------------
func _draw_furniture(f: Dictionary):
	var r: Rect2 = f["r"]
	var col: Color = f["c"]
	var kind: String = f["kind"]
	match kind:
		"rug":
			draw_rect(r, col)
			draw_rect(r.grow(-6.0), col.lightened(0.15), false, 2.0)
		"round":
			var rad := minf(r.size.x, r.size.y) / 2.0
			draw_circle(r.get_center(), rad, col)
			draw_circle(r.get_center(), rad * 0.5, col.darkened(0.3))
		"bed":
			draw_rect(r, Color(0.32, 0.22, 0.18))
			draw_rect(Rect2(r.position + Vector2(5, 28), r.size - Vector2(10, 33)), col)
			draw_rect(Rect2(r.position + Vector2(8, 6), Vector2(48, 18)), Color(0.95, 0.95, 0.95))
			draw_rect(Rect2(r.position + Vector2(r.size.x - 56, 6), Vector2(48, 18)), Color(0.95, 0.95, 0.95))
			draw_rect(r, Color(0, 0, 0, 0.35), false, 2.0)
		"tub":
			draw_rect(r, col)
			draw_rect(Rect2(r.position + Vector2(6, 6), r.size - Vector2(12, 12)), Color(0.55, 0.75, 0.9))
			draw_rect(r, Color(0, 0, 0, 0.35), false, 2.0)
		"stove":
			draw_rect(r, col)
			for p in [Vector2(15, 6), Vector2(45, 6), Vector2(15, 18), Vector2(45, 18)]:
				draw_circle(r.position + p, 4.0, Color(0.55, 0.55, 0.55))
		_:
			draw_rect(r, col)
			draw_rect(r, Color(0, 0, 0, 0.35), false, 2.0)

func _draw():
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.12, 0.15))  # outside the house

	# Doorstep outside the front door
	draw_rect(Rect2(530, 628, 100, 20), Color(0.3, 0.3, 0.33))

	# Room floors
	var xs0 := [68, 400, 760]
	var xs1 := [400, 760, 1084]
	var ys0 := [128, 370]
	var ys1 := [370, 612]
	for ci in 3:
		for ri in 2:
			var col: Color = floor_cols[ci][ri]
			draw_rect(Rect2(xs0[ci], ys0[ri], xs1[ci] - xs0[ci], ys1[ri] - ys0[ri]), col)

	# Doorways
	for d in doors:
		draw_rect(d, Color(0.6, 0.5, 0.35))

	# Walls
	for r in walls:
		draw_rect(r, Color(0.35, 0.28, 0.28))

	# Furniture
	for f in furniture:
		_draw_furniture(f)

	# Front door (open, swinging inward)
	draw_line(Vector2(540, 618), Vector2(540, 578), Color(0.45, 0.3, 0.2), 5.0)
	draw_arc(Vector2(540, 618), 40.0, -PI / 2.0, 0.0, 16, Color(1, 1, 1, 0.2), 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(634, 643), "FRONT DOOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.6))

	# Room labels
	var labels := [
		["BEDROOM", Vector2(78, 350)],
		["LIVING ROOM", Vector2(418, 350)],
		["KITCHEN", Vector2(778, 350)],
		["BATHROOM", Vector2(78, 400)],
		["ENTRANCE HALL", Vector2(418, 602)],
		["STUDY", Vector2(778, 400)],
	]
	for l in labels:
		draw_string(ThemeDB.fallback_font, l[1], l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.5))

	# Remains: pulse gets faster as they're being destroyed
	var speed := 250.0 - destroy_progress * 1.8
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / speed)
	draw_rect(Rect2(remains_pos - Vector2(12, 12), Vector2(24, 24)), Color(0.7, 0.3, 1.0, pulse))

	if scare_flash > 0.0:
		draw_arc(ghost_pos, SCARE_RANGE, 0, TAU, 48, Color(0.7, 0.9, 1.0, scare_flash * 3.0), 4.0)

	# Visitors
	for v in visitors:
		if not v.started or v.gone:
			continue
		draw_circle(v.pos, 18, v.color)
		draw_rect(Rect2(v.pos + Vector2(-20, -34), Vector2(40, 6)), Color(0.2, 0.2, 0.2))
		draw_rect(Rect2(v.pos + Vector2(-20, -34), Vector2(40 * max(v.courage, 0.0) / v.max_courage, 6)), Color(0.3, 0.9, 0.4))
		if v.chase_state != "none" and v.courage > 0.0:
			draw_string(ThemeDB.fallback_font, v.pos + Vector2(-10, -42), "!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.85, 0.3))
		elif v.noticed and v.courage > 0.0:
			draw_string(ThemeDB.fallback_font, v.pos + Vector2(-5, -42), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1.0, 0.3, 0.3))

	# Ghost: see-through while inside a wall or dodging
	var ghost_col := Color(1.0, 0.4, 0.4, 0.95) if exposed else Color(0.8, 0.95, 1.0, 0.9)
	if ghost_in_wall:
		ghost_col.a = 0.4
	if dodge_t > 0.0:
		ghost_col.a = 0.3
	draw_circle(ghost_pos, 20, ghost_col)
