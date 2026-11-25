extends Node
## Trạng thái và luật chơi cốt lõi (autoload "GameState").
## Mọi con số cân bằng nằm ở phần hằng số ngay bên dưới, chỉnh ở đây là đủ.

signal changed
signal message(text: String)
signal ending(id: String)
## Phát ra lần đầu người chơi có một món đồ (dùng cho hướng dẫn, ví dụ lockpick)
signal item_first(id: String)

const TOTAL_DAYS: int = 60
const SLOTS_PER_DAY: int = 4
## Thời gian thực: 12 phút ngoài đời = 24 giờ trong game -> 1 giây = 2 phút game
const GAME_MIN_PER_SEC: float = 1440.0 / 720.0
const WAKE_MIN: int = 7 * 60            # giờ bắt đầu ngày 1
## Giờ ngủ cố định: 00:00 -> 06:00. 23:30 cảnh báo về nhà; 00:00 còn ở ngoài thì mất 5% tiền.
const MORNING_MIN: int = 6 * 60         # thức dậy lúc 06:00
const NIGHT_WARN_MIN: int = 23 * 60 + 30
const OUTSIDE_LOSS: float = 0.05
## Ngủ và thức
const SLEEP_HOURS: int = 8              # ngủ bình thường
const SLEEP_LONG_HOURS: int = 12        # ngủ khi đã thức gần 2 ngày
const WARN_AWAKE_MIN: int = 42 * 60     # thức 42 tiếng: cảnh báo "sắp ngất"
const COLLAPSE_AWAKE_MIN: int = 48 * 60 # thức quá 2 ngày: gục, ngủ bù mất 1 ngày
const MAX_COLLAPSES: int = 3            # suy kiệt quá 3 lần -> nhập viện, kết thúc xấu
const HUNGER_PER_HOUR: float = 5.0      # 100 -> 0 trong khoảng 20 giờ
const THIRST_PER_HOUR: float = 7.0      # 100 -> 0 trong khoảng 14 giờ
## Thời gian (phút game) mỗi hành động tiêu tốn
const DUR: Dictionary = {"stream": 180, "talk": 45, "eat_out": 40, "noodle": 20, "water": 5, "trash": 30, "pile": 20, "gamble": 30, "gray": 180, "loan": 15}
const SLOT_NAMES: Array = ["Sáng", "Trưa", "Chiều", "Tối"]
const DEBT_START: int = 100_000_000
## Mốc trả nợ: ngày -> tổng số tiền ĐÃ TRẢ cần đạt đến hết ngày đó
## Lịch chủ nợ đến thu (theo kịch bản): ngày -> tổng số tiền ĐÃ TRẢ cần đạt (cộng dồn)
## ngày 13 thu 5tr, ngày 40 thu 10tr, ngày 50 thu 5tr, ngày 60 trả hết phần còn lại
const MILESTONES: Dictionary = {13: 5_000_000, 40: 15_000_000, 50: 20_000_000, 60: 100_000_000}
const COLLECT_HOUR: int = 20           # giờ chủ nợ đến nhà
const REPAIR_SMASH: int = 800_000      # sửa góc stream bị đập
const REPAIR_SMASH_RUDE: int = 1_600_000  # ... nếu ngày 1 đã hỗn
const NEW_HOUSE_DEADLINE: int = 27     # hết ngày 27 chưa thuê nhà mới -> vợ bỏ đi
const LOCKPICK_DAY: int = 32           # chú Tư bán lockpick từ ngày 32
const SITE_DAY: int = 37               # từ ngày 37 lẻn được vào công trường
const SITE_FINE: int = 2_000_000       # bị bảo vệ bắt lần 2: phạt tiền
const AI_DEAL_MONEY: int = 20_000_000
const NEW_HOUSE_DEPOSIT: int = 3_000_000
## Tiền nhà đóng theo tháng, vào cuối các ngày này
const RENT_DAYS: Array = [7, 45]
const RENT_OLD: int = 2_500_000
const RENT_NEW: int = 4_000_000
const RUDE_PENALTY: int = 10_000_000   # nợ thêm khi hỗn với chủ nợ ngày 1
const FOLLOWER_CAP: float = 2000.0
const FOLLOWER_GROW: float = 1.6
const DONOR_RATE: float = 0.025        # tỉ lệ người xem donate
const AD_PER_VIEWER: int = 700         # tiền quảng cáo / người xem / buổi 3 tiếng
## Giờ giấc (phút trong ngày)
const PEAK_START: int = 20 * 60        # giờ vàng stream: 20:00 - 23:00 (đông người xem nhất)
const PEAK_END: int = 23 * 60
const STREAM_MAX_MIN: int = 8 * 60     # tối đa 8 tiếng stream mỗi ngày
const OFFPEAK_MULT: float = 0.35       # ngoài giờ vàng, người xem chỉ bằng 35%
const NIGHT_MULT: float = 0.2          # 0:00 - 7:00
const STREET_CLOSE: int = 23 * 60      # sau 23:00 phố vắng, quán đóng (trừ quán ăn), có trấn lột
const SHOP_OPEN: int = 7 * 60
const WIFE_LEAVE: int = 7 * 60         # vợ đi làm lúc 7:00
const WIFE_HOME: int = 18 * 60         # ... về lúc 18:00
const WIFE_SLEEP: int = 23 * 60        # vợ đi ngủ lúc 23:00
const WIFE_TALK_MAX: int = 3
const WIFE_TALK_GAIN: int = 3
const WIFE_COOK_CHANCE: float = 0.6
const ROB_RATE: float = 0.05           # trấn lột / ngủ ngoài đường mất 5% tiền mặt
const IGNORE_WIFE_LOSS: int = 8        # phớt lờ vợ lúc 23h
const SAVE_SLOTS: int = 3
const INV_SIZE: int = 15               # tổng số ô túi đồ (5 ô đầu là thanh nhanh)
const HOTBAR: int = 5
const CONTENT: Dictionary = {
	"game": {"name": "Chơi game", "mult": 1.0, "grow": 1.0, "hp": -5, "mood": -2, "wife": 0},
	"chat": {"name": "Trò chuyện / hài", "mult": 0.85, "grow": 1.0, "hp": -3, "mood": 3, "wife": 0},
	"shock": {"name": "Thử thách gây sốc", "mult": 1.35, "grow": 1.3, "hp": -8, "mood": -6, "wife": -3},
}

