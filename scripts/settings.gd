extends Node
## Cài đặt người chơi (autoload "Settings"): ngôn ngữ, độ nhạy chuột, âm lượng.
## Lưu ở user://cai_dat.cfg, tách riêng khỏi bản lưu game.

signal changed

const PATH: String = "user://cai_dat.cfg"
const LANGS: Array = ["vi", "en"]

var lang: String = "vi"
var mouse_sens: float = 1.0      # hệ số nhân độ nhạy chuột (0.2 - 3.0)
var vol_master: float = 0.9      # 0..1
var vol_voice: float = 1.0
var vol_sfx: float = 0.9


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply()


func _ensure_buses() -> void:
	for b in ["Voice", "SFX"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	var c: ConfigFile = ConfigFile.new()
	if c.load(PATH) != OK:
		return
	lang = str(c.get_value("chung", "ngon_ngu", lang))
	if not LANGS.has(lang):
		lang = "vi"
	mouse_sens = float(c.get_value("dieu_khien", "do_nhay_chuot", mouse_sens))
	vol_master = float(c.get_value("am_thanh", "tong", vol_master))
	vol_voice = float(c.get_value("am_thanh", "loi_thoai", vol_voice))
	vol_sfx = float(c.get_value("am_thanh", "hieu_ung", vol_sfx))


func save_settings() -> void:
	var c: ConfigFile = ConfigFile.new()
	c.set_value("chung", "ngon_ngu", lang)
	c.set_value("dieu_khien", "do_nhay_chuot", mouse_sens)
	c.set_value("am_thanh", "tong", vol_master)
	c.set_value("am_thanh", "loi_thoai", vol_voice)
	c.set_value("am_thanh", "hieu_ung", vol_sfx)
	c.save(PATH)


func apply() -> void:
	_set_bus("Master", vol_master)
	_set_bus("Voice", vol_voice)
	_set_bus("SFX", vol_sfx)
	TranslationServer.set_locale(lang)
	changed.emit()


func _set_bus(name: String, v: float) -> void:
	var i: int = AudioServer.get_bus_index(name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))


## Âm lượng cho giọng đọc máy (TTS không đi qua bus âm thanh): 0..100
func tts_volume() -> int:
	return int(clampf(vol_master * vol_voice, 0.0, 1.0) * 100.0)


# ---------------------------------------------------------------- chữ giao diện hai ngôn ngữ

const TEXT: Dictionary = {
	"subtitle": ["Sau 60 ngày, cuộc sống sẽ ra sao là do bạn.", "After 60 days, what your life becomes is up to you."],
	"start": ["Bắt đầu", "New game"],
	"continue": ["Tiếp tục", "Continue"],
	"options": ["Tùy chọn", "Options"],
	"quit": ["Thoát", "Quit"],
	"back": ["Quay lại", "Back"],
	"saves": ["CHỌN BẢN LƯU", "SELECT A SAVE"],
	"slot": ["Ô %d", "Slot %d"],
	"empty": ["Trống", "Empty"],
	"day": ["Ngày %d", "Day %d"],
	"money": ["Tiền", "Cash"],
	"debt": ["Nợ còn", "Debt left"],
	"saved_at": ["Lưu lúc", "Saved"],
	"no_saves": ["Chưa có bản lưu nào.", "No saved games yet."],
	"opt_title": ["TÙY CHỌN", "OPTIONS"],
	"language": ["Ngôn ngữ", "Language"],
	"lang_vi": ["Tiếng Việt", "Tiếng Việt"],
	"lang_en": ["English", "English"],
	"sens": ["Độ nhạy chuột", "Mouse sensitivity"],
	"vol_master": ["Âm lượng tổng", "Master volume"],
	"vol_voice": ["Lời thoại", "Voice"],
	"vol_sfx": ["Hiệu ứng", "Effects"],
	"lang_note": ["Lời thoại và cốt truyện hiện mới có tiếng Việt.", "Story and dialogue are currently Vietnamese only."],
	"confirm_new": ["Bắt đầu lại từ đầu? Các bản lưu vẫn được giữ.", "Start a new game? Your saves are kept."],
	"yes": ["Đồng ý", "Yes"],
	"no": ["Không", "No"],
	"paused": ["TẠM DỪNG", "PAUSED"],
	"paused_body": ["Ngày %d · %s. Chỉ lưu được khi đang chơi tự do (không trong đoạn cắt cảnh).", "Day %d · %s. You can only save during free play (not in cutscenes)."],
	"resume": ["Tiếp tục chơi", "Resume"],
	"save": ["Lưu game", "Save game"],
	"load": ["Tải game", "Load game"],
	"to_title": ["Về màn hình chính", "Main menu"],
	"quit_game": ["Thoát game", "Quit game"],
	"save_title": ["LƯU GAME", "SAVE GAME"],
	"save_body": ["Chọn ô để lưu (ô đã có sẽ bị ghi đè):", "Pick a slot (existing saves are overwritten):"],
	"load_title": ["TẢI GAME", "LOAD GAME"],
	"load_body": ["Chọn bản lưu:", "Choose a save:"],
	"saved_ok": ["Đã lưu vào ô %d", "Saved to slot %d"],
	"saved_fail": ["Không lưu được!", "Could not save!"],
	"skip_hint": ["[Space]  Bỏ qua", "[Space]  Skip"],
	"hint_menu": ["Chuột hoặc phím ↑ ↓ · Enter để chọn · Esc để quay lại", "Mouse or ↑ ↓ · Enter to select · Esc to go back"],
}


## Chữ giao diện theo ngôn ngữ đang chọn.
func t(key: String) -> String:
	var e: Array = TEXT.get(key, [key, key])
	return str(e[1] if lang == "en" else e[0])