var day: int = 1
var slot: int = 0  # buổi trong ngày (0 sáng, 1 trưa, 2 chiều, 3 tối), suy ra từ đồng hồ
var minutes: float = 420.0  # phút trong ngày, có thể quá 1440 nếu thức qua nửa đêm
var hunger: float = 100.0  # 100 = no, 0 = đói lả
var thirst: float = 100.0  # 100 = đủ nước, 0 = khát khô
var _drain_acc: float = 0.0
var money: int = 3_000_000
var wife: int = 60
var health: int = 100
var mood: int = 70
var danger: int = 0
var debt_total: int = DEBT_START
var paid: int = 0
var followers: float = 0.0
var pc_level: int = 1  # 1..4, theo danh sách "pcs" trong items.json
var gear: Dictionary = {}  # đồ stream đã mua: id -> true
var inventory: Array = []  # INV_SIZE ô, mỗi ô {} (trống) hoặc {"id", "count"}
var selected: int = 0      # ô đang chọn trên thanh nhanh (0..4)
var rent_owed: int = 0
var talks_today: int = 0
var wife_cooked: bool = false
var wife_met_today: bool = false
var dinner_eaten: bool = false
var streamed_today: bool = false
var stream_min_today: float = 0.0
var awake_min: float = 0.0
var collapses: int = 0
var warned_awake: bool = false
## Hàng đợi để main hiện giao diện khi rảnh
var pending_rollovers: Array = []    # mỗi lần qua 0:00: {"day", "lines"}
var morning_pending: bool = false    # sự kiện buổi sáng
var wife_leave_pending: bool = false # vợ chào đi làm lúc 7:00
var warn_pending: bool = false
var collapse_pending: bool = false  # (không còn dùng)
var midnight_pending: bool = false   # vừa qua 0:00 khi đang thức -> main cắt cảnh, cho đi ngủ
var night_warn_pending: bool = false
## Thống kê trong ngày (hiện ở bảng cuối ngày)
var today: Dictionary = {}
## Ô lưu đang chờ tải sau khi nạp lại cảnh (0 = không)
var pending_load: int = 0
var loaded_extra: Dictionary = {}
var items_db: Dictionary = {}
var pc_dur: float = 70.0
var new_house: bool = false
var flags: Dictionary = {}
var scav_today: int = 0
var total_stream_income: int = 0
var loan_taken: int = 0
var last_viewers: int = 0
var forced_event: String = ""
var last_event: String = ""
var finished: bool = false
var ending_id: String = ""
var data: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_load_data()
	reset()


## Biến theo ngày lịch (reset lúc 0:00)
func _new_day_vars() -> void:
	streamed_today = false
	stream_min_today = 0.0
	scav_today = 0
	today = {"donate": 0, "ads": 0, "other": 0, "viewers": 0, "followers": 0, "robbed": 0, "spent": 0, "stream_min": 0}


## Biến theo lịch của vợ (reset lúc 7:00 khi vợ đi làm)
func _wife_day_vars() -> void:
	talks_today = 0
	wife_met_today = false
	dinner_eaten = false
	wife_cooked = rng.randf() < WIFE_COOK_CHANCE


func _load_items() -> void:
	var f: FileAccess = FileAccess.open("res://data/items.json", FileAccess.READ)
	if f == null:
		push_error("Không đọc được data/items.json")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		items_db = parsed


func _load_data() -> void:
	_load_items()
	var f: FileAccess = FileAccess.open("res://data/events.json", FileAccess.READ)
	if f == null:
		push_error("Không đọc được data/events.json")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("data/events.json sai định dạng")


func reset() -> void:
	day = 1
	slot = 0
	minutes = float(WAKE_MIN)
	hunger = 90.0
	thirst = 90.0
	_drain_acc = 0.0
	money = 2_000_000
	wife = 60
	health = 100
	mood = 70
	danger = 0
	debt_total = DEBT_START
	paid = 0
	followers = 0.0
	pc_level = 1
	gear = {}
	inventory = []
	for _i in INV_SIZE:
		inventory.append({})
	selected = 0
	rent_owed = 0
	_new_day_vars()
	_wife_day_vars()
	awake_min = 0.0
	collapses = 0
	warned_awake = false
	pending_rollovers = []
	morning_pending = false
	wife_leave_pending = false
	warn_pending = false
	collapse_pending = false
	midnight_pending = false
	night_warn_pending = false
	pc_dur = 70.0
	new_house = false
	flags = {}
	scav_today = 0
	total_stream_income = 0
	loan_taken = 0
	last_viewers = 0
	forced_event = ""
	last_event = ""
	finished = false
	ending_id = ""
	changed.emit()


# ---------------------------------------------------------------- tiện ích

func say(text: String) -> void:
	message.emit(text)


func fmt_money(v: int) -> String:
	var neg: bool = v < 0
	var a: int = absi(v)
	var s: String = ""
	if a >= 1_000_000:
		s = ("%.1f" % (float(a) / 1_000_000.0)).replace(".", ",") + "tr"
		s = s.replace(",0tr", "tr")
	elif a >= 1000:
		s = str(a / 1000) + "k"
	else:
		s = str(a) + "đ"
	return ("-" if neg else "") + s


func remaining_debt() -> int:
	return maxi(0, debt_total - paid)


func hour() -> int:
	return int(minutes) / 60


func clock_str() -> String:
	var m: int = int(minutes)
	return "%02d:%02d" % [(m / 60) % 24, m % 60]


func _update_slot() -> void:
	var h: int = hour()
	if h < 5 or h >= 18:
		slot = 3
	elif h < 11:
		slot = 0
	elif h < 14:
		slot = 1
	elif h < 18:
		slot = 2
	else:
		slot = 3


## Đồng hồ chạy theo thời gian thực (main gọi mỗi khung hình khi người chơi đang tự do).
func tick(delta: float) -> void:
	if finished:
		return
	var before: int = int(minutes)
	_advance_core(delta * GAME_MIN_PER_SEC, false)
	if int(minutes) != before:
		_update_slot()
		changed.emit()


## Hành động tốn thời gian: tua đồng hồ đi một số phút game (đang thức).
func advance(mins: float) -> void:
	_advance_core(mins, false)
	_update_slot()
	changed.emit()


## Lõi thời gian: chạy từng đoạn, bắt các mốc 7:00 (vợ đi làm) và 0:00 (sang ngày mới).
func _advance_core(m: float, sleeping: bool) -> void:
	var left: float = m
	var guard: int = 0
	while left > 0.0 and guard < 50:
		guard += 1
		var to_mid: float = 1440.0 - minutes
		if not sleeping and minutes < float(NIGHT_WARN_MIN):
			to_mid = minf(to_mid, float(NIGHT_WARN_MIN) - minutes)
		var to_morn: float = (float(WIFE_LEAVE) - minutes) if minutes < float(WIFE_LEAVE) else (1440.0 - minutes + float(WIFE_LEAVE))
		var step: float = minf(left, minf(to_mid, to_morn))
		var prev: float = minutes
		minutes += step
		left -= step
		_decay(step, sleeping)
		if not sleeping:
			awake_min += step
		if not sleeping and prev < float(NIGHT_WARN_MIN) and minutes >= float(NIGHT_WARN_MIN):
			night_warn_pending = true
		if minutes >= 1440.0:
			minutes = 0.0
			_rollover()
			if not sleeping:
				# 0:00 khi còn thức: dừng đồng hồ, main sẽ cắt cảnh đi ngủ
				midnight_pending = true
				break
		elif prev < float(WIFE_LEAVE) and minutes >= float(WIFE_LEAVE):
			_morning(sleeping)
		if finished:
			break


## Qua 0:00: tổng kết ngày cũ, tiền nhà, mốc nợ, sang ngày mới
func _rollover() -> void:
	var ended: int = day
	var lines: Array = day_summary()
	lines.append("")
	var due: int = rent_owed
	if RENT_DAYS.has(ended):
		due += RENT_NEW if new_house else RENT_OLD
	if due > 0:
		if money >= due:
			money -= due
			rent_owed = 0
			lines.append("Đóng tiền nhà tháng này: -%s" % fmt_money(due))
		else:
			rent_owed = due - money
			lines.append("Không đủ tiền nhà! Đóng được %s, còn nợ chủ nhà %s (tự trừ vào các ngày sau)." % [fmt_money(money), fmt_money(rent_owed)])
			money = 0
			apply({"wife": -10, "mood": -8})
	danger = maxi(0, danger - 2)
	if ended == NEW_HOUSE_DEADLINE and not new_house:
		finish("wife_left_27")
		return
	if ended >= TOTAL_DAYS:
		_evaluate_end()
		return
	day += 1
	_new_day_vars()
	pending_rollovers.append({"day": ended, "lines": lines})


## 7:00: vợ đi làm, sự kiện buổi sáng
func _morning(sleeping: bool) -> void:
	_wife_day_vars()
	if not sleeping:
		wife_leave_pending = true
	if day > 1:
		morning_pending = true


func is_night() -> bool:
	return minutes >= float(STREET_CLOSE) or minutes < float(SHOP_OPEN)


## 0:00: ngủ đến 06:00. outside = lúc 0:00 vẫn ở ngoài đường (mất 5% tiền mặt)
func night_sleep(outside: bool) -> Array:
	midnight_pending = false
	var lines: Array = []
	if outside:
		var lost: int = int(float(money) * OUTSIDE_LOSS)
		money -= lost
		lines.append("Nửa đêm rồi mà bạn vẫn lang thang ngoài đường. Về đến nhà thì phát hiện bị móc túi mất %s (5%% tiền mặt)." % fmt_money(lost))
		apply({"mood": -5})
	return lines + _sleep_until_morning()


## Đi ngủ sớm ở giường: ngủ luôn đến 06:00 sáng hôm sau
func sleep_early() -> Array:
	var lines: Array = ["Bạn đi ngủ sớm."]
	return lines + _sleep_until_morning()


func _sleep_until_morning() -> Array:
	var lines: Array = []
	var mins: float = float(MORNING_MIN) - minutes
	if mins <= 0.0:
		mins += 1440.0
	var h: float = mins / 60.0
	var rest: int = int(h * 2.0)
	if hunger < 20.0:
		rest -= 6
		lines.append("Bụng đói cồn cào, bạn trằn trọc mãi.")
	if thirst < 20.0:
		rest -= 4
		lines.append("Cổ họng khô khốc, ngủ không ngon.")
	awake_min = 0.0
	_advance_core(mins, true)
	var rl: Array = apply({"health": rest, "mood": 5})
	lines.append("Ngủ %d tiếng." % int(round(h)))
	if rl.size() > 0:
		lines.append("Hồi phục: " + ", ".join(PackedStringArray(rl)))
	_update_slot()
	changed.emit()
	return lines





func _decay(m: float, sleeping: bool = false) -> void:
	var k: float = 0.5 if sleeping else 1.0
	hunger = maxf(0.0, hunger - m * k * HUNGER_PER_HOUR / 60.0)
	thirst = maxf(0.0, thirst - m * k * THIRST_PER_HOUR / 60.0)
	# Đói hoặc khát cạn thì mất dần sức khỏe và tinh thần
	if hunger <= 0.0:
		_drain_acc += m * 3.0 / 60.0
	if thirst <= 0.0:
		_drain_acc += m * 4.0 / 60.0
	if _drain_acc >= 1.0:
		var d: int = int(_drain_acc)
		_drain_acc -= float(d)
		health = clampi(health - d, 0, 100)
		mood = clampi(mood - d, 0, 100)
		_check_end()


func time_name() -> String:
	return str(SLOT_NAMES[mini(slot, SLOTS_PER_DAY - 1)])


func next_milestone() -> Dictionary:
	var keys: Array = MILESTONES.keys()
	keys.sort()
	for k in keys:
		if int(k) >= day:
			var need: int = int(MILESTONES[k])
			if int(k) == TOTAL_DAYS:
				need = maxi(need, debt_total)
			return {"day": int(k), "need": need}
	return {"day": TOTAL_DAYS, "need": debt_total}




func _sgn(v: int) -> String:
	return ("+" if v >= 0 else "") + str(v)


func _val(v: Variant) -> int:
	if v is Array:
		return rng.randi_range(int(v[0]), int(v[1]))
	return int(v)


# ---------------------------------------------------------------- áp dụng hiệu ứng

func apply(e: Dictionary) -> Array:
	var out: Array = []
	for k in e.keys():
		var key: String = str(k)
		if key == "flag":
			flags[str(e[k])] = true
			continue
		var v: int = _val(e[k])
		if v == 0:
			continue
		match key:
			"money":
				if v > 0:
					today["other"] = int(today.get("other", 0)) + v
				money = maxi(0, money + v)
				out.append("Tiền %s%s" % [("+" if v >= 0 else "-"), fmt_money(absi(v))])
			"wife":
				wife = clampi(wife + v, 0, 100)
				out.append("Tình cảm vợ %s" % _sgn(v))
			"health":
				health = clampi(health + v, 0, 100)
				out.append("Sức khỏe %s" % _sgn(v))
			"mood":
				mood = clampi(mood + v, 0, 100)
				out.append("Tinh thần %s" % _sgn(v))
			"danger":
				danger = clampi(danger + v, 0, 100)
				out.append("Nguy hiểm %s" % _sgn(v))
			"followers":
				followers = maxf(0.0, followers + float(v))
				out.append("Follower %s" % _sgn(v))
			"hunger":
				hunger = clampf(hunger + float(v), 0.0, 100.0)
				out.append("No %s" % _sgn(v))
			"thirst":
				thirst = clampf(thirst + float(v), 0.0, 100.0)
				out.append("Nước %s" % _sgn(v))
			"pc_dur":
				pc_dur = clampf(pc_dur + float(v), 0.0, 100.0)
				out.append("Độ bền máy %s" % _sgn(v))
	_check_end()
	changed.emit()
	return out


func _check_end() -> void:
	if finished:
		return
	if wife <= 0:
		finish("wife_left")
	elif health <= 0:
		finish("hospital")


func finish(id: String) -> void:
	if finished:
		return
	finished = true
	ending_id = id
	ending.emit(id)
	changed.emit()


func _evaluate_end() -> void:
	if finished:
		return
	if remaining_debt() <= 0:
		finish("happy" if wife >= 60 else "ok")
	else:
		finish("bad_debt")


# ---------------------------------------------------------------- sự kiện

func _event_ok(ev: Dictionary) -> bool:
	if day < int(ev.get("min_day", 1)) or day > int(ev.get("max_day", 999)):
		return false
	if followers < float(ev.get("min_followers", 0)):
		return false
	if bool(ev.get("once", false)) and flags.has("seen_" + str(ev["id"])):
		return false
	if str(ev["id"]) == last_event:
		return false
	var n: Dictionary = ev.get("needs", {})
	if n.has("wife_below") and wife >= int(n["wife_below"]):
		return false
	if n.has("wife_above") and wife <= int(n["wife_above"]):
		return false
	if n.has("money_below") and money >= int(n["money_below"]):
		return false
	if n.has("danger_above") and danger <= int(n["danger_above"]):
		return false
	if n.has("new_house") and bool(n["new_house"]) != new_house:
		return false
	if n.has("flag") and not flags.has(str(n["flag"])):
		return false
	if n.has("noflag") and flags.has(str(n["noflag"])):
		return false
	return true


func _pick_weighted(list: Array) -> Dictionary:
	var total: float = 0.0
	for it in list:
		total += float(it.get("weight", 1))
	if total <= 0.0:
		return {}
	var r: float = rng.randf() * total
	for it in list:
		r -= float(it.get("weight", 1))
		if r <= 0.0:
			return it
	return list[list.size() - 1]


func _find_event(id: String) -> Dictionary:
	for ev in data.get("events", []):
		if str(ev["id"]) == id:
			return ev
	return {}


func roll_morning_event() -> Dictionary:
	var ev: Dictionary = {}
	if forced_event != "":
		ev = _find_event(forced_event)
		forced_event = ""
	elif danger >= 60 and rng.randf() < 0.3:
		ev = _find_event("street_ambush")
	elif rng.randf() < 0.85:
		var pool: Array = []
		for e in data.get("events", []):
			if float(e.get("weight", 0)) > 0.0 and _event_ok(e):
				pool.append(e)
		ev = _pick_weighted(pool)
	if not ev.is_empty():
		flags["seen_" + str(ev["id"])] = true
		last_event = str(ev["id"])
	return ev


func roll_list(key: String) -> Dictionary:
	var list: Array = data.get(key, [])
	if list.is_empty():
		return {"text": "...", "lines": []}
	var r: Dictionary = _pick_weighted(list)
	var lines: Array = apply(r.get("effects", {}))
	return {"text": str(r.get("text", "")), "lines": lines}


# ---------------------------------------------------------------- hành động

func can_stream() -> bool:
	return pc_dur > 0.0


func stream_hours_left() -> int:
	var by_cap: int = int((float(STREAM_MAX_MIN) - stream_min_today) / 60.0)
	var by_midnight: int = int((1440.0 - minutes) / 60.0)
	return mini(by_cap, by_midnight)


## Hệ số người xem theo giờ trong ngày
func stream_mult_at(m: float) -> float:
	var mm: float = fmod(m, 1440.0)
	if mm >= float(PEAK_START) and mm < float(PEAK_END):
		return 1.0
	if mm < float(SHOP_OPEN):
		return NIGHT_MULT
	return OFFPEAK_MULT


## Stream `hours` tiếng kể từ bây giờ. Giờ vàng 20-23h đông người xem nhất.
func do_stream(kind: String, hours: float) -> Dictionary:
	var c: Dictionary = CONTENT[kind]
	hours = clampf(hours, 0.0, (float(STREAM_MAX_MIN) - stream_min_today) / 60.0)
	# tổng hệ số người xem qua từng nửa giờ (chuẩn hóa theo 3 tiếng giờ vàng)
	var f: float = 0.0
	var peak_mult: float = 0.0
	var t: float = minutes
	var steps: int = int(round(hours * 2.0))
	for _i in steps:
		var mlt: float = stream_mult_at(t)
		f += mlt * 0.5
		peak_mult = maxf(peak_mult, mlt)
		t += 30.0
	var scale: float = f / 3.0
	var mood_f: float = 0.6 + float(mood) / 100.0 * 0.8
	var house_f: float = 1.3 if new_house else 1.0
	var base: float = 4.0 + pow(followers, 0.95) * 0.15
	var v: float = base * (1.0 + pc_view_bonus()) * (1.0 + gear_bonus("view"))
	v = v * house_f * mood_f * float(c["mult"]) * 1.3 * rng.randf_range(0.6, 1.5)
	var notes: Array = []
	var extra_mood: int = 0
	if followers >= 50.0 and peak_mult >= 1.0 and rng.randf() < 0.04:
		v *= 3.0
		followers *= 1.3
		notes.append("Clip của bạn bỗng được chia sẻ rầm rộ, view tăng vọt!")
	if kind == "shock" and rng.randf() < 0.3:
		v *= 0.4
		extra_mood = -8
		notes.append("Nội dung gây sốc bị report, nhiều người chửi rồi rời đi.")
	if flags.has("sold_to_ai"):
		v *= 0.5  # đã bán mặt cho AI: người xem giảm một nửa
	elif flags.has("refused_ai") and day >= 48 and day <= 52:
		v *= 0.8  # kênh AI nhái làm mất bớt người xem
	var viewers: int = maxi(0, int(v * maxf(peak_mult, 0.2)))
	var vv: int = maxi(0, int(v))
	var n: int = maxi(1, int(float(vv) * DONOR_RATE))
	var sample: int = mini(n, 100)
	var don: float = 0.0
	for _i in sample:
		var a: float = rng.randf_range(10000.0, 50000.0)
		if rng.randf() < 0.05:
			a *= 10.0
		don += a
	don = don * float(n) / float(sample) * (1.0 + gear_bonus("donate")) * scale
	var ads: int = int(float(vv * AD_PER_VIEWER) * scale)
	var crash: bool = rng.randf() < (100.0 - pc_dur) / 200.0 * clampf(hours / 3.0, 0.3, 2.0)
	if crash:
		don *= 0.5
		ads = int(float(ads) * 0.5)
		notes.append("Máy treo giữa buổi stream! Mất nửa doanh thu.")
	pc_dur = maxf(0.0, pc_dur - rng.randf_range(1.0, 4.0) * hours / 3.0)
	if pc_dur <= 0.0:
		notes.append("Máy tính hỏng hẳn. Phải sửa mới stream tiếp được.")
	var growth: float = float(vv) * FOLLOWER_GROW * float(c["grow"]) * maxf(0.0, 1.0 - followers / FOLLOWER_CAP) * scale
	if crash:
		growth *= 0.7
	followers += growth
	if flags.has("sold_to_ai"):
		don *= 0.5
		ads = int(float(ads) * 0.5)
	# Ngày 1-2: kênh mới tinh, thu nhập cố định 50k / 70k cả ngày, 1-5 người xem
	if day <= 2:
		viewers = rng.randi_range(1, 5)
		var fixed: int = 50_000 if day == 1 else 70_000
		var already: int = int(today.get("donate", 0)) + int(today.get("ads", 0))
		don = float(maxi(0, fixed - already))
		ads = 0
		followers -= growth
		growth = float(rng.randi_range(1, 2))
		followers += growth
	# Cộng đồng ủng hộ sau khi từ chối bán cho AI (một lần)
	var rally: int = 0
	if flags.has("refused_ai") and day >= 49 and not flags.has("rally_done"):
		flags["rally_done"] = true
		rally = 5_000_000
		don += float(rally)
		notes.append("Người donate đầu tiên của kênh kêu gọi mọi người ủng hộ bạn chống lại kênh AI nhái. Donate dồn dập!")
	var income: int = int(don) + ads
	money += income
	total_stream_income += income
	last_viewers = viewers
	streamed_today = true
	stream_min_today += hours * 60.0
	today["donate"] = int(today.get("donate", 0)) + int(don)
	today["ads"] = int(today.get("ads", 0)) + ads
	today["viewers"] = maxi(int(today.get("viewers", 0)), viewers)
	today["followers"] = int(today.get("followers", 0)) + int(growth)
	today["stream_min"] = int(today.get("stream_min", 0)) + int(hours * 60.0)
	advance(hours * 60.0)
	var eff: Dictionary = {"health": int(float(c["hp"]) * hours / 3.0), "mood": int(c["mood"]) + extra_mood, "wife": int(c["wife"])}
	var lines: Array = apply(eff)
	var chat: Array = []
	var good: Array = data.get("chat_good", [])
	var bad: Array = data.get("chat_bad", [])
	if viewers < 5:
		chat.append("(Chat im lặng. Chỉ có vài người xem...)")
	else:
		if good.size() > 0:
			chat.append(str(good.pick_random()))
		if bad.size() > 0 and (kind == "shock" or mood < 40 or rng.randf() < 0.4):
			chat.append(str(bad.pick_random()))
	return {"rally": rally, "first_donate": day == 3 and not flags.has("first_donate_shown"), "hours": hours, "viewers": viewers, "income": income, "donate": int(don), "ads": ads, "notes": notes, "chat": chat, "lines": lines, "growth": int(growth)}


func gamble(bet: int, pick_red: bool) -> Dictionary:
	bet = mini(bet, money)
	if bet <= 0:
		return {"text": "Bạn không còn tiền để cược.", "lines": []}
	var win: bool = rng.randf() < 0.47
	var ball_red: bool = pick_red if win else (not pick_red)
	var text: String = "Bóng dừng ở màu %s. " % ("ĐỎ" if ball_red else "ĐEN")
	var eff: Dictionary = {}
	if win:
		text += "Bạn thắng!"
		eff = {"money": bet, "mood": 4}
	else:
		text += "Bạn thua sạch."
		eff = {"money": -bet, "mood": -6}
	var lines: Array = apply(eff)
	flags["gambled"] = true
	advance(DUR["gamble"])
	if rng.randf() < 0.12:
		text += "\n\nVợ biết chuyện bạn đi đánh bạc."
		lines.append_array(apply({"wife": -15, "flag": "wife_knows_gamble"}))
	return {"text": text, "lines": lines}


func gray_job() -> Dictionary:
	var text: String = ""
	var eff: Dictionary = {}
	if rng.randf() < 0.25:
		text = "Việc đổ bể. Bạn bị chặn đường, mất cả tiền công lẫn một ít sức khỏe."
		eff = {"health": -20, "mood": -8, "money": -500000}
	else:
		text = "Bạn chạy xong việc và nhận phong bì. Không ai hỏi gì, bạn cũng không muốn biết bên trong là gì."
		eff = {"money": rng.randi_range(1_500_000, 3_000_000), "mood": -3, "danger": 3}
	var lines: Array = apply(eff)
	flags["gray_job"] = true
	advance(DUR["gray"])
	if rng.randf() < 0.15:
		text += "\n\nVợ thấy bạn về muộn, người dính bụi, và bắt đầu nghi ngờ."
		lines.append_array(apply({"wife": -12}))
	return {"text": text, "lines": lines}


func take_loan() -> Dictionary:
	var amount: int = 10_000_000
	money += amount
	debt_total += int(float(amount) * 1.3)
	loan_taken += amount
	flags["loan_shark"] = true
	advance(DUR["loan"])
	var lines: Array = apply({"danger": 8})
	lines.insert(0, "Tiền +%s, nợ tăng %s (lãi 30%%)" % [fmt_money(amount), fmt_money(int(float(amount) * 1.3))])
	return {"text": "Gã cho vay đếm tiền và nhìn bạn bằng nụ cười lạnh: \"Nhớ trả đủ nhé.\"", "lines": lines}


func pay_debt(amount: int) -> int:
	var a: int = mini(amount, mini(money, remaining_debt()))
	if a <= 0:
		return 0
	money -= a
	paid += a
	say("Đã trả nợ %s" % fmt_money(a))
	if remaining_debt() <= 0:
		_evaluate_end()
	changed.emit()
	return a


func eat(kind: String) -> Dictionary:
	var cost: int = 0
	var eff: Dictionary = {}
	var text: String = ""
	match kind:
		"noodle":
			cost = 15_000
			eff = {"hunger": 30, "mood": -1}
			text = "Một gói mì tôm nấu vội ở nhà. Đỡ đói, không hơn."
		"water":
			cost = 0
			eff = {"thirst": 40}
			text = "Bạn uống một cốc nước lọc mát lạnh."
		"drink":
			cost = 15_000
			eff = {"thirst": 60, "mood": 2}
			text = "Một ly trà đá vỉa hè. Mát cả người."
		"cheap":
			cost = 50_000
			eff = {"hunger": 45, "thirst": 15, "health": 3, "mood": 2}
			text = "Một tô mì bình dân. No bụng, vậy là đủ."
		"good":
			cost = 300_000
			eff = {"hunger": 75, "thirst": 25, "health": 8, "mood": 8}
			text = "Bạn gọi một bữa ra trò. Lâu lắm mới thấy dễ chịu."
		"date":
			cost = 600_000
			eff = {"hunger": 65, "thirst": 25, "health": 5, "mood": 5, "wife": 10}
			text = "Bạn rủ vợ đi ăn. Cô ấy cười nhiều hơn bạn nghĩ."
	if money < cost:
		return {"text": "Bạn không đủ tiền cho bữa này.", "lines": [], "ok": false}
	money -= cost
	var lines: Array = apply(eff)
	if cost > 0:
		lines.insert(0, "Tiền -%s" % fmt_money(cost))
	var d: String = "eat_out"
	if kind == "noodle" or kind == "water":
		d = kind
	elif kind == "drink":
		d = "water"
	advance(DUR[d])
	return {"text": text, "lines": lines, "ok": true}


func wife_line() -> String:
	var key: String = "low" if wife < 30 else ("mid" if wife < 65 else "high")
	var all: Dictionary = data.get("wife_lines", {})
	var arr: Array = all.get(key, [])
	if arr.is_empty():
		return "Vợ nhìn bạn và mỉm cười."
	return str(arr.pick_random())


func wife_home() -> bool:
	return minutes >= float(WIFE_HOME) or minutes < float(WIFE_LEAVE)


func wife_asleep() -> bool:
	return minutes >= float(WIFE_SLEEP) or minutes < float(WIFE_LEAVE)


## Nói chuyện với vợ: không tốn thời gian, tối đa 3 lần/ngày, mỗi lần +3 tình cảm
func talk_wife() -> Dictionary:
	if talks_today >= WIFE_TALK_MAX:
		return {"text": "Vợ cười: \"Hôm nay nói nhiều rồi, anh đi làm việc đi.\"", "lines": []}
	talks_today += 1
	var arr: Array = data.get("wife_talk", [])
	var text: String = str(arr.pick_random()) if arr.size() > 0 else wife_line()
	var lines: Array = apply({"wife": WIFE_TALK_GAIN})
	return {"text": text, "lines": lines}


func eat_dinner() -> Dictionary:
	dinner_eaten = true
	var lines: Array = apply({"hunger": 100, "thirst": 100, "mood": 3})
	advance(20)
	return {"text": "Cơm canh còn ấm. Bạn ăn hết sạch, no căng bụng.", "lines": lines}


## Bị trấn lột: mất ROB_RATE số tiền mặt đang có
func rob() -> int:
	var amt: int = int(float(money) * ROB_RATE)
	money -= amt
	today["robbed"] = int(today.get("robbed", 0)) + amt
	changed.emit()
	return amt


# ---------------------------------------------------------------- đồ stream

func pcs() -> Array:
	return items_db.get("pcs", [])


func pc_name() -> String:
	var p: Array = pcs()
	if pc_level - 1 < p.size():
		return str(p[pc_level - 1]["name"]).replace(" (đang dùng)", "")
	return "Máy Lv%d" % pc_level


func pc_view_bonus() -> float:
	var p: Array = pcs()
	if pc_level - 1 < p.size():
		return float(p[pc_level - 1]["view"]) / 100.0
	return 0.0


## Tổng % cộng thêm từ đồ stream đã mua. key: "view" hoặc "donate"
func gear_bonus(key: String) -> float:
	var all: Dictionary = items_db.get("gear", {})
	var t: float = 0.0
	for id in gear.keys():
		if all.has(id):
			t += float(all[id].get(key, 0))
	return t / 100.0


func buy_pc_tier(tier: int) -> Dictionary:
	var p: Array = pcs()
	if tier <= pc_level or tier > p.size():
		return {"ok": false, "text": "Không mua được."}
	var cost: int = int(p[tier - 1]["price"])
	if money < cost:
		return {"ok": false, "text": "Không đủ tiền."}
	money -= cost
	pc_level = tier
	pc_dur = 100.0
	changed.emit()
	return {"ok": true, "text": "Đã mua %s (-%s). Máy chạy mượt hẳn." % [str(p[tier - 1]["name"]), fmt_money(cost)]}


func buy_gear(id: String) -> Dictionary:
	var all: Dictionary = items_db.get("gear", {})
	if not all.has(id) or gear.has(id):
		return {"ok": false, "text": "Không mua được."}
	var g: Dictionary = all[id]
	if g.has("needs") and not gear.has(str(g["needs"])):
		return {"ok": false, "text": "Cần mua %s trước." % str(all[str(g["needs"])]["name"])}
	var cost: int = int(g["price"])
	if money < cost:
		return {"ok": false, "text": "Không đủ tiền."}
	money -= cost
	gear[id] = true
	changed.emit()
	return {"ok": true, "text": "Đã mua %s (-%s)." % [str(g["name"]), fmt_money(cost)]}


# ---------------------------------------------------------------- túi đồ

func item_info(id: String) -> Dictionary:
	return items_db.get("items", {}).get(id, {})


func item_name(id: String) -> String:
	return str(item_info(id).get("name", id))


func count_item(id: String) -> int:
	var n: int = 0
	for s in inventory:
		if not s.is_empty() and str(s["id"]) == id:
			n += int(s["count"])
	return n


func has_item(id: String) -> bool:
	return count_item(id) > 0


## Thêm đồ vào túi (ưu tiên cộng dồn, rồi tới ô trống). Trả về số lượng đã thêm được.
func add_item(id: String, n: int = 1) -> int:
	var info: Dictionary = item_info(id)
	if info.is_empty():
		return 0
	var first: bool = not flags.has("got_" + id)
	var stack: int = int(info.get("stack", 1))
	var left: int = n
	for s in inventory:
		if left <= 0:
			break
		if not s.is_empty() and str(s["id"]) == id and int(s["count"]) < stack:
			var put: int = mini(left, stack - int(s["count"]))
			s["count"] = int(s["count"]) + put
			left -= put
	for i in inventory.size():
		if left <= 0:
			break
		if inventory[i].is_empty():
			var put2: int = mini(left, stack)
			inventory[i] = {"id": id, "count": put2}
			left -= put2
	var added: int = n - left
	if added > 0:
		flags["got_" + id] = true
		changed.emit()
		if first:
			item_first.emit(id)
	return added


func remove_item(id: String, n: int = 1) -> bool:
	if count_item(id) < n:
		return false
	var left: int = n
	for i in range(inventory.size() - 1, -1, -1):
		var s: Dictionary = inventory[i]
		if left <= 0:
			break
		if not s.is_empty() and str(s["id"]) == id:
			var take: int = mini(left, int(s["count"]))
			s["count"] = int(s["count"]) - take
			left -= take
			if int(s["count"]) <= 0:
				inventory[i] = {}
	changed.emit()
	return true


func selected_id() -> String:
	var s: Dictionary = inventory[selected]
	return "" if s.is_empty() else str(s["id"])


func select_slot(i: int) -> void:
	selected = clampi(i, 0, HOTBAR - 1)
	changed.emit()


## Kéo đồ từ ô a sang ô b: cùng loại thì cộng dồn, khác loại thì đổi chỗ
func move_slot(a: int, b: int) -> void:
	if a == b:
		return
	var sa: Dictionary = inventory[a]
	var sb: Dictionary = inventory[b]
	if not sa.is_empty() and not sb.is_empty() and str(sa["id"]) == str(sb["id"]):
		var stack: int = int(item_info(str(sa["id"])).get("stack", 1))
		var put: int = mini(int(sa["count"]), stack - int(sb["count"]))
		if put > 0:
			sb["count"] = int(sb["count"]) + put
			sa["count"] = int(sa["count"]) - put
			if int(sa["count"]) <= 0:
				inventory[a] = {}
			changed.emit()
			return
	swap_slots(a, b)


## Đổi chỗ hai ô trong túi (dùng để đưa đồ lên thanh nhanh)
func swap_slots(a: int, b: int) -> void:
	var t: Dictionary = inventory[a]
	inventory[a] = inventory[b]
	inventory[b] = t
	changed.emit()


## Dùng món đang cầm (ăn, uống). Trả về {"ok", "text", "lines"}
func use_selected() -> Dictionary:
	var id: String = selected_id()
	if id == "":
		return {"ok": false, "text": "Tay đang trống."}
	var info: Dictionary = item_info(id)
	if not info.has("use"):
		var t: String = item_name(id) + ": không dùng trực tiếp được."
		if str(info.get("type", "")) == "jewelry":
			t += " Bán ở tiệm vàng bạc, hoặc tặng vợ."
		elif str(info.get("type", "")) == "tool":
			t += " " + str(info.get("desc", ""))
		else:
			t += " Có thể bán cho chú Tư ve chai."
		return {"ok": false, "text": t}
	remove_item(id, 1)
	var lines: Array = apply(info["use"])
	advance(5)
	var verb: String = "Bạn uống" if str(info.get("type", "")) == "drink" else "Bạn ăn"
	return {"ok": true, "text": "%s %s." % [verb, item_name(id).to_lower()], "lines": lines}


func buy_item(id: String) -> Dictionary:
	var info: Dictionary = item_info(id)
	var cost: int = int(info.get("buy", 0))
	if money < cost:
		return {"ok": false, "text": "Không đủ tiền."}
	if add_item(id, 1) <= 0:
		return {"ok": false, "text": "Túi đồ đã đầy."}
	money -= cost
	changed.emit()
	return {"ok": true, "text": "Đã mua %s (-%s)." % [item_name(id), fmt_money(cost)]}


func sell_items(id: String, n: int) -> Dictionary:
	n = mini(n, count_item(id))
	if n <= 0:
		return {"ok": false, "text": "Không có món này."}
	var price: int = int(item_info(id).get("sell", 0))
	remove_item(id, n)
	money += price * n
	today["other"] = int(today.get("other", 0)) + price * n
	changed.emit()
	return {"ok": true, "text": "Bán %d %s, nhận %s." % [n, item_name(id).to_lower(), fmt_money(price * n)]}


## Bán hết ve chai (chai nhựa, vỏ lon, giấy, sắt vụn...)
func sell_all_junk() -> Dictionary:
	var total: int = 0
	var n: int = 0
	for id in items_db.get("items", {}).keys():
		if str(item_info(id).get("type", "")) == "junk":
			var c: int = count_item(id)
			if c > 0:
				total += c * int(item_info(id).get("sell", 0))
				n += c
				remove_item(id, c)
	money += total
	today["other"] = int(today.get("other", 0)) + total
	changed.emit()
	if n == 0:
		return {"ok": false, "text": "Không có ve chai để bán."}
	return {"ok": true, "text": "Bán %d món ve chai, nhận %s." % [n, fmt_money(total)]}


func gift_wife(id: String) -> Dictionary:
	var info: Dictionary = item_info(id)
	if not remove_item(id, 1):
		return {"text": "Bạn không có món này.", "lines": []}
	var g: int = int(info.get("gift", 5))
	var lines: Array = apply({"wife": g, "mood": 4})
	advance(10)
	var text: String = "Bạn đưa %s cho vợ. " % item_name(id).to_lower()
	if g >= 14:
		text += "Cô ấy sững lại, rồi ôm chầm lấy bạn. \"Anh lấy đâu ra vậy?\""
	else:
		text += "Cô ấy mỉm cười, đeo thử ngay. \"Đẹp đấy, cảm ơn anh.\""
	return {"text": text, "lines": lines}


## Cạy khóa cổng công trường bỏ hoang
func pick_lock() -> Dictionary:
	if not has_item("lockpick"):
		return {"ok": false, "text": "Bạn cần một chiếc lockpick."}
	advance(15)
	if rng.randf() < 0.6:
		flags["site_open"] = true
		changed.emit()
		return {"ok": true, "text": "Tách! Ổ khóa rỉ sét bật ra. Cánh cổng công trường hé mở."}
	var text: String = "Ổ khóa kẹt cứng, bạn loay hoay mãi không được."
	if rng.randf() < 0.5:
		remove_item("lockpick", 1)
		text += " Chiếc lockpick gãy đôi trong tay."
	return {"ok": false, "text": text}


func repair_cost() -> int:
	if flags.has("smashed"):
		return REPAIR_SMASH_RUDE if flags.has("creditor_rude") else REPAIR_SMASH
	return 800_000


func repair_pc() -> Dictionary:
	var cost: int = repair_cost()
	if money < cost:
		return {"ok": false, "text": "Không đủ tiền sửa máy."}
	money -= cost
	if flags.has("smashed"):
		flags.erase("smashed")
		pc_dur = 70.0
		changed.emit()
		return {"ok": true, "text": "Đã sửa lại góc stream bị đập phá (-%s). Stream lại được rồi." % fmt_money(cost)}
	pc_dur = minf(100.0, pc_dur + 40.0)
	changed.emit()
	return {"ok": true, "text": "Đã sửa máy (-%s, độ bền +40)." % fmt_money(cost)}


## Chủ nợ đến nhà thu tiền theo lịch. Tự lấy tiền mặt; thiếu thì đập phá góc stream.
func creditor_collect() -> Dictionary:
	var need: int = int(MILESTONES.get(day, 0)) - paid
	var res: Dictionary = {"need": maxi(0, need), "paid": 0, "short": 0}
	if need <= 0:
		danger = clampi(danger - 10, 0, 100)
		changed.emit()
		return res
	var a: int = mini(need, money)
	if a > 0:
		money -= a
		paid += a
	res["paid"] = a
	res["short"] = need - a
	if need - a > 0:
		flags["smashed"] = true
		pc_dur = 0.0
		danger = clampi(danger + 15, 0, 100)
		apply({"wife": -8, "mood": -10})
	else:
		danger = clampi(danger - 10, 0, 100)
	changed.emit()
	return res


## Ngày 46: bán giọng nói và khuôn mặt cho công ty AI
func ai_deal(sell: bool) -> void:
	if sell:
		flags["sold_to_ai"] = true
		money += AI_DEAL_MONEY
		today["other"] = int(today.get("other", 0)) + AI_DEAL_MONEY
	else:
		flags["refused_ai"] = true
	changed.emit()


# ---------------------------------------------------------------- công trường

func site_caught() -> Dictionary:
	var n: int = int(flags.get("site_caught", 0)) + 1
	flags["site_caught"] = n
	var text: String = ""
	if n == 1:
		var lost: Array = []
		if remove_item("copper_coil", count_item("copper_coil")):
			lost.append("cuộn dây đồng")
		text = "Bảo vệ tóm được bạn, quát tháo rồi tống cổ ra ngoài cổng. Đồ lấy được bị tịch thu%s.\nLần sau bị bắt sẽ bị phạt tiền." % ((": " + ", ".join(PackedStringArray(lost))) if lost.size() > 0 else "")
	elif n == 2:
		remove_item("copper_coil", count_item("copper_coil"))
		var fine: int = mini(SITE_FINE, money)
		money -= fine
		today["robbed"] = int(today.get("robbed", 0)) + fine
		text = "Lại là cậu à? Bảo vệ lập biên bản, bạn bị phạt %s. Đồ lấy được bị tịch thu.\nLần thứ ba bị bắt là bị giao cho công an." % fmt_money(fine)
	else:
		finish("jail")
		text = "Lần thứ ba bị bắt quả tang. Bảo vệ gọi công an."
	changed.emit()
	return {"n": n, "text": text}


## Đào vụn dây đồng trong công trường (sau khi đã lấy được cuộn dây đồng)
func dig_site() -> Dictionary:
	advance(30)
	scav_today += 1
	var r: float = rng.randf()
	var id: String = "copper_s" if r < 0.55 else ("copper_m" if r < 0.88 else "copper_l")
	if add_item(id, 1) <= 0:
		return {"text": "Túi đồ đã đầy.", "lines": []}
	return {"text": "Bạn đào bới đống phế liệu, gỡ ra được %s." % item_name(id).to_lower(), "lines": ["+1 " + item_name(id)]}


func rent_new_house() -> Dictionary:
	if new_house:
		return {"ok": false, "text": "Bạn đã thuê nhà mới rồi."}
	if money < NEW_HOUSE_DEPOSIT:
		return {"ok": false, "text": "Không đủ tiền đặt cọc."}
	money -= NEW_HOUSE_DEPOSIT
	new_house = true
	changed.emit()
	return {"ok": true, "text": "Đã thuê nhà mới (-%s tiền cọc). Studio rộng hơn nhiều, tiền nhà các tháng sau là %s/tháng." % [fmt_money(NEW_HOUSE_DEPOSIT), fmt_money(RENT_NEW)]}


func do_trash() -> Dictionary:
	advance(DUR["trash"])
	scav_today += 1
	return roll_list("trash")


## Bới đụn rác / đụn lá trên vỉa hè: ra tiền (mệnh giá VNĐ), đồ vật, hoặc bốc phải phân.
## Tỉ lệ chỉnh trong data/items.json ("dig_outcome", "money_drops", "drop_trash"/"drop_leaves").
func dig_pile(kind: String) -> Dictionary:
	advance(DUR["pile"])
	scav_today += 1
	var title: String = "Bới rác" if kind == "trash" else "Bới lá"
	var oc: Dictionary = items_db.get("dig_outcome", {}).get(kind, {"nothing": 1})
	var outcome: String = str(_pick_key(oc))
	match outcome:
		"poop":
			var r: Dictionary = roll_list("poop_pile")
			r["title"] = "Xấu số!"
			return r
		"money":
			var drops: Array = items_db.get("money_drops", [[1000, 1]])
			var wsum: float = 0.0
			for d in drops:
				wsum += float(d[1])
			var x: float = rng.randf() * wsum
			var amt: int = int(drops[0][0])
			for d in drops:
				x -= float(d[1])
				if x <= 0.0:
					amt = int(d[0])
					break
			var t: String = "Bạn tìm thấy một tờ %s nhàu nát!" % fmt_money(amt)
			if amt >= 200000:
				t = "Trời ơi, một tờ %s nằm lẫn trong đó! Hôm nay may thật." % fmt_money(amt)
			var lines: Array = apply({"money": amt, "mood": 3 if amt >= 100000 else 1})
			return {"title": title, "text": t, "lines": lines}
		"item":
			var key: String = "drop_" + kind
			var pool: Dictionary = {}
			var all: Dictionary = items_db.get("items", {})
			for id in all.keys():
				var w: float = float(all[id].get(key, 0))
				if w > 0.0:
					pool[id] = w
			var id2: String = str(_pick_key(pool))
			var nm: String = item_name(id2)
			if add_item(id2, 1) <= 0:
				return {"title": title, "text": "Bạn tìm thấy %s nhưng túi đồ đã đầy, đành bỏ lại." % nm.to_lower(), "lines": []}
			var t2: String = "Bạn nhặt được: %s." % nm
			if str(item_info(id2).get("type", "")) == "jewelry":
				t2 = "Có thứ gì lấp lánh... là %s! Có thể bán, hoặc mang về tặng vợ." % nm.to_lower()
			return {"title": title, "text": t2, "lines": ["+1 " + nm]}
	var empty_txt: String = "Toàn rác bẩn, chẳng có gì giá trị." if kind == "trash" else "Toàn lá khô với lá khô."
	return {"title": title, "text": empty_txt, "lines": apply({"mood": -1})}


func _pick_key(weights: Dictionary) -> Variant:
	var total: float = 0.0
	for k in weights.keys():
		total += float(weights[k])
	var x: float = rng.randf() * total
	for k in weights.keys():
		x -= float(weights[k])
		if x <= 0.0:
			return k
	return weights.keys()[0]


# ---------------------------------------------------------------- hết ngày

## Ngủ (hoặc ngất) -> sang sáng hôm sau 07:00. passed_out = thức quá 02:00.
func day_summary() -> Array:
	var t: Dictionary = today
	var out: Array = []
	var stream_inc: int = int(t.get("donate", 0)) + int(t.get("ads", 0))
	if streamed_today:
		out.append("Stream %.1f tiếng: đông nhất %d người xem  ·  donate %s  ·  quảng cáo %s  ·  +%d follower" % [float(t.get("stream_min", 0)) / 60.0, int(t.get("viewers", 0)), fmt_money(int(t.get("donate", 0))), fmt_money(int(t.get("ads", 0))), int(t.get("followers", 0))])
	else:
		out.append("Hôm nay không stream.")
	out.append("Thu nhập khác (bới nhặt, bán đồ, sự kiện...): %s" % fmt_money(int(t.get("other", 0))))
	if int(t.get("robbed", 0)) > 0:
		out.append("Bị trấn lột / mất: -%s" % fmt_money(int(t.get("robbed", 0))))
	out.append("TỔNG THU NHẬP HÔM NAY: %s" % fmt_money(stream_inc + int(t.get("other", 0))))
	out.append("Tiền mặt: %s  ·  Nợ còn: %s" % [fmt_money(money), fmt_money(remaining_debt())])
	return out


# ---------------------------------------------------------------- lưu game (3 ô)

const SAVE_KEYS: Array = ["day", "minutes", "money", "wife", "health", "mood", "danger", "debt_total", "paid",
	"followers", "pc_level", "pc_dur", "gear", "new_house", "flags", "inventory", "selected", "rent_owed",
	"hunger", "thirst", "total_stream_income", "loan_taken", "last_viewers", "forced_event", "last_event",
	"scav_today", "talks_today", "wife_cooked", "wife_met_today", "dinner_eaten", "streamed_today", "today",
	"stream_min_today", "awake_min", "collapses", "warned_awake"]


func _save_path(slot: int) -> String:
	return "user://save_%d.json" % slot


func save_game(slot: int, extra: Dictionary) -> bool:
	var d: Dictionary = {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	d["extra"] = extra
	d["meta"] = {"day": day, "clock": clock_str(), "money": money, "debt": remaining_debt(), "saved_at": Time.get_datetime_string_from_system(false, true)}
	var f: FileAccess = FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


func slot_info(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_save_path(slot)):
		return {}
	var f: FileAccess = FileAccess.open(_save_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		return d.get("meta", {})
	return {}


func slot_label(slot: int) -> String:
	var m: Dictionary = slot_info(slot)
	if m.is_empty():
		return "Ô %d: (trống)" % slot
	return "Ô %d: Ngày %d, %s · tiền %s · nợ còn %s · lưu lúc %s" % [slot, int(m.get("day", 1)), str(m.get("clock", "")),
		fmt_money(int(m.get("money", 0))), fmt_money(int(m.get("debt", 0))), str(m.get("saved_at", ""))]


## Nạp dữ liệu từ ô lưu vào trạng thái hiện tại. Trả về phần "extra" (vị trí người chơi...).
func load_game(slot: int) -> Dictionary:
	if not FileAccess.file_exists(_save_path(slot)):
		return {}
	var f: FileAccess = FileAccess.open(_save_path(slot), FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		return {}
	var ints: Array = ["day", "money", "wife", "health", "mood", "danger", "debt_total", "paid", "pc_level",
		"selected", "rent_owed", "total_stream_income", "loan_taken", "last_viewers", "scav_today", "talks_today", "collapses"]
	for k in SAVE_KEYS:
		if d.has(k):
			var v: Variant = d[k]
			if k in ints:
				v = int(v)
			set(k, v)
	# JSON trả số thực: chuẩn hóa túi đồ và thống kê
	var inv: Array = []
	for sl in inventory:
		if sl is Dictionary and not sl.is_empty():
			inv.append({"id": str(sl["id"]), "count": int(sl["count"])})
		else:
			inv.append({})
	while inv.size() < INV_SIZE:
		inv.append({})
	inventory = inv
	for k in today.keys():
		today[k] = int(today[k])
	finished = false
	ending_id = ""
	pending_rollovers = []
	morning_pending = false
	wife_leave_pending = false
	warn_pending = false
	collapse_pending = false
	midnight_pending = false
	night_warn_pending = false
	_update_slot()
	changed.emit()
	return d.get("extra", {})
