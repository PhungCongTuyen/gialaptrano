extends Node3D
## Dựng đoạn phố 3D, hai căn phòng và toàn bộ menu tương tác.
## Mọi thứ được tạo bằng code (khối hộp đơn giản) để dễ chỉnh và thay model sau này.

const OLD_ORIGIN: Vector3 = Vector3(300, 0, 0)
const NEW_ORIGIN: Vector3 = Vector3(400, 0, 0)
const OLD_SIZE: Vector3 = Vector3(6, 2.8, 5)
const NEW_SIZE: Vector3 = Vector3(10, 3.2, 8)
const OFFICE_ORIGIN: Vector3 = Vector3(500, 0, 0)
const OFFICE_SIZE: Vector3 = Vector3(12, 3.0, 9)
const BOSS_ORIGIN: Vector3 = Vector3(600, 0, 0)
const BOSS_SIZE: Vector3 = Vector3(8, 3.0, 6)

var player  # CharacterBody3D (scripts/player.gd)
var town  # Node3D (scripts/town.gd): dựng nhà ống, cột điện, xe máy...
var hud  # CanvasLayer (scripts/hud.gd)
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var env: Environment
var lamps: Array = []
var piles: Array = []  # đụn rác / đụn lá trên vỉa hè
var street_items: Node3D
var exit_pos: Vector3 = Vector3.ZERO
var exit_yaw: float = 0.0
var in_room: bool = true
# Intro (văn phòng -> phòng giám đốc)
var intro_took_report: bool = false
var office_report: StaticBody3D
var boss_paper: StaticBody3D
var linh: Node3D
## Đồng hồ chỉ chạy khi đã vào game thật (sau intro và mở đầu ngày 1)
var game_live: bool = false
var wives: Array = []        # mô hình vợ trong phòng trọ và nhà mới
var creditor_npc: Node3D     # chủ nợ đứng trước cửa (ngày 1)
var site_gate: StaticBody3D  # cổng khóa khu công trường
var trays: Array = []        # mâm cơm vợ nấu (phòng trọ, nhà mới)
var junk_npc: Node3D
var walkers: Array = []      # người đi đường (đi cả trên mặt đường, vào quán ăn, tiệm vàng)
var groups: Array = []       # các nhóm người đứng nói chuyện
var group_period: String = ""
var robbers: Array = []      # trấn lột sau 23:00
var stream_kind: String = "game"
var stream_res: Dictionary = {}
var stream_rest: float = 0.0   # số giờ stream còn lại sau cảnh 23:00
var ending_shown: bool = false
# Công trường
var site_c: Vector3
var site_w: float = 0.0
var site_d: float = 0.0
var gate_guard: Node3D        # bảo vệ đứng cổng (trước ngày 37)
var patrol_guard: Node3D      # bảo vệ tuần tra bên trong (từ ngày 37 tới khi lấy được cuộn dây đồng)
var patrol_pts: Array = []
var patrol_i: int = 0
var patrol_phase: float = 0.0
var detect: float = 0.0
var coil_node: StaticBody3D
var site_digs: Array = []
var linh_npc: StaticBody3D
var warned_hunger: bool = false
var warned_thirst: bool = false

var time_sets: Array = [
	{"bg": Color(0.55, 0.72, 0.92), "amb": Color(0.8, 0.82, 0.9), "amb_e": 0.8, "sun": 1.0, "lamp": 0.0},
	{"bg": Color(0.6, 0.78, 0.95), "amb": Color(0.85, 0.88, 0.95), "amb_e": 0.9, "sun": 1.2, "lamp": 0.0},
	{"bg": Color(0.95, 0.62, 0.4), "amb": Color(0.9, 0.7, 0.55), "amb_e": 0.7, "sun": 0.8, "lamp": 0.6},
	{"bg": Color(0.04, 0.05, 0.12), "amb": Color(0.25, 0.28, 0.45), "amb_e": 0.6, "sun": 0.1, "lamp": 2.2},
]


func _ready() -> void:
	GameState.reset()
	_build_environment()
	town = preload("res://scripts/town.gd").new()
	add_child(town)
	street_items = Node3D.new()
	add_child(street_items)
	_build_street()
	_build_room(OLD_ORIGIN, OLD_SIZE, false)
	_build_room(NEW_ORIGIN, NEW_SIZE, true)
	_build_office()
	_build_boss_room()

	var ps: GDScript = preload("res://scripts/player.gd")
	player = ps.new()
	add_child(player)
	var hs: GDScript = preload("res://scripts/hud.gd")
	hud = hs.new()
	add_child(hud)
	player.interact.connect(_on_interact)
	hud.use_requested.connect(_use_item)
	GameState.item_first.connect(_on_item_first)
	hud.pause_requested.connect(_menu_pause)
	_build_npcs()
	GameState.changed.connect(_apply_time)

	_apply_time()
	if GameState.pending_load > 0:
		var slot: int = GameState.pending_load
		GameState.pending_load = 0
		_resume_from_save(GameState.load_game(slot))
	else:
		_show_title()


func _process(delta: float) -> void:
	player.locked = hud.menu_open or hud.fading or hud.inv_open or hud.live_open
	var free: bool = game_live and not hud.menu_open and not hud.fading and not hud.inv_open and not hud.live_open and not GameState.finished
	if free:
		GameState.tick(delta)
		_check_needs()
		_update_world()
		_move_walkers(delta)
		_check_first_meet()
		_check_robbers()
		_update_site(delta)
		_poll_state()
	_update_watch()
	var label: String = ""
	if is_instance_valid(player.target) and not hud.menu_open and not hud.inv_open:
		label = str(player.target.get_meta("label", ""))
	hud.set_prompt(label)


func _update_watch() -> void:
	var g = GameState
	var hungry: int = 100 - int(g.hunger)
	var thirsty: int = 100 - int(g.thirst)
	player.set_watch("%s  N%d\nĐói  %d%%\nKhát %d%%" % [g.clock_str(), g.day, hungry, thirsty])


## Nhắc khi bắt đầu đói / khát (mỗi lần xuống ngưỡng nhắc một lần)
func _check_needs() -> void:
	var g = GameState
	if g.hunger < 30.0 and not warned_hunger:
		warned_hunger = true
		hud.toast("Bụng bắt đầu sôi... Bạn đói rồi (xem đồng hồ: Q)", 3.5)
	elif g.hunger >= 40.0:
		warned_hunger = false
	if g.thirst < 30.0 and not warned_thirst:
		warned_thirst = true
		hud.toast("Cổ họng khô rát... Bạn khát nước rồi", 3.5)
	elif g.thirst >= 40.0:
		warned_thirst = false


## Hiện những gì GameState xếp hàng: kết thúc, gục ngã, qua 0h, vợ chào đi làm, sự kiện sáng, cảnh báo
func _poll_state() -> void:
	var g = GameState
	if hud.menu_open or hud.fading or not game_live:
		return
	if g.finished:
		_show_ending()
		return
	if g.midnight_pending:
		game_live = false
		hud.set_hint("")
		hud.transition(_midnight_mid, 1.2)
		return
	if g.night_warn_pending:
		g.night_warn_pending = false
		if not in_room:
			var t: String = "Đã 23:30. Về nhà trước 00:00! Nửa đêm còn ở ngoài đường sẽ bị mất 5% số tiền mang theo."
			hud.show_menu("SẮP NỬA ĐÊM", t, [{"label": "Về nhà ngay", "cb": _noop}], "Đã mười một giờ rưỡi. Về nhà trước nửa đêm.", "night_warn")
			return
		hud.toast("23:30 rồi. 00:00 sẽ tự đi ngủ.", 3.0)
	if not g.pending_rollovers.is_empty():
		var r: Dictionary = g.pending_rollovers.pop_front()
		_spawn_street_items()
		hud.show_menu("THỐNG KÊ NGÀY %d" % int(r["day"]), "\n".join(PackedStringArray(r["lines"])), [{"label": "Sang ngày %d" % (int(r["day"]) + 1), "cb": _show_new_day_card}])
		return
	if g.wife_leave_pending:
		g.wife_leave_pending = false
		if in_room:
			var arr: Array = g.data.get("wife_leave", [])
			var t: String = str(arr.pick_random()) if arr.size() > 0 else "Em đi làm đây."
			_say("Vợ  ·  07:00", t, _noop, "")
			return
	if g.morning_pending:
		g.morning_pending = false
		var ev: Dictionary = g.roll_morning_event()
		if not ev.is_empty():
			_show_event(ev, "NGÀY %d" % g.day)
			return
	if _story_poll():
		return
	if g.warn_pending:
		g.warn_pending = false
		var w: String = "Bạn sắp ngất rồi, cần nghỉ ngơi. Bạn đã thức gần 2 ngày. Về nhà ngủ ngay (sẽ ngủ 12 tiếng), nếu không bạn sẽ gục và mất trọn một ngày."
		hud.show_menu("CẢNH BÁO", w, [{"label": "Đã hiểu", "cb": _noop}], "Bạn sắp ngất rồi, cần nghỉ ngơi.", "warn_awake")


func _show_new_day_card() -> void:
	hud.show_day_card(GameState.day, GameState.TOTAL_DAYS)


func _resume_play() -> void:
	game_live = true


## 00:00: cắt cảnh, ngủ đến 06:00. Còn ở ngoài đường thì mất 5% tiền.
func _midnight_mid() -> void:
	var outside: bool = not in_room
	_clear_robbers()
	_enter_room(GameState.new_house)
	_reset_wives()
	var lines: Array = GameState.night_sleep(outside)
	_show_night_panel(lines, outside)


## Gộp bảng thống kê ngày cũ với phần ngủ đêm
func _show_night_panel(sleep_lines: Array, outside: bool) -> void:
	var g = GameState
	var lines: Array = []
	var title: String = "Ngày mới · %s" % g.clock_str()
	if not g.pending_rollovers.is_empty():
		var r: Dictionary = g.pending_rollovers.pop_front()
		title = "HẾT NGÀY %d" % int(r["day"])
		lines.append_array(r["lines"])
		lines.append("")
	lines.append_array(sleep_lines)
	if outside:
		title += "  ·  KHÔNG VỀ NHÀ KỊP"
	_spawn_street_items()
	hud.show_menu(title, "\n".join(PackedStringArray(lines)), [{"label": "Sang ngày %d" % g.day, "cb": _night_done}])


func _night_done() -> void:
	game_live = true
	hud.show_day_card(GameState.day, GameState.TOTAL_DAYS)


func _after_collapse() -> void:
	game_live = true
	if GameState.finished:
		_show_ending()


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# ====================================================================== dựng thế giới

func _build_environment() -> void:
	env = Environment.new()
	var sky: Sky = Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.75, 0.72, 0.68)
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_density = 0.0025
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


## Trời sáng/tối liên tục theo giờ: mặt trời, màu trời, đèn đường, đèn cửa sổ, biển hiệu
func _apply_time() -> void:
	if env == null:
		return
	var h: float = GameState.minutes / 60.0
	# 0 = ban ngày, 1 = đêm
	var night: float = 0.0
	if h >= 17.5 and h < 19.5:
		night = (h - 17.5) / 2.0
	elif h >= 19.5 or h < 5.0:
		night = 1.0
	elif h >= 5.0 and h < 6.5:
		night = 1.0 - (h - 5.0) / 1.5
	var dusk: float = clampf(1.0 - absf(h - 18.0) / 1.5, 0.0, 1.0) + clampf(1.0 - absf(h - 6.0) / 1.2, 0.0, 1.0)
	var elev: float = clampf((h - 6.0) / 12.0, 0.0, 1.0) * 180.0
	sun.rotation_degrees = Vector3(-maxf(elev, 8.0) if elev < 90.0 else -(180.0 - maxf(180.0 - elev, 8.0)), -40.0 + elev * 0.3, 0)
	sun.light_energy = lerpf(1.05, 0.0, night)
	sun.light_color = Color(1.0, 0.95, 0.88).lerp(Color(1.0, 0.6, 0.35), dusk)
	var day_top: Color = Color(0.28, 0.52, 0.85)
	var day_hor: Color = Color(0.72, 0.82, 0.92)
	var dusk_hor: Color = Color(0.98, 0.6, 0.38)
	var night_top: Color = Color(0.02, 0.03, 0.08)
	var night_hor: Color = Color(0.08, 0.09, 0.16)
	sky_mat.sky_top_color = day_top.lerp(night_top, night)
	sky_mat.sky_horizon_color = day_hor.lerp(dusk_hor, clampf(dusk, 0.0, 1.0) * (1.0 - night * 0.6)).lerp(night_hor, night)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color(0.2, 0.18, 0.16).lerp(Color(0.02, 0.02, 0.03), night)
	env.ambient_light_energy = lerpf(0.6, 0.25, night)
	env.fog_light_color = sky_mat.sky_horizon_color
	town.set_night(night)


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, solid: bool = true) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)
	if solid:
		var cs: CollisionShape3D = CollisionShape3D.new()
		var sh: BoxShape3D = BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
	parent.add_child(body)
	return body


func _invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


func _glow(body: Node, color: Color) -> void:
	var mi: MeshInstance3D = body.get_child(0) as MeshInstance3D
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	mi.material_override = m


func _mark(body: Node, kind: String, label: String) -> void:
	body.set_meta("interact", kind)
	body.set_meta("label", label)


func _label(parent: Node, text: String, pos: Vector3, scale_f: float = 1.0, yaw: float = 0.0) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.008 * scale_f
	l.outline_size = 10
	l.position = pos
	l.rotation = Vector3(0, yaw, 0)
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- BẢN ĐỒ KHU PHỐ
# Dựng theo ảnh bản đồ 603 x 735 px, 1 px = 0,1 m (khu phố ~60 x 73 m).
# Tọa độ trong các bảng dưới đây là pixel trên ảnh: [x0, y0, x1, y1].
const PX: float = 0.1
const MAP_W: float = 603.0
const MAP_H: float = 735.0
const ROADS: Array = [
	[171, 0, 221, 735],     # đường dọc (hẹp ~5 m)
	[171, 173, 603, 223],   # đường ngang trên
	[171, 537, 603, 587],   # đường ngang dưới
]
## Khoảng trống đi lại được (mặt đường + vỉa hè), mỗi ô là một hình chữ nhật thông thoáng.
## Người đi đường di chuyển thẳng trong một ô, chuyển ô qua phần giao nhau.
const CORRIDORS: Array = [
	[132, 0, 243, 735],     # 0: trục dọc
	[132, 130, 600, 262],   # 1: trục ngang trên
	[132, 496, 600, 622],   # 2: trục ngang dưới
]
## kind: loại tương tác ("" = nhà thường). side: mặt có cửa, hướng ra đường (e/w/n/s).
## style "site": công trường bỏ hoang (dựng riêng).
const BUILDINGS: Array = [
	{"r": [0, 0, 122, 130], "c": Color(0.0, 0.64, 0.91), "h": 7.0, "side": "e", "kind": "", "sign": ""},
	{"r": [0, 147, 123, 268], "c": Color(0.13, 0.69, 0.3), "h": 5.0, "side": "e", "kind": "food", "sign": "QUÁN ĂN", "label": "Vào quán ăn"},
	{"r": [0, 289, 128, 425], "c": Color(0.85, 0.7, 0.2), "h": 6.0, "side": "e", "kind": "jewelry_shop", "sign": "TIỆM VÀNG BẠC", "label": "Tiệm vàng bạc (mua bán trang sức)"},
	{"r": [0, 447, 128, 577], "c": Color(0.0, 0.64, 0.91), "h": 6.5, "side": "e", "kind": "", "sign": ""},
	{"r": [0, 597, 129, 720], "c": Color(0.64, 0.29, 0.64), "h": 6.0, "side": "e", "kind": "door_old", "sign": "NHÀ MÌNH", "label": "Vào nhà"},
	{"r": [275, 0, 422, 127], "c": Color(1.0, 0.5, 0.15), "h": 5.0, "side": "s", "kind": "casino", "sign": "ĐỎ ĐEN", "label": "Chỗ đỏ đen (mở từ 14:00)"},
	{"r": [458, 0, 603, 127], "c": Color(0.93, 0.11, 0.14), "h": 7.0, "side": "s", "kind": "creditor", "sign": "NHÀ CHỦ NỢ", "label": "Nhà chủ nợ (trả nợ)"},
	{"r": [268, 266, 430, 493], "c": Color(1.0, 0.95, 0.0), "h": 8.0, "side": "n", "kind": "door_new", "sign": "NHÀ CHO THUÊ", "label": "Nhà mới cho thuê"},
	{"r": [451, 264, 603, 493], "c": Color(0.5, 0.5, 0.5), "h": 9.0, "side": "n", "kind": "", "sign": "", "style": "site"},
	{"r": [265, 624, 589, 733], "c": Color(1.0, 0.68, 0.8), "h": 5.5, "side": "n", "kind": "shop", "sign": "ĐỒ MÁY TÍNH", "label": "Cửa hàng đồ máy tính"},
]

## Chỗ đứng ngay ngoài cửa mỗi nhà (để ra khỏi nhà): kind -> {"pos", "yaw"}
var door_spots: Dictionary = {}


func _m(px: float, py: float) -> Vector3:
	return Vector3((px - MAP_W / 2.0) * PX, 0.0, (py - MAP_H / 2.0) * PX)


func _build_street() -> void:
	var roads_w: Array = []
	for r in ROADS:
		var c: Vector3 = _m((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
		roads_w.append({"center": c, "size": Vector3((r[2] - r[0]) * PX, 0.04, (r[3] - r[1]) * PX)})
	town.build_ground(Vector3(MAP_W * PX, 1.0, MAP_H * PX), roads_w)
	# tường vô hình bao quanh khu phố
	var hw: float = MAP_W * PX / 2.0
	var hd: float = MAP_H * PX / 2.0
	_invisible_wall(Vector3(-hw - 0.5, 3, 0), Vector3(1, 6, hd * 2.0))
	_invisible_wall(Vector3(hw + 0.5, 3, 0), Vector3(1, 6, hd * 2.0))
	_invisible_wall(Vector3(0, 3, -hd - 0.5), Vector3(hw * 2.0, 6, 1))
	_invisible_wall(Vector3(0, 3, hd + 0.5), Vector3(hw * 2.0, 6, 1))
	for b in BUILDINGS:
		_map_building(b)
	_build_street_props()


## Cột điện, dây điện, đèn đường, xe máy dựng trước cửa, cây xanh, ghế nhựa quán ăn
func _build_street_props() -> void:
	# cột điện dọc mép đường (đèn đường gắn trên cột)
	town.build_pole_line(_m(226, 6), _m(226, 729), 14.0, Vector3(-1, 0, 0))
	town.build_pole_line(_m(240, 168), _m(598, 168), 14.0, Vector3(0, 0, 1))
	town.build_pole_line(_m(240, 592), _m(598, 592), 14.0, Vector3(0, 0, -1))
	town.build_pole_line(_m(166, 230), _m(166, 530), 15.0, Vector3(1, 0, 0))
	# xe máy dựng trước các nhà (tránh trước cửa nhà có tương tác)
	for bs in town.bike_spots:
		var p: Vector3 = bs["pos"]
		var ok: bool = true
		for k in door_spots.keys():
			if _flat_dist(p, door_spots[k]["pos"]) < 3.0:
				ok = false
		if ok:
			town.build_motorbike(Vector3(p.x, 0.0, p.z), float(bs["yaw"]))
	# cây xanh trên vỉa hè
	for p in [[150, 135], [150, 280], [150, 440], [150, 585], [300, 255], [470, 258], [580, 600], [330, 530], [520, 530]]:
		var wp: Vector3 = _m(p[0], p[1])
		var ok2: bool = true
		for k in door_spots.keys():
			if _flat_dist(wp, door_spots[k]["pos"]) < 3.0:
				ok2 = false
		if ok2:
			town.build_tree(wp)
	# bàn ghế nhựa trước quán ăn
	if door_spots.has("food"):
		var fp: Vector3 = door_spots["food"]["pos"]
		town.build_stools(Vector3(fp.x + 0.4, 0, fp.z - 3.5), PI / 2.0)
	# quán trà đá góc phố
	town.build_stools(_m(255, 240) , 0.0)


const BLOCK_SPECS: Dictionary = {
	"food": {"sign": "CƠM BÌNH DÂN • PHỞ", "sub": "Bún - Phở - Cơm tấm", "sign_bg": Color(0.8, 0.1, 0.1), "sign_fg": Color(1, 0.9, 0.2), "front": "shop", "floors": 2},
	"jewelry_shop": {"sign": "TIỆM VÀNG KIM HOA", "sub": "Mua bán vàng bạc - đá quý", "sign_bg": Color(0.75, 0.05, 0.05), "sign_fg": Color(1, 0.85, 0.3), "front": "shop", "floors": 3},
	"shop": {"sign": "LINH KIỆN MÁY TÍNH", "sub": "PC - Gaming - Livestream", "sign_bg": Color(0.1, 0.3, 0.7), "sign_fg": Color(1, 1, 1), "front": "shop", "floors": 3},
	"creditor": {"sign": "CẦM ĐỒ • CHO VAY", "sub": "Giải ngân nhanh trong ngày", "sign_bg": Color(0.12, 0.12, 0.14), "sign_fg": Color(1, 0.8, 0.2), "front": "gate", "floors": 3},
	"casino": {"sign": "CLB BIDA • GIẢI TRÍ", "sub": "Mở cửa từ 14h", "sign_bg": Color(0.25, 0.05, 0.1), "sign_fg": Color(1, 0.3, 0.3), "front": "shop", "floors": 2},
	"door_new": {"sign": "CHO THUÊ NHÀ", "sub": "Nhà rộng - LH: 0912 xxx xxx", "sign_bg": Color(0.85, 0.1, 0.1), "sign_fg": Color(1, 1, 1), "front": "gate", "floors": 3},
	"door_old": {"front": "gate", "floors": 2},
}


func _map_building(b: Dictionary) -> void:
	if str(b.get("style", "")) == "site":
		_build_site(b)
		return
	var r: Array = b["r"]
	var c: Vector3 = _m((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
	var w: float = (r[2] - r[0]) * PX
	var d: float = (r[3] - r[1]) * PX
	var side: String = str(b["side"])
	var yaw: float = 0.0
	var L: float = w
	var D: float = d
	match side:
		"e":
			yaw = PI / 2.0
			L = d
			D = w
		"w":
			yaw = -PI / 2.0
			L = d
			D = w
		"n":
			yaw = PI
		_:
			yaw = 0.0
	var kind: String = str(b["kind"])
	var spec: Dictionary = {}
	if kind != "":
		spec = BLOCK_SPECS.get(kind, {"front": "gate"}).duplicate()
		spec["kind"] = kind
	var info: Dictionary = town.build_block(c, L, D, yaw, spec)
	if kind == "" or info.is_empty():
		return
	var root: Node3D = info["root"]
	var dl: Vector3 = info["door_local"]
	# vùng tương tác vô hình ngay mặt tiền căn chính
	var door: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(maxf(1.4, float(info["width"]) * 0.7), 2.4, 0.3)
	cs.shape = sh
	door.add_child(cs)
	add_child(door)
	door.global_position = root.to_global(dl)
	door.rotation = Vector3(0, yaw, 0)
	_mark(door, kind, str(b.get("label", "")))
	door_spots[kind] = {"pos": root.to_global(Vector3(dl.x, 1.0, dl.z + 1.5)), "yaw": yaw + PI}


func _build_room(origin: Vector3, sz: Vector3, nice: bool) -> void:
	var root: Node3D = Node3D.new()
	root.position = origin
	add_child(root)
	var w: float = sz.x
	var h: float = sz.y
	var d: float = sz.z
	var wall_c: Color = Color(0.85, 0.82, 0.74) if nice else Color(0.6, 0.58, 0.52)
	_box(root, Vector3(w, 0.2, d), Vector3(0, -0.1, 0), Color(0.45, 0.35, 0.28))
	_box(root, Vector3(w, 0.2, d), Vector3(0, h + 0.1, 0), Color(0.9, 0.9, 0.9))
	_box(root, Vector3(w, h, 0.2), Vector3(0, h / 2.0, -d / 2.0), wall_c)
	_box(root, Vector3(w, h, 0.2), Vector3(0, h / 2.0, d / 2.0), wall_c)
	_box(root, Vector3(0.2, h, d), Vector3(-w / 2.0, h / 2.0, 0), wall_c)
	_box(root, Vector3(0.2, h, d), Vector3(w / 2.0, h / 2.0, 0), wall_c)

	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0, h - 0.4, 0)
	lamp.omni_range = 14.0
	lamp.light_energy = 1.4
	lamp.light_color = Color(1.0, 0.92, 0.78)
	root.add_child(lamp)

	var bed: StaticBody3D = _box(root, Vector3(2.0, 0.5, 1.0), Vector3(-w / 2.0 + 1.3, 0.25, -d / 2.0 + 0.9), Color(0.3, 0.4, 0.7))
	_mark(bed, "bed", "Giường (ngủ, kết thúc ngày)")
	var desk: StaticBody3D = _box(root, Vector3(1.6, 0.8, 0.7), Vector3(w / 2.0 - 1.2, 0.4, -d / 2.0 + 0.7), Color(0.4, 0.28, 0.18))
	_mark(desk, "desk", "Bàn stream")
	var mon: StaticBody3D = _box(root, Vector3(0.8, 0.5, 0.05), Vector3(w / 2.0 - 1.2, 1.1, -d / 2.0 + 0.45), Color(0.1, 0.3, 0.8), false)
	_glow(mon, Color(0.2, 0.5, 1.0))
	if nice:
		var mon2: StaticBody3D = _box(root, Vector3(0.8, 0.5, 0.05), Vector3(w / 2.0 - 2.3, 1.1, -d / 2.0 + 0.45), Color(0.1, 0.3, 0.8), false)
		_glow(mon2, Color(0.5, 0.2, 1.0))
		_box(root, Vector3(2.4, 0.55, 0.9), Vector3(-w / 4.0, 0.28, 1.2), Color(0.55, 0.3, 0.3))
		_box(root, Vector3(3.0, 0.02, 2.0), Vector3(0, 0.01, 0), Color(0.6, 0.55, 0.4), false)

	_make_wife(root, Vector3(0, 0.8, -0.2))
	(wives[wives.size() - 1] as Node3D).set_meta("bed_pos", Vector3(-w / 2.0 + 1.3, 0.78, -d / 2.0 + 0.9))
	_box(root, Vector3(0.9, 0.7, 0.6), Vector3(w / 2.0 - 1.0, 0.35, d / 2.0 - 1.3), Color(0.5, 0.35, 0.2))
	var tray: StaticBody3D = _box(root, Vector3(0.6, 0.12, 0.4), Vector3(w / 2.0 - 1.0, 0.76, d / 2.0 - 1.3), Color(0.95, 0.85, 0.6))
	_glow(tray, Color(0.9, 0.7, 0.35))
	_mark(tray, "dinner", "Ăn cơm vợ nấu")
	tray.visible = false
	tray.collision_layer = 0
	trays.append(tray)

	var kitchen: StaticBody3D = _box(root, Vector3(0.9, 0.9, 0.6), Vector3(-w / 2.0 + 0.6, 0.45, d / 2.0 - 0.9), Color(0.75, 0.75, 0.78))
	_mark(kitchen, "kitchen", "Góc bếp (uống nước, nấu mì)")
	var jug: StaticBody3D = _box(root, Vector3(0.18, 0.35, 0.18), Vector3(-w / 2.0 + 0.45, 1.07, d / 2.0 - 0.9), Color(0.4, 0.7, 1.0), false)
	_glow(jug, Color(0.4, 0.7, 1.0))

	var door: StaticBody3D = _box(root, Vector3(1.1, 2.1, 0.1), Vector3(0, 1.05, d / 2.0 - 0.15), Color(0.2, 0.45, 0.25))
	_mark(door, "door_exit", "Ra ngoài phố")
	_label(root, "RA NGOÀI", Vector3(0, 2.35, d / 2.0 - 0.25), 0.5, PI)


func _make_wife(parent: Node3D, pos: Vector3) -> void:
	var b: StaticBody3D = StaticBody3D.new()
	b.set_meta("home_pos", pos)
	wives.append(b)
	b.position = pos
	var parts: Dictionary = town.humanoid(b, {"shirt": Color(0.95, 0.6, 0.7), "pants": Color(0.2, 0.2, 0.3), "female": true, "skin": Color(0.95, 0.8, 0.68)})
	(parts["root"] as Node3D).position = Vector3(0, -0.8, 0)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CapsuleShape3D = CapsuleShape3D.new()
	sh.radius = 0.28
	sh.height = 1.6
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	_mark(b, "wife", "Nói chuyện với vợ")
	var l: Label3D = _label(b, "Vợ", Vector3(0, 1.25, 0), 0.4)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED


## NPC ngoài phố: chú Tư ve chai (thu mua ve chai, bán lockpick) và chủ nợ (chỉ hiện ở ngày 1)
func _build_npcs() -> void:
	var p: Vector3 = _m(260, 60)
	var tu: StaticBody3D = _person(self, p + Vector3(0, 0.8, 0), Color(0.45, 0.38, 0.25), "Chú Tư ve chai")
	junk_npc = tu
	_mark(tu, "junk_npc", "Chú Tư ve chai (thu mua ve chai, bán lockpick)")
	_box(self, Vector3(1.0, 0.7, 1.6), p + Vector3(0, 0.35, 1.3), Color(0.35, 0.25, 0.15))
	door_spots["npc"] = {"pos": p + Vector3(0, 1.0, 0), "yaw": 0.0}
	var spot: Dictionary = door_spots["door_old"]
	creditor_npc = _person(self, Vector3(spot["pos"].x + 1.8, 0.8, spot["pos"].z), Color(0.1, 0.1, 0.12), "Chủ nợ")
	creditor_npc.visible = false
	(creditor_npc as CollisionObject3D).collision_layer = 0


func _shell(root: Node3D, sz: Vector3, wall_c: Color, floor_c: Color) -> void:
	var w: float = sz.x
	var h: float = sz.y
	var d: float = sz.z
	_box(root, Vector3(w, 0.2, d), Vector3(0, -0.1, 0), floor_c)
	_box(root, Vector3(w, 0.2, d), Vector3(0, h + 0.1, 0), Color(0.92, 0.92, 0.92))
	_box(root, Vector3(w, h, 0.2), Vector3(0, h / 2.0, -d / 2.0), wall_c)
	_box(root, Vector3(w, h, 0.2), Vector3(0, h / 2.0, d / 2.0), wall_c)
	_box(root, Vector3(0.2, h, d), Vector3(-w / 2.0, h / 2.0, 0), wall_c)
	_box(root, Vector3(0.2, h, d), Vector3(w / 2.0, h / 2.0, 0), wall_c)
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0, h - 0.4, 0)
	lamp.omni_range = 18.0
	lamp.light_energy = 1.6
	lamp.light_color = Color(1.0, 0.96, 0.88)
	root.add_child(lamp)


func _person(parent: Node3D, pos: Vector3, color: Color, name_text: String, opts: Dictionary = {}) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.position = pos
	var o: Dictionary = opts.duplicate()
	o["shirt"] = color
	o["female"] = bool(opts.get("female", name_text in ["Linh", "Vợ"]))
	var parts: Dictionary = town.humanoid(b, o)
	(parts["root"] as Node3D).position = Vector3(0, -0.8, 0)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CapsuleShape3D = CapsuleShape3D.new()
	sh.radius = 0.28
	sh.height = 1.6
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	var l: Label3D = _label(b, name_text, Vector3(0, 1.25, 0), 0.4)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return b


func _build_office() -> void:
	var root: Node3D = Node3D.new()
	root.position = OFFICE_ORIGIN
	add_child(root)
	_shell(root, OFFICE_SIZE, Color(0.82, 0.84, 0.86), Color(0.35, 0.37, 0.4))
	# Hàng bàn làm việc phía trong. Bàn của nhân vật chính ở x = -3.
	for x in [-3.0, 0.5, 4.0]:
		_box(root, Vector3(2.0, 0.8, 0.9), Vector3(x, 0.4, -2.8), Color(0.55, 0.45, 0.35))
		var mon: StaticBody3D = _box(root, Vector3(0.8, 0.5, 0.05), Vector3(x, 1.1, -3.1), Color(0.1, 0.3, 0.8), false)
		_glow(mon, Color(0.3, 0.55, 0.9))
	for x in [0.5, 4.0]:
		_box(root, Vector3(2.0, 0.8, 0.9), Vector3(x, 0.4, 1.0), Color(0.55, 0.45, 0.35))
		var mon2: StaticBody3D = _box(root, Vector3(0.8, 0.5, 0.05), Vector3(x, 1.1, 0.7), Color(0.1, 0.3, 0.8), false)
		_glow(mon2, Color(0.3, 0.55, 0.9))
	# Cửa văn phòng (trang trí)
	_box(root, Vector3(1.2, 2.2, 0.1), Vector3(3.5, 1.1, OFFICE_SIZE.z / 2.0 - 0.15), Color(0.3, 0.2, 0.12), false)
	# Bản báo cáo trên bàn nhân vật chính (chỉ nhặt được sau khi chọn "lên sau")
	office_report = _box(root, Vector3(0.6, 0.04, 0.42), Vector3(-3.0, 0.82, -2.45), Color(0.97, 0.97, 0.9))
	_glow(office_report, Color(1.0, 0.95, 0.6))
	_mark(office_report, "report", "Nhặt bản báo cáo")
	office_report.remove_meta("interact")
	linh = _person(root, Vector3(3.5, 0.8, 3.2), Color(0.9, 0.5, 0.7), "Linh")
	linh.visible = false


func _build_boss_room() -> void:
	var root: Node3D = Node3D.new()
	root.position = BOSS_ORIGIN
	add_child(root)
	_shell(root, BOSS_SIZE, Color(0.55, 0.42, 0.32), Color(0.25, 0.12, 0.12))
	_box(root, Vector3(3.0, 0.8, 1.2), Vector3(0, 0.4, -1.5), Color(0.28, 0.17, 0.1))
	boss_paper = _box(root, Vector3(0.5, 0.04, 0.36), Vector3(0, 0.82, -1.15), Color(0.97, 0.97, 0.9))
	_glow(boss_paper, Color(1.0, 0.95, 0.6))
	_mark(boss_paper, "paper", "Nhận giấy cho nghỉ việc")
	boss_paper.remove_meta("interact")
	_person(root, Vector3(0, 0.8, -2.45), Color(0.2, 0.2, 0.28), "Giám đốc")


## Điểm ngẫu nhiên trên mặt đường (hiện chưa dùng)
## Công trường bỏ hoang (ô xám): hàng rào tôn có lối vào phía bắc, nền bê tông,
## khung cột dở dang, giàn giáo, đống gạch đá. Tính năng riêng sẽ thêm sau.
func _build_site(b: Dictionary) -> void:
	var r: Array = b["r"]
	var c: Vector3 = _m((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
	var w: float = (r[2] - r[0]) * PX
	var d: float = (r[3] - r[1]) * PX
	var fence: Color = Color(0.45, 0.5, 0.42)
	var fh: float = 2.2
	_box(self, Vector3(w - 0.4, 0.15, d - 0.4), c + Vector3(0, 0.075, 0), Color(0.55, 0.53, 0.5))
	# hàng rào: 3 mặt kín, mặt bắc chừa lối vào rộng 3 m
	_box(self, Vector3(w, fh, 0.12), c + Vector3(0, fh / 2.0, d / 2.0), fence)
	_box(self, Vector3(0.12, fh, d), c + Vector3(-w / 2.0, fh / 2.0, 0), fence)
	_box(self, Vector3(0.12, fh, d), c + Vector3(w / 2.0, fh / 2.0, 0), fence)
	var seg: float = (w - 3.0) / 2.0
	_box(self, Vector3(seg, fh, 0.12), c + Vector3(-w / 2.0 + seg / 2.0, fh / 2.0, -d / 2.0), fence)
	_box(self, Vector3(seg, fh, 0.12), c + Vector3(w / 2.0 - seg / 2.0, fh / 2.0, -d / 2.0), fence)
	_label(self, "CÔNG TRƯỜNG BỎ HOANG", c + Vector3(-w / 4.0, fh + 0.5, -d / 2.0 - 0.1), 0.8, PI)
	var warn: StaticBody3D = _box(self, Vector3(1.6, 0.9, 0.05), c + Vector3(w / 4.0, 1.3, -d / 2.0 - 0.1), Color(0.95, 0.8, 0.1), false)
	_label(warn, "CẤM VÀO", Vector3(0, 0, -0.05), 0.5, PI)
	# khung cột bê tông dở dang + một phần sàn tầng 2
	var concrete: Color = Color(0.62, 0.6, 0.57)
	for ix in [-1, 0, 1]:
		for iz in [-1, 0, 1]:
			var hgt: float = 6.0 if iz < 1 else GameState.rng.randf_range(2.0, 5.0)
			var p: Vector3 = c + Vector3(float(ix) * w * 0.28, hgt / 2.0, float(iz) * d * 0.3 + 1.5)
			_box(self, Vector3(0.5, hgt, 0.5), p, concrete)
			_box(self, Vector3(0.04, 1.2, 0.04), p + Vector3(0.12, hgt / 2.0 + 0.6, 0.12), Color(0.45, 0.25, 0.15), false)
	_box(self, Vector3(w * 0.6, 0.3, d * 0.35), c + Vector3(0, 6.1, -d * 0.15 + 1.5), concrete)
	# giàn giáo
	var sc: Color = Color(0.25, 0.35, 0.55)
	var sx: float = w / 2.0 - 1.2
	for k in 4:
		var zz: float = -d / 2.0 + 4.0 + float(k) * 1.6
		_box(self, Vector3(0.08, 5.0, 0.08), c + Vector3(sx, 2.5, zz), sc)
		_box(self, Vector3(0.08, 5.0, 0.08), c + Vector3(sx - 1.2, 2.5, zz), sc)
	for lv in [1.6, 3.2, 4.8]:
		_box(self, Vector3(1.3, 0.06, 5.0), c + Vector3(sx - 0.6, lv, -d / 2.0 + 6.4), Color(0.55, 0.4, 0.25))
	# đống gạch, đá, bao xi măng
	for i in 6:
		var rp: Vector3 = c + Vector3(GameState.rng.randf_range(-w / 2.0 + 2.0, w / 2.0 - 4.0), 0, GameState.rng.randf_range(d * 0.15, d / 2.0 - 1.5))
		var sz: float = GameState.rng.randf_range(0.6, 1.4)
		_box(self, Vector3(sz, sz * 0.5, sz * 0.8), rp + Vector3(0, sz * 0.25, 0), Color(0.6, 0.35, 0.25) if i % 2 == 0 else Color(0.7, 0.7, 0.68))
	# cổng khóa ở lối vào: cạy bằng lockpick
	site_gate = _box(self, Vector3(3.0, fh, 0.15), c + Vector3(0, fh / 2.0, -d / 2.0), Color(0.35, 0.38, 0.33))
	_box(site_gate, Vector3(0.25, 0.3, 0.2), Vector3(0.4, 0.0, -0.12), Color(0.55, 0.45, 0.2), false)
	_mark(site_gate, "site_gate", "Cổng công trường (bị khóa)")
	door_spots["site"] = {"pos": c + Vector3(0, 1.0, -d / 2.0 - 1.5), "yaw": PI}
	site_c = c
	site_w = w
	site_d = d
	# bảo vệ gác cổng (trước ngày 37)
	gate_guard = _person(self, c + Vector3(2.2, 0.8, -d / 2.0 - 1.0), Color(0.15, 0.25, 0.45), "Bảo vệ")
	_mark(gate_guard, "gate_guard", "Bảo vệ công trường")
	# bảo vệ tuần tra bên trong, cầm đèn pin
	patrol_guard = _person_mesh(Color(0.15, 0.25, 0.45), "Bảo vệ")
	var torch: SpotLight3D = SpotLight3D.new()
	torch.position = Vector3(0, 1.5, -0.2)
	torch.spot_range = 9.0
	torch.spot_angle = 35.0
	torch.light_energy = 3.0
	torch.light_color = Color(1.0, 0.95, 0.7)
	patrol_guard.add_child(torch)
	patrol_guard.visible = false
	for p in [Vector3(-w / 2.0 + 2.5, 0, -d / 2.0 + 3.5), Vector3(w / 2.0 - 3.5, 0, -d / 2.0 + 3.5), Vector3(w / 2.0 - 3.5, 0, d / 2.0 - 3.0), Vector3(-w / 2.0 + 2.5, 0, d / 2.0 - 3.0), Vector3(0, 0, 0)]:
		patrol_pts.append(c + p)
	patrol_guard.position = patrol_pts[0]
	# cuộn dây đồng ở góc trong cùng
	coil_node = StaticBody3D.new()
	coil_node.position = c + Vector3(-w / 2.0 + 1.4, 0.0, d / 2.0 - 1.4)
	var cmi: MeshInstance3D = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.25
	tor.outer_radius = 0.5
	cmi.mesh = tor
	cmi.position = Vector3(0, 0.2, 0)
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.85, 0.45, 0.2)
	cmat.metallic = 0.8
	cmat.emission_enabled = true
	cmat.emission = Color(0.5, 0.22, 0.08)
	cmi.material_override = cmat
	coil_node.add_child(cmi)
	var ccs: CollisionShape3D = CollisionShape3D.new()
	var csh: BoxShape3D = BoxShape3D.new()
	csh.size = Vector3(1.0, 0.5, 1.0)
	ccs.shape = csh
	ccs.position = Vector3(0, 0.25, 0)
	coil_node.add_child(ccs)
	add_child(coil_node)
	_mark(coil_node, "coil", "Lấy cuộn dây đồng")
	# đống phế liệu để đào vụn dây đồng (sau khi công trường bỏ ngỏ)
	for p in [Vector3(-2.0, 0, 2.0), Vector3(3.0, 0, -4.0), Vector3(-4.0, 0, -6.0)]:
		var pile: StaticBody3D = _box(self, Vector3(1.4, 0.6, 1.2), c + p + Vector3(0, 0.3, 0), Color(0.5, 0.35, 0.25))
		_mark(pile, "site_dig", "Đào đống phế liệu (tìm vụn dây đồng)")
		site_digs.append(pile)


func _random_street_pos() -> Vector3:
	var total: float = 0.0
	for r in ROADS:
		total += float((r[2] - r[0]) * (r[3] - r[1]))
	var pick: float = GameState.rng.randf() * total
	var rr: Array = ROADS[0]
	for r in ROADS:
		pick -= float((r[2] - r[0]) * (r[3] - r[1]))
		if pick <= 0.0:
			rr = r
			break
	var px: float = GameState.rng.randf_range(float(rr[0]) + 8.0, float(rr[2]) - 8.0)
	var py: float = GameState.rng.randf_range(float(rr[1]) + 8.0, float(rr[3]) - 8.0)
	return _m(px, py) + Vector3(0, 0.06, 0)


func _spawn_street_items() -> void:
	group_period = ""
	for p in piles:
		if is_instance_valid(p):
			(p as Node).queue_free()
	piles.clear()
	_spawn_piles()


## Rải 4-5 đụn rác / đụn lá ngẫu nhiên trên vỉa hè, cách nhau và cách cửa nhà.
func _spawn_piles() -> void:
	var count: int = GameState.rng.randi_range(4, 5)
	var placed: Array = []
	var tries: int = 0
	while placed.size() < count and tries < 200:
		tries += 1
		var pos: Vector3 = _random_sidewalk_pos()
		var ok: bool = true
		for q in placed:
			if _flat_dist(pos, q) < 8.0:
				ok = false
		for k in door_spots.keys():
			if _flat_dist(pos, door_spots[k]["pos"]) < 3.0:
				ok = false
		if not ok:
			continue
		placed.append(pos)
		var kind: String = "trash" if GameState.rng.randf() < 0.55 else "leaves"
		piles.append(_make_pile(pos, kind))


func _make_pile(pos: Vector3, kind: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var cols: Array = []
	if kind == "trash":
		cols = [Color(0.08, 0.08, 0.09), Color(0.15, 0.15, 0.17), Color(0.35, 0.3, 0.25), Color(0.6, 0.6, 0.62)]
	else:
		cols = [Color(0.75, 0.45, 0.12), Color(0.6, 0.35, 0.1), Color(0.8, 0.62, 0.2), Color(0.45, 0.3, 0.12)]
	var n: int = 5 if kind == "trash" else 7
	for i in n:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		var r: float = GameState.rng.randf_range(0.18, 0.32) if kind == "trash" else GameState.rng.randf_range(0.2, 0.35)
		sm.radius = r
		sm.height = r * (1.4 if kind == "trash" else 0.7)
		mi.mesh = sm
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = cols[GameState.rng.randi_range(0, cols.size() - 1)]
		mat.roughness = 0.4 if kind == "trash" else 1.0
		mi.material_override = mat
		mi.position = Vector3(GameState.rng.randf_range(-0.35, 0.35), r * 0.45, GameState.rng.randf_range(-0.35, 0.35))
		body.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(1.1, 0.5, 1.1)
	cs.shape = sh
	cs.position = Vector3(0, 0.25, 0)
	body.add_child(cs)
	street_items.add_child(body)
	body.set_meta("pile", kind)
	_mark(body, "pile", "Bới đụn rác" if kind == "trash" else "Bới đụn lá")
	return body


## Vỉa hè (phần trắng trên bản đồ), tính bằng pixel [x0, y0, x1, y1]
const SIDEWALKS: Array = [
	[129, 0, 171, 173],     # dọc dãy nhà bên trái (trên)
	[129, 223, 171, 537],   # dọc dãy nhà bên trái (giữa)
	[129, 587, 171, 735],   # dọc dãy nhà bên trái (dưới)
	[221, 0, 275, 173],     # cạnh chỗ đỏ đen
	[275, 127, 603, 173],   # trước chỗ đỏ đen, nhà chủ nợ
	[221, 223, 603, 264],   # trước nhà cho thuê, công trường
	[221, 264, 268, 537],   # cạnh nhà cho thuê
	[268, 493, 603, 537],   # sau nhà cho thuê, công trường
	[221, 587, 603, 624],   # trước cửa hàng máy tính
	[221, 624, 265, 735],   # cạnh cửa hàng máy tính
]


func _random_sidewalk_pos() -> Vector3:
	var total: float = 0.0
	for r in SIDEWALKS:
		total += float((r[2] - r[0]) * (r[3] - r[1]))
	var pick: float = GameState.rng.randf() * total
	var rr: Array = SIDEWALKS[0]
	for r in SIDEWALKS:
		pick -= float((r[2] - r[0]) * (r[3] - r[1]))
		if pick <= 0.0:
			rr = r
			break
	var px: float = GameState.rng.randf_range(float(rr[0]) + 6.0, float(rr[2]) - 6.0)
	var py: float = GameState.rng.randf_range(float(rr[1]) + 6.0, float(rr[3]) - 6.0)
	return _m(px, py)


# ====================================================================== thế giới theo giờ

func _shops_open() -> bool:
	var m: float = GameState.minutes
	return m >= float(GameState.SHOP_OPEN) and m < float(GameState.STREET_CLOSE)


func _set_active(n: Node3D, on: bool) -> void:
	n.visible = on
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 1 if on else 0


func _reset_wives() -> void:
	for w in wives:
		(w as Node3D).position = w.get_meta("home_pos")
		(w as Node3D).rotation = Vector3.ZERO


## Cập nhật những gì phụ thuộc giờ: vợ ở nhà từ 18h, mâm cơm, chú Tư, người đi đường, trấn lột
func _update_world() -> void:
	if not game_live:
		return
	var g = GameState
	var home: bool = g.wife_home()
	var asleep: bool = g.wife_asleep()
	for w in wives:
		_set_active(w, home)
		if home:
			(w as Node3D).position = w.get_meta("bed_pos") if asleep else w.get_meta("home_pos")
			(w as Node3D).rotation = Vector3(0, 0, PI / 2.0) if asleep else Vector3.ZERO
	for i in trays.size():
		_set_active(trays[i], home and g.wife_cooked and not g.dinner_eaten)
	_set_active(junk_npc, _shops_open())
	if not is_instance_valid(linh_npc) and door_spots.has("food"):
		var fp: Vector3 = door_spots["food"]["pos"]
		linh_npc = _person(self, Vector3(fp.x + 1.2, 0.8, fp.z + 1.0), Color(0.9, 0.5, 0.7), "Linh")
		_mark(linh_npc, "linh", "Nói chuyện với Linh")
	_set_active(linh_npc, g.day == 31 and g.hour() >= 7 and g.hour() < 22 and not g.flags.has("story_31"))
	var h: int = g.hour()
	var want: int = 0
	var want_groups: int = 0
	var period: String = "night"
	if h >= 7 and h < 18:
		want = 9
		want_groups = 3
		period = "day"
	elif h >= 18 and h < 23:
		want = 4
		want_groups = 1
		period = "evening"
	while walkers.size() < want:
		walkers.append(_spawn_walker())
	while walkers.size() > want:
		var wk: Dictionary = walkers.pop_back()
		(wk["node"] as Node).queue_free()
	if period != group_period:
		group_period = period
		_clear_groups()
		for _i in want_groups:
			_spawn_group()
	if g.minutes >= float(g.STREET_CLOSE):
		var key: String = "robbers_night_%d" % g.day
		if robbers.is_empty() and not g.flags.has(key):
			g.flags[key] = true
			for _i in 5:
				robbers.append(_spawn_robber())
	elif not robbers.is_empty():
		_clear_robbers()


## Cập nhật thế giới theo giờ ngay cả khi chưa vào game (dùng khi tải game / chụp ảnh)
func _update_world_force() -> void:
	var was: bool = game_live
	game_live = true
	_update_world()
	game_live = was


func _check_first_meet() -> void:
	var g = GameState
	if not in_room or g.wife_met_today or not g.wife_home() or g.wife_asleep() or hud.menu_open:
		return
	g.wife_met_today = true
	if g.day == 19 and not g.new_house and not g.flags.has("story_19"):
		g.flags["story_19"] = true
		_say("Vợ", "Anh ơi... mấy hôm nay đêm nào em cũng không ngủ được vì đèn stream sáng quá. Sáng ra đi làm em cứ lờ đờ. Mình tìm chỗ nào rộng hơn được không anh?", _day19_2, "day19_01")
		return
	if g.wife_cooked:
		_say("Vợ", "Hôm nay em có nấu cơm, anh ăn đi nhé còn làm việc.", _noop, "wife_cooked")
	else:
		_say("Vợ", "Hôm nay em làm tăng ca nên ăn luôn ở công ty rồi.", _noop, "wife_overtime")


func _person_mesh(color: Color, label_text: String = "") -> Node3D:
	var n: Node3D = Node3D.new()
	var parts: Dictionary = town.humanoid(n, {"shirt": color, "pants": color.darkened(0.3), "female": false})
	n.set_meta("parts", parts)
	if label_text != "":
		var l: Label3D = _label(n, label_text, Vector3(0, 2.1, 0), 0.4)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.modulate = Color(1, 0.4, 0.4)
	street_items.add_child(n)
	return n


func _rand_in_rect(r: Array, margin: float) -> Vector3:
	var px: float = GameState.rng.randf_range(float(r[0]) + margin, float(r[2]) - margin)
	var py: float = GameState.rng.randf_range(float(r[1]) + margin, float(r[3]) - margin)
	return _m(px, py)


const NPC_NAMES_M: Array = ["Anh Hùng", "Bác Tâm", "Anh Tuấn", "Chú Bảy", "Anh Dũng", "Ông Năm", "Anh Khoa", "Anh Phát", "Em Huy", "Chú Sáng"]
const NPC_NAMES_F: Array = ["Chị Lan", "Cô Hoa", "Bà Sáu", "Em Vy", "Chị Mai", "Cô Thảo", "Chị Hằng", "Bé Na", "Cô Tư", "Chị Nhung"]
const NPC_ROLES: Array = ["người trong xóm", "xe ôm", "sinh viên", "bán xôi", "dân văn phòng", "công nhân", "bà nội trợ", "shipper"]


## Tạo một người (StaticBody để nhìn vào và bấm E nói chuyện được)
func _make_npc(pos: Vector3) -> StaticBody3D:
	var rng: RandomNumberGenerator = GameState.rng
	var b: StaticBody3D = StaticBody3D.new()
	b.position = pos
	var role0: String = str(NPC_ROLES[rng.randi_range(0, NPC_ROLES.size() - 1)])
	var hat: bool = role0 in ["bán xôi", "bà nội trợ", "công nhân"] and rng.randf() < 0.7
	var female: bool = role0 in ["bán xôi", "bà nội trợ"] or (role0 != "xe ôm" and rng.randf() < 0.45)
	var parts: Dictionary = town.humanoid(b, {"rng": rng, "hat": hat, "female": female})
	b.set_meta("parts", parts)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CapsuleShape3D = CapsuleShape3D.new()
	sh.radius = 0.26
	sh.height = 1.6
	cs.shape = sh
	cs.position = Vector3(0, 0.8, 0)
	b.add_child(cs)
	var names: Array = NPC_NAMES_F if female else NPC_NAMES_M
	var nm: String = str(names[rng.randi_range(0, names.size() - 1)])
	var role: String = role0
	b.set_meta("npc_name", nm)
	b.set_meta("npc_role", role)
	_mark(b, "npc", "Nói chuyện với %s (%s)" % [nm, role])
	street_items.add_child(b)
	return b


func _corr_world(i: int) -> Array:
	var r: Array = CORRIDORS[i]
	var a: Vector3 = _m(float(r[0]), float(r[1]))
	var b: Vector3 = _m(float(r[2]), float(r[3]))
	return [a.x, a.z, b.x, b.z]


func _corr_of(p: Vector3) -> int:
	for i in CORRIDORS.size():
		var w: Array = _corr_world(i)
		if p.x >= w[0] and p.x <= w[2] and p.z >= w[1] and p.z <= w[3]:
			return i
	return 0


func _rand_in_corr(i: int) -> Vector3:
	var w: Array = _corr_world(i)
	return Vector3(GameState.rng.randf_range(w[0] + 0.6, w[2] - 0.6), 0.0, GameState.rng.randf_range(w[1] + 0.6, w[3] - 0.6))


## Điểm ngẫu nhiên trong phần giao nhau của hai ô đi lại
func _overlap_point(a: int, b: int) -> Vector3:
	var wa: Array = _corr_world(a)
	var wb: Array = _corr_world(b)
	var x0: float = maxf(wa[0], wb[0]) + 0.8
	var z0: float = maxf(wa[1], wb[1]) + 0.8
	var x1: float = minf(wa[2], wb[2]) - 0.8
	var z1: float = minf(wa[3], wb[3]) - 0.8
	return Vector3(GameState.rng.randf_range(x0, maxf(x0, x1)), 0.0, GameState.rng.randf_range(z0, maxf(z0, z1)))


## Đường đi từ p đến d, chỉ đi thẳng trong từng ô (không xuyên nhà)
func _plan_path(p: Vector3, d: Vector3) -> Array:
	var ci: int = _corr_of(p)
	var cj: int = _corr_of(d)
	if ci == cj:
		return [d]
	if ci == 0 or cj == 0:
		return [_overlap_point(ci, cj), d]
	return [_overlap_point(ci, 0), _overlap_point(0, cj), d]


## Chọn điểm đến mới: 25% vào quán ăn / tiệm vàng, còn lại đi dạo
func _walker_new_goal(wk: Dictionary) -> void:
	var n: Node3D = wk["node"]
	var rng: RandomNumberGenerator = GameState.rng
	var shop: String = ""
	if rng.randf() < 0.25:
		shop = "food" if rng.randf() < 0.6 else "jewelry_shop"
	var dest: Vector3
	if shop != "" and door_spots.has(shop):
		dest = door_spots[shop]["pos"]
		dest.y = 0.0
	else:
		dest = _rand_in_corr(rng.randi_range(0, CORRIDORS.size() - 1))
	wk["path"] = _plan_path(n.position, dest)
	wk["shop"] = shop


func _spawn_walker() -> Dictionary:
	var n: StaticBody3D = _make_npc(_rand_in_corr(GameState.rng.randi_range(0, CORRIDORS.size() - 1)))
	var wk: Dictionary = {"node": n, "path": [], "shop": "", "wait": GameState.rng.randf_range(0.0, 3.0), "speed": GameState.rng.randf_range(1.0, 1.5)}
	_walker_new_goal(wk)
	return wk


## Nhóm 2-3 người đứng nói chuyện trên vỉa hè
func _spawn_group() -> void:
	var rng: RandomNumberGenerator = GameState.rng
	var center: Vector3 = _random_sidewalk_pos()
	var cnt: int = rng.randi_range(2, 3)
	var members: Array = []
	for i in cnt:
		var ang: float = TAU * float(i) / float(cnt) + rng.randf() * 0.4
		var p: Vector3 = center + Vector3(cos(ang), 0, sin(ang)) * 0.75
		var n: StaticBody3D = _make_npc(p)
		var to_c: Vector3 = center - p
		n.rotation.y = atan2(-to_c.x, -to_c.z)
		n.set_meta("in_group", true)
		members.append(n)
	groups.append(members)


func _clear_groups() -> void:
	for g in groups:
		for n in g:
			(n as Node).queue_free()
	groups.clear()


## Trấn lột: lảng vảng trên mặt đường sau 23:00
func _spawn_robber() -> Dictionary:
	var r: Array = ROADS[GameState.rng.randi_range(0, ROADS.size() - 1)]
	var n: Node3D = _person_mesh(Color(0.12, 0.1, 0.1), "Trấn lột")
	n.position = _rand_in_rect(r, 10.0)
	return {"node": n, "rect": r, "target": _rand_in_rect(r, 10.0), "robbed": false, "speed": 2.0}


func _clear_robbers() -> void:
	for rb in robbers:
		(rb["node"] as Node).queue_free()
	robbers.clear()


func _move_walkers(delta: float) -> void:
	for wk in walkers:
		var n: StaticBody3D = wk["node"]
		if float(wk["wait"]) > 0.0:
			wk["wait"] = float(wk["wait"]) - delta
			town.animate_walk(n.get_meta("parts", {}), 0.0, false)
			if float(wk["wait"]) <= 0.0 and not n.visible:
				_set_active(n, true)  # đi ra khỏi quán
			continue
		var path: Array = wk["path"]
		if path.is_empty():
			if str(wk["shop"]) != "":
				_set_active(n, false)  # vào quán ăn / tiệm vàng một lúc
				wk["wait"] = GameState.rng.randf_range(15.0, 40.0)
				wk["shop"] = ""
			else:
				wk["wait"] = GameState.rng.randf_range(0.5, 4.0)
			_walker_new_goal(wk)
			continue
		var tgt: Vector3 = path[0]
		var dir: Vector3 = tgt - n.position
		dir.y = 0.0
		if dir.length() < 0.3:
			path.pop_front()
			continue
		n.position += dir.normalized() * float(wk["speed"]) * delta
		n.rotation.y = atan2(-dir.x, -dir.z)
		wk["phase"] = float(wk.get("phase", 0.0)) + delta * float(wk["speed"]) * 5.0
		town.animate_walk(n.get_meta("parts", {}), float(wk["phase"]), true)
	for rb in robbers:
		var rn: Node3D = rb["node"]
		var d2: Vector3 = rb["target"] - rn.position
		if d2.length() < 0.5:
			rb["target"] = _rand_in_rect(rb["rect"], 10.0)
			continue
		rn.position += d2.normalized() * float(rb["speed"]) * delta
		rn.rotation.y = atan2(-d2.x, -d2.z)
		rb["phase"] = float(rb.get("phase", 0.0)) + delta * 9.0
		town.animate_walk(rn.get_meta("parts", {}), float(rb["phase"]), true)


## Trong tầm 3 m của trấn lột thì bị trấn 5% tiền mặt (mỗi tên một lần mỗi đêm)
func _check_robbers() -> void:
	if in_room or hud.menu_open:
		return
	for rb in robbers:
		if bool(rb["robbed"]):
			continue
		if _flat_dist(player.global_position, (rb["node"] as Node3D).position) < 3.0:
			rb["robbed"] = true
			var amt: int = GameState.rob()
			_show_result("Bị trấn lột!", "Một gã từ trong bóng tối chặn đường, dí sát vào người bạn: \"Có bao nhiêu đưa đây.\"\nBạn mất %s (5%% tiền mặt).\n\nĐường khuya nguy hiểm, nên về nhà trước 23:00." % GameState.fmt_money(amt), [])
			return


# ====================================================================== cốt truyện theo ngày

func _story_once(key: String) -> bool:
	if GameState.flags.has(key):
		return false
	GameState.flags[key] = true
	return true


## Các cảnh cố định theo ngày (theo sheet xương sống). Trả về true nếu đã mở một cảnh.
func _story_poll() -> bool:
	var g = GameState
	var d: int = g.day
	var m: float = g.minutes
	if g.MILESTONES.has(d) and d < g.TOTAL_DAYS and m >= float(g.COLLECT_HOUR * 60) and _story_once("collect_%d" % d):
		_collect_start()
		return true
	if m < float(7 * 60):
		return false
	if d == 32 and _story_once("story_32"):
		_say("Tin nhắn từ chú Tư ve chai", "Cháu ơi, chú mới về được ít \"đồ nghề đặc biệt\", cái loại mở được ổ khóa ấy. Cần thì qua chỗ chú. (Chú Tư giờ có bán lockpick.)", _noop, "day32_hint")
		return true
	if d == 36 and _story_once("story_36"):
		_say("Tin trong xóm", "Loa phường thông báo: ngày mai cả khu phố đi lễ hội ở nhà văn hóa, mời bà con tham gia. Nghe nói bảo vệ công trường bỏ hoang cũng đi, ngày mai cổng không có ai canh...", _noop, "day36_news")
		return true
	if d == 37 and _story_once("story_37"):
		_say("Tôi (nghĩ thầm)", "Hôm nay cả xóm đi lễ hội, cổng công trường không có ai gác. Bên trong chắc vẫn còn tay bảo vệ đi tuần... Nếu có lockpick thì đây là cơ hội.", _noop, "day37_think")
		return true
	if d == 46 and m >= float(9 * 60) and _story_once("story_46"):
		_ai_offer()
		return true
	if d == 56 and _story_once("story_56"):
		_say("Nhắc nhở", "Chỉ còn 4 ngày nữa là hết hạn. Bạn còn nợ %s. Hết ngày 60 phải trả đủ." % g.fmt_money(g.remaining_debt()), _noop, "")
		return true
	return false


# --- ngày 13 / 40 / 50: chủ nợ đến nhà thu tiền lúc 20:00

func _collect_start() -> void:
	game_live = false
	var need: int = int(GameState.MILESTONES[GameState.day]) - GameState.paid
	var t: String = "Điện thoại rung. Giọng chủ nợ: \"Tao đang đứng trước cửa nhà mày. Hôm nay là ngày đóng %s đấy.\"" % GameState.fmt_money(maxi(0, need))
	hud.show_menu("Chủ nợ gọi", t, [{"label": "Về nhà ra mở cửa", "cb": func(): hud.transition(_collect_door, 0.8)}], t, "")


func _collect_door() -> void:
	var spot: Dictionary = door_spots["door_old" if not GameState.new_house else "door_new"]
	var yaw: float = float(spot["yaw"])
	creditor_npc.position = Vector3(spot["pos"].x, 0.8, spot["pos"].z) + Vector3(-sin(yaw), 0, -cos(yaw)) * 1.8
	creditor_npc.visible = true
	player.teleport(spot["pos"], float(spot["yaw"]))
	in_room = false
	var g = GameState
	var r: Dictionary = g.creditor_collect()
	var t: String = ""
	if int(r["need"]) <= 0:
		t = "Chủ nợ liếc sổ: \"Mày đóng đủ trước rồi. Được, biết điều đấy.\" Hắn bỏ đi."
	elif int(r["short"]) <= 0:
		t = "Bạn đưa %s. Chủ nợ đếm tiền, gật gù: \"Được, mày biết điều đấy. Lần sau cũng vậy nhé.\"" % g.fmt_money(int(r["paid"]))
	else:
		t = "Bạn chỉ đưa được %s, còn thiếu %s.\nChủ nợ hất hàm, đàn em xông vào nhà đập phá góc stream. Máy tính, đèn, mic vỡ tung tóe. Vợ đứng nép ở góc, run bần bật." % [g.fmt_money(int(r["paid"])), g.fmt_money(int(r["short"]))]
		if g.flags.has("creditor_rude"):
			t += "\n\nChủ nợ cười khẩy: \"Còn nhớ hôm trước mày bảo tao biến mẹ về không? Tao bảo rồi, nhớ đấy.\" Lần này chúng đập nát hơn."
		t += "\n\nPhải mang ra cửa hàng đồ máy tính sửa (%s) mới stream tiếp được." % g.fmt_money(g.repair_cost())
	hud.show_menu("Chủ nợ đến thu tiền · Ngày %d" % g.day, t, [{"label": "Tiếp tục", "cb": _collect_end}], t, "")


func _collect_end() -> void:
	creditor_npc.visible = false
	game_live = true


# --- ngày 19: vợ không ngủ được vì đèn stream

func _day19_2() -> void:
	_say("Tôi", "Ừ... anh xin lỗi. Để anh tính. Đầu ngõ có căn nhà cho thuê rộng hơn, anh sẽ cố thuê bằng được.", _day19_3, "day19_02")


func _day19_3() -> void:
	var g = GameState
	_say("MỤC TIÊU MỚI", "Thuê căn NHÀ CHO THUÊ (màu vàng, giữa khu phố) trước khi hết ngày %d. Tiền cọc %s.\nNếu không, vợ sẽ không chịu được nữa." % [g.NEW_HOUSE_DEADLINE, g.fmt_money(g.NEW_HOUSE_DEPOSIT)], _noop, "")
	hud.set_objective("Thuê nhà mới trước hết ngày %d (cọc %s)" % [g.NEW_HOUSE_DEADLINE, g.fmt_money(g.NEW_HOUSE_DEPOSIT)])


# --- ngày 31: gặp lại Linh ở quán ăn

func _linh_scene() -> void:
	if not _story_once("story_31"):
		return
	_say("Linh", "Ơ, anh! Lâu lắm mới gặp. Em ra đây ăn trưa... Từ hôm anh nghỉ, công ty dùng AI loạn hết cả lên, giờ đến lượt em cũng sắp bị cắt rồi.", _linh_2, "day31_01")


func _linh_2() -> void:
	_say("Linh", "À mà anh ở xóm này đúng không? Người ta đồn cái công trường bỏ hoang ấy, ông chủ thầu ôm tiền bỏ trốn, còn giấu cả đống đồ trong đó. Có cuộn dây đồng to lắm, bán phải chục triệu.", _linh_3, "day31_02")


func _linh_3() -> void:
	if is_instance_valid(linh_npc):
		_set_active(linh_npc, false)
	_say("Tôi (nghĩ thầm)", "Cuộn dây đồng chục triệu... Nhưng công trường lúc nào cũng có bảo vệ.", _noop, "day31_03")


# --- ngày 46: công ty cũ muốn mua giọng nói và khuôn mặt

func _ai_offer() -> void:
	game_live = false
	var t: String = "Một người đàn ông mặc vest gõ cửa, đưa danh thiếp của chính công ty cũ của bạn.\n\n\"Chúng tôi đang làm streamer AI. Kênh của anh có chất riêng. Công ty muốn mua bản quyền giọng nói và khuôn mặt của anh: %s, trả ngay hôm nay. Từ nay AI sẽ live thay anh.\"" % GameState.fmt_money(GameState.AI_DEAL_MONEY)
	hud.show_menu("Người từ công ty cũ", t, [
		{"label": "Bán (nhận %s, người xem và thu nhập stream giảm một nửa đến hết game)" % GameState.fmt_money(GameState.AI_DEAL_MONEY), "cb": _ai_sell},
		{"label": "Từ chối", "cb": _ai_refuse}], "Công ty muốn mua bản quyền giọng nói và khuôn mặt của anh.", "day46_offer")


func _ai_sell() -> void:
	GameState.ai_deal(true)
	_say("Tôi (nghĩ thầm)", "Hai mươi triệu. Món nợ nhẹ đi một chút. Còn mình... từ giờ là ai?", _resume_play, "day46_sell")


func _ai_refuse() -> void:
	GameState.ai_deal(false)
	_say("Tôi", "Cảm ơn, nhưng tôi không bán chính mình. Bị AI cướp việc một lần là đủ rồi.", _resume_play, "day46_refuse")


# ====================================================================== công trường: lén lút

func _in_site(p: Vector3) -> bool:
	return absf(p.x - site_c.x) < site_w / 2.0 and absf(p.z - site_c.z) < site_d / 2.0


func _update_site(delta: float) -> void:
	var g = GameState
	var guard_gate: bool = g.day < g.SITE_DAY
	_set_active(gate_guard, guard_gate)
	var free_site: bool = g.flags.has("site_free")
	var patrolling: bool = (not guard_gate) and not free_site
	patrol_guard.visible = patrolling
	_set_active(coil_node, patrolling and not g.has_item("copper_coil"))
	for p in site_digs:
		_set_active(p, free_site)
	if not patrolling:
		return
	# đi tuần
	var tgt: Vector3 = patrol_pts[patrol_i]
	var dir: Vector3 = tgt - patrol_guard.position
	dir.y = 0.0
	if dir.length() < 0.4:
		patrol_i = (patrol_i + 1) % patrol_pts.size()
	else:
		patrol_guard.position += dir.normalized() * 1.6 * delta
		patrol_phase += delta * 8.0
		town.animate_walk(patrol_guard.get_meta("parts", {}), patrol_phase, true)
		var want: float = atan2(-dir.x, -dir.z)
		patrol_guard.rotation.y = lerp_angle(patrol_guard.rotation.y, want, minf(1.0, delta * 4.0))
	# phát hiện
	var pp: Vector3 = player.global_position
	if in_room or not _in_site(pp):
		detect = maxf(0.0, detect - delta)
		if g.has_item("copper_coil") and not in_room and not _in_site(pp) and _flat_dist(pp, site_c) < site_d:
			_site_escaped()
		return
	var to_p: Vector3 = pp - patrol_guard.position
	to_p.y = 0.0
	var dist: float = to_p.length()
	var fwd: Vector3 = -patrol_guard.global_transform.basis.z
	fwd.y = 0.0
	var rng_lim: float = 4.5 if player.crouching else 8.5
	var seen: bool = false
	if dist < 1.3:
		seen = true
	elif dist < rng_lim and fwd.normalized().angle_to(to_p.normalized()) < deg_to_rad(45.0):
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(patrol_guard.position + Vector3(0, 1.6, 0), pp + Vector3(0, 0.3, 0))
		q.exclude = [player.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		seen = hit.is_empty()
	if seen:
		detect += delta * 2.0
		hud.set_hint("Bảo vệ đang nhìn về phía bạn!  %d%%" % int(minf(detect, 1.0) * 100.0))
	else:
		detect = maxf(0.0, detect - delta * 0.7)
		hud.set_hint("Ctrl: cúi người  ·  Tránh ánh đèn pin của bảo vệ" if detect <= 0.0 else "Bảo vệ đang nghi ngờ...  %d%%" % int(detect * 100.0))
	if detect >= 1.0:
		detect = 0.0
		game_live = false
		hud.set_hint("")
		hud.transition(_caught_mid, 0.6)


func _caught_mid() -> void:
	var r: Dictionary = GameState.site_caught()
	var spot: Dictionary = door_spots["site"]
	player.teleport(spot["pos"], float(spot["yaw"]))
	patrol_i = 0
	patrol_guard.position = patrol_pts[0]
	hud.show_menu("BỊ BẢO VỆ BẮT · lần %d/3" % int(r["n"]), str(r["text"]), [{"label": "Tiếp tục", "cb": _after_collapse}], str(r["text"]), "")


func _take_coil() -> void:
	if GameState.add_item("copper_coil", 1) <= 0:
		_show_result("Cuộn dây đồng", "Túi đồ đầy rồi, không mang được.", [])
		return
	_set_active(coil_node, false)
	hud.set_objective("Mang cuộn dây đồng ra khỏi công trường mà không bị phát hiện")
	hud.toast("Đã lấy cuộn dây đồng! Ra ngoài thật cẩn thận.", 3.0)


func _site_escaped() -> void:
	GameState.flags["site_free"] = true
	hud.set_objective("")
	hud.set_hint("")
	_show_result("Thoát ra an toàn!", "Bạn ôm cuộn dây đồng ra khỏi công trường mà không ai hay biết. Mang bán cho chú Tư ve chai được 10 triệu.\n\nTừ giờ bảo vệ bỏ đi, công trường bỏ ngỏ. Bạn có thể vào đào bới đống phế liệu tìm vụn dây đồng (100k–500k).", [])


func _menu_site_dig() -> void:
	var g = GameState
	var key: String = "site_dig_%d" % g.day
	var used: int = int(g.flags.get(key, 0))
	if used >= 2:
		_show_result("Đống phế liệu", "Hôm nay bạn đào đủ rồi, tay rát hết cả. Mai quay lại.", [])
		return
	hud.show_menu("Đống phế liệu", "Đào tìm vụn dây đồng? (30 phút, còn %d lần hôm nay)" % (2 - used), [
		{"label": "Đào", "cb": _do_site_dig},
		{"label": "Thôi", "cb": _noop}])


func _do_site_dig() -> void:
	var g = GameState
	var key: String = "site_dig_%d" % g.day
	g.flags[key] = int(g.flags.get(key, 0)) + 1
	var r: Dictionary = g.dig_site()
	_show_result("Đào phế liệu", str(r["text"]), r["lines"])


# ====================================================================== màn hình livestream

func _play_live(res: Dictionary, done: Callable) -> void:
	var g = GameState
	var info: Dictionary = {"viewers": int(res.get("viewers", 0)), "day": g.day, "chat_good": g.data.get("chat_good", []), "chat_bad": g.data.get("chat_bad", []), "popups": []}
	var pops: Array = []
	if bool(res.get("first_donate", false)):
		g.flags["first_donate_shown"] = true
		pops.append({"t": 5.0, "text": "💛 Donate đầu tiên của kênh nè, cố gắng bạn nhé, đừng bỏ cuộc"})
	elif int(res.get("rally", 0)) > 0:
		pops.append({"t": 3.0, "text": "💛 Người donate đầu tiên: \"Anh em ơi, ủng hộ streamer thật của chúng ta đi!\""})
		pops.append({"t": 6.0, "text": "Donate dồn dập: +%s" % g.fmt_money(int(res["rally"]))})
	elif int(res.get("donate", 0)) > 0 and g.day > 2:
		var n: int = mini(3, 1 + int(res["viewers"]) / 40)
		for i in n:
			pops.append({"t": 2.5 + float(i) * 2.5, "text": "Donate %s: \"%s\"" % [g.fmt_money(int(res["donate"]) / n), str(info["chat_good"].pick_random()) if info["chat_good"].size() > 0 else "Cố lên!"]})
	info["popups"] = pops
	hud.show_live(info, done)


# ====================================================================== lưu / tải / menu

func _show_title() -> void:
	hud.show_panels(false)
	in_room = true
	player.teleport(OFFICE_ORIGIN + Vector3(-3.0, 1.0, -1.2), 0.0)
	hud.fade_from_black(1.0)
	var any: bool = false
	for i in range(1, GameState.SAVE_SLOTS + 1):
		if not GameState.slot_info(i).is_empty():
			any = true
	hud.show_menu("NỢ 60 NGÀY", "Bị AI cướp việc, nợ 100 triệu, 60 ngày để trả.", [
		{"label": "Chơi mới", "cb": func(): hud.transition(_show_intro, 0.8)},
		{"label": "Tải game", "disabled": not any, "cb": _menu_load.bind(_show_title)},
		{"label": "Thoát", "cb": _quit}])


func _menu_pause() -> void:
	if GameState.finished:
		return
	hud.show_menu("TẠM DỪNG", "Ngày %d · %s. Chỉ lưu được khi đang chơi tự do (không trong đoạn cắt cảnh)." % [GameState.day, GameState.clock_str()], [
		{"label": "Tiếp tục", "cb": _noop},
		{"label": "Lưu game", "disabled": not game_live, "cb": _menu_save},
		{"label": "Tải game", "cb": _menu_load.bind(_menu_pause)},
		{"label": "Về màn hình chính", "cb": _to_title},
		{"label": "Thoát game", "cb": _quit}])


func _menu_save() -> void:
	var opts: Array = []
	for i in range(1, GameState.SAVE_SLOTS + 1):
		opts.append({"label": GameState.slot_label(i), "cb": _save_to.bind(i)})
	opts.append({"label": "Quay lại", "cb": _menu_pause})
	hud.show_menu("LƯU GAME", "Chọn ô để lưu (ô đã có sẽ bị ghi đè):", opts)


func _save_to(slot: int) -> void:
	var extra: Dictionary = {"in_room": in_room, "pos": [player.global_position.x, player.global_position.y, player.global_position.z], "yaw": player.rotation.y}
	if GameState.save_game(slot, extra):
		hud.toast("Đã lưu vào ô %d" % slot, 2.5)
	else:
		hud.toast("Không lưu được!", 2.5)


func _menu_load(back: Callable) -> void:
	var opts: Array = []
	for i in range(1, GameState.SAVE_SLOTS + 1):
		var empty: bool = GameState.slot_info(i).is_empty()
		opts.append({"label": GameState.slot_label(i), "disabled": empty, "cb": _load_from.bind(i)})
	opts.append({"label": "Quay lại", "cb": back})
	hud.show_menu("TẢI GAME", "Chọn bản lưu:", opts)


func _load_from(slot: int) -> void:
	GameState.pending_load = slot
	hud.transition(_reload_scene, 0.6)


func _to_title() -> void:
	GameState.pending_load = 0
	hud.transition(_reload_scene, 0.6)


func _reload_scene() -> void:
	get_tree().reload_current_scene()


func _resume_from_save(extra: Dictionary) -> void:
	var g = GameState
	hud.show_panels(true)
	if g.flags.has("site_open") and is_instance_valid(site_gate):
		_set_active(site_gate, false)
		site_gate.remove_meta("interact")
	_spawn_street_items()
	in_room = bool(extra.get("in_room", true))
	if in_room:
		_enter_room(g.new_house)
	else:
		var p: Array = extra.get("pos", [0, 1, 0])
		player.teleport(Vector3(float(p[0]), float(p[1]) + 0.1, float(p[2])), float(extra.get("yaw", 0.0)))
	game_live = true
	_reset_wives()
	_update_world()
	_apply_time()
	hud.fade_from_black(0.8)
	hud.toast("Đã tải game: ngày %d, %s" % [g.day, g.clock_str()], 3.0)


# ====================================================================== phòng & di chuyển

func _enter_room(new_h: bool) -> void:
	var origin: Vector3 = NEW_ORIGIN if new_h else OLD_ORIGIN
	var sz: Vector3 = NEW_SIZE if new_h else OLD_SIZE
	var spot: Dictionary = door_spots["door_new" if new_h else "door_old"]
	exit_pos = spot["pos"]
	exit_yaw = float(spot["yaw"])
	player.teleport(origin + Vector3(0, 1.0, sz.z / 2.0 - 1.4), 0.0)
	in_room = true


func _go_room(new_h: bool) -> void:
	hud.transition(_enter_room.bind(new_h))


func _exit_room() -> void:
	player.teleport(exit_pos, exit_yaw)
	in_room = false


func _noop() -> void:
	pass


# ====================================================================== luồng ngày

# ---------------------------------------------------------------------- INTRO
# Văn phòng -> (Linh báo lên gặp giám đốc) -> lên luôn / lên sau (nhặt báo cáo)
# -> phòng giám đốc nghe bị đuổi việc -> nhận giấy cho nghỉ việc -> vào game.

const MOVE_HINT: String = "Di chuyển: W A S D  ·  Nhìn: chuột  ·  Chạy: Shift  ·  Nhặt / tương tác: E"


## Hiện một câu thoại ở khung dưới màn hình, đọc thành tiếng (vid = tên file giọng trong res://voice/).
func _say(speaker: String, text: String, next: Callable, vid: String = "") -> void:
	hud.show_menu(speaker, text, [{"label": "Tiếp tục", "cb": next}], text, vid)


func _show_intro() -> void:
	in_room = true
	intro_took_report = false
	hud.show_panels(false)
	player.teleport(OFFICE_ORIGIN + Vector3(-3.0, 1.0, -1.2), 0.0)
	_say("VĂN PHÒNG  ·  4:45 CHIỀU", "Một buổi chiều như mọi buổi chiều. Màn hình đầy bảng số liệu, và trên bàn bạn là bản báo cáo tuần chưa nộp.", _intro_linh, "intro_01")


func _intro_linh() -> void:
	linh.visible = true
	var t: String = "Anh ơi! Giám đốc bảo anh lên phòng gặp ông ấy ngay ạ."
	hud.show_menu("Linh (đồng nghiệp)", t, [
		{"label": "Lên gặp giám đốc luôn", "cb": _intro_go_now},
		{"label": "Để mình lên sau một chút", "cb": _intro_go_later}], t, "intro_02")


func _intro_go_now() -> void:
	_say("Linh (đồng nghiệp)", "Dạ, em báo lại với sếp nhé. Anh lên phòng giám đốc đi ạ.", _intro_boss, "intro_03")


func _intro_go_later() -> void:
	_say("Linh (đồng nghiệp)", "Dạ... anh nhớ lên sớm nhé. Nhìn sếp có vẻ không vui lắm.", _intro_think, "intro_04")


func _intro_think() -> void:
	linh.visible = false
	_say("Tôi (nghĩ thầm)", "Chắc là cần mình nộp báo cáo đây.", _intro_report_task, "intro_05")


func _intro_report_task() -> void:
	hud.set_hint(MOVE_HINT)
	hud.set_objective("Nhìn xuống bàn làm việc của bạn và bấm E để nhặt bản báo cáo")
	office_report.set_meta("interact", "report")


func _intro_take_report(t: Node) -> void:
	t.remove_meta("interact")
	(t as Node3D).visible = false
	(t as CollisionObject3D).collision_layer = 0
	intro_took_report = true
	hud.set_objective("")
	_say("Tôi (nghĩ thầm)", "Đủ rồi. Mang lên phòng giám đốc thôi.", _intro_boss, "intro_06")


func _intro_boss() -> void:
	hud.set_hint("")
	hud.set_objective("")
	hud.transition(_intro_boss_enter)


func _intro_boss_enter() -> void:
	linh.visible = false
	player.teleport(BOSS_ORIGIN + Vector3(0, 1.0, 1.2), 0.0)
	_say("PHÒNG GIÁM ĐỐC", "Căn phòng im lặng đến mức nghe rõ tiếng điều hòa. Giám đốc ngồi sau bàn, chưa ngẩng đầu lên ngay.", _intro_boss_1, "intro_07")


func _intro_boss_1() -> void:
	if intro_took_report:
		_say("Giám đốc", "Ngồi đi. Tôi sẽ nói thẳng, vì tôi biết cậu không thích vòng vo. Báo cáo cậu cứ để đó, có lẽ cũng không cần đọc nữa.", _intro_boss_2, "intro_08b")
	else:
		_say("Giám đốc", "Ngồi đi. Tôi sẽ nói thẳng, vì tôi biết cậu không thích vòng vo.", _intro_boss_2, "intro_08")


func _intro_boss_2() -> void:
	_say("Giám đốc", "Tuần trước công ty đã đưa hệ thống AI mới vào vận hành. Nó làm việc của cậu nhanh hơn, rẻ hơn, và không bao giờ xin nghỉ phép.", _intro_boss_3, "intro_09")


func _intro_boss_3() -> void:
	_say("Tôi", "Ý sếp là... tôi bị cho nghỉ việc?", _intro_boss_4, "intro_10")


func _intro_boss_4() -> void:
	_say("Giám đốc", "Tôi rất tiếc. Hôm nay là ngày làm việc cuối cùng của cậu. Giấy cho nghỉ việc để trên bàn, cậu nhận đi.", _intro_paper_task, "intro_11")


func _intro_paper_task() -> void:
	hud.set_hint(MOVE_HINT)
	hud.set_objective("Bấm E ở bàn giám đốc để nhận giấy cho nghỉ việc")
	boss_paper.set_meta("interact", "paper")


func _intro_take_paper(t: Node) -> void:
	t.remove_meta("interact")
	(t as Node3D).visible = false
	(t as CollisionObject3D).collision_layer = 0
	hud.set_objective("")
	hud.set_hint("")
	_say("RỜI CÔNG TY", "Bạn cầm tờ giấy lên. Chữ ký, con dấu đỏ, và cái tên của bạn. Ngần ấy năm làm việc, hóa ra chỉ cần một tờ giấy để kết thúc.", _intro_end, "intro_12")


func _intro_end() -> void:
	hud.transition(_intro_end_mid, 1.2)


func _intro_end_mid() -> void:
	_start_day()


# ---------------------------------------------------------------------- NGÀY 1
# Độc thoại về khoản nợ -> chuyển cảnh đến máy tính ở góc phòng -> quyết định
# thử livestream -> hiện giao diện chơi, thẻ "NGÀY 1", bắt đầu chơi bình thường.

func _day1_opening() -> void:
	hud.show_panels(false)
	for w in wives:
		(w as Node3D).visible = false
	_say("Tôi (độc thoại)", "Bị đuổi việc rồi... Phải làm gì để trả hết số nợ này đây?", _day1_to_pc, "day1_01")


func _day1_to_pc() -> void:
	hud.transition(_day1_at_pc, 0.8)


func _day1_at_pc() -> void:
	var origin: Vector3 = NEW_ORIGIN if GameState.new_house else OLD_ORIGIN
	var sz: Vector3 = NEW_SIZE if GameState.new_house else OLD_SIZE
	player.teleport(origin + Vector3(sz.x / 2.0 - 1.2, 1.0, -sz.z / 2.0 + 2.0), 0.0)
	player.set_pitch(-0.3)
	_say("Tôi (độc thoại)", "Mình thử làm livestream vậy. Dù gì thì mình cũng chỉ biết chơi game, trong lúc tìm việc mới.", _day1_begin, "day1_02")


func _day1_begin() -> void:
	hud.transition(_day1_wife_home, 0.8)


## Vợ đi làm về, nhắc tiền nhà
func _day1_wife_home() -> void:
	var origin: Vector3 = OLD_ORIGIN
	var w: Node3D = wives[0]
	w.visible = true
	w.position = Vector3(0.6, 0.8, OLD_SIZE.z / 2.0 - 0.9)
	player.teleport(origin + Vector3(0.2, 1.0, -0.6), PI)
	_say("Vợ", "Tiền nhà tháng này sắp phải đóng rồi, mà giờ không có tiền thì chúng mình làm sao đây?", _day1_knock, "day1_03")


## Có người đập cửa
func _day1_knock() -> void:
	(wives[0] as Node3D).position = wives[0].get_meta("home_pos")
	hud.play_sfx("res://sfx/knock.wav")
	_say("", "RẦM! RẦM! RẦM! Có ai đó đang đập cửa rất mạnh.", _day1_door, "day1_04")


func _day1_door() -> void:
	hud.transition(_day1_door_mid, 0.6)


func _day1_door_mid() -> void:
	var spot: Dictionary = door_spots["door_old"]
	creditor_npc.visible = true
	player.teleport(spot["pos"], float(spot["yaw"]))
	_say("Chủ nợ", "Còn 2 tháng nữa phải đóng hết số tiền 100 triệu. Lo mà trả đi, không thì mày và vợ mày tới công chuyện với tao.", _day1_reply, "day1_05")


func _day1_reply() -> void:
	var t: String = "Bạn trả lời thế nào?"
	hud.show_menu("Tôi", t, [
		{"label": "\"Em biết rồi, anh đi về đi, đừng đập nữa. Em sẽ trả đủ cho anh trong vòng 2 tháng.\"", "cb": _day1_polite},
		{"label": "\"Biến mẹ về đi, tao khắc trả, lèo nhèo.\"", "cb": _day1_rude}])


func _day1_polite() -> void:
	GameState.flags["creditor_polite"] = true
	_say("Chủ nợ", "Mày nên giữ lời hứa thì tốt hơn.", _day1_end, "day1_06")


func _day1_rude() -> void:
	GameState.flags["creditor_rude"] = true
	GameState.debt_total += GameState.RUDE_PENALTY
	GameState.danger = mini(100, GameState.danger + 10)
	GameState.changed.emit()
	_say("Chủ nợ", "Á à, mày thích thái độ với tao à? Nhớ đấy.", _day1_rude_notice, "day1_07")


func _day1_rude_notice() -> void:
	hud.show_menu("NỢ TĂNG", "Chủ nợ cộng thêm 10 triệu tiền lãi vì thái độ của bạn.\nTổng nợ bây giờ: %s." % GameState.fmt_money(GameState.debt_total), [{"label": "Tiếp tục", "cb": _day1_end}])


func _day1_end() -> void:
	hud.transition(_day1_begin_mid, 0.8)


func _day1_begin_mid() -> void:
	creditor_npc.visible = false
	_enter_room(false)
	hud.show_panels(true)
	hud.show_day_card(GameState.day, GameState.TOTAL_DAYS)
	hud.set_hint("Q: đồng hồ  ·  E: tương tác  ·  Tab: túi đồ  ·  1-5: chọn đồ  ·  F: dùng  ·  Ngồi vào bàn máy tính để stream")
	get_tree().create_timer(12.0).timeout.connect(hud.set_hint.bind(""))
	game_live = true


func _start_day() -> void:
	_apply_time()
	_spawn_street_items()
	_enter_room(GameState.new_house)
	if GameState.day == 1:
		_day1_opening()
		return
	game_live = true


func _show_event(ev: Dictionary, head: String) -> void:
	var opts: Array = []
	for ch in ev.get("choices", []):
		var choice: Dictionary = ch
		var req: int = int(choice.get("requires_money", 0))
		var lab: String = str(choice.get("label", "OK"))
		if req > 0:
			lab += "  (%s)" % GameState.fmt_money(req)
		opts.append({"label": lab, "disabled": GameState.money < req, "cb": func(): _resolve_choice(ev, choice)})
	var title: String = str(ev.get("title", ""))
	if head != "":
		title = head + "  ·  " + title
	hud.show_menu(title, str(ev.get("text", "")), opts, str(ev.get("text", "")), "ev_" + str(ev.get("id", "")))


func _resolve_choice(ev: Dictionary, choice: Dictionary) -> void:
	var lines: Array = GameState.apply(choice.get("effects", {}))
	_show_result(str(ev.get("title", "")), str(choice.get("result", "")), lines)


func _show_result(title: String, text: String, lines: Array = []) -> void:
	var body: String = text
	if lines.size() > 0:
		body += "\n\n" + "\n".join(PackedStringArray(lines))
	hud.show_menu(title, body, [{"label": "Tiếp tục", "cb": _after_result}], text)


func _after_result() -> void:
	if GameState.finished:
		_show_ending()


func _show_ending() -> void:
	if ending_shown:
		return
	ending_shown = true
	game_live = false
	var all: Dictionary = GameState.data.get("endings", {})
	var e: Dictionary = all.get(GameState.ending_id, {"title": "Kết thúc", "text": ""})
	var g = GameState
	var epi: String = ""
	for k in ["sold_to_ai", "refused_ai"]:
		if g.flags.has(k):
			epi += "\n\n" + str(g.data.get("epilogue", {}).get(k, ""))
	var stats: String = epi + "\n\nNgày %d/%d  ·  Nợ còn lại: %s  ·  Tình cảm vợ: %d\nTổng thu từ stream: %s  ·  Follower: %d" % [
		g.day, g.TOTAL_DAYS, g.fmt_money(g.remaining_debt()), g.wife, g.fmt_money(g.total_stream_income), int(g.followers)]
	hud.show_menu(str(e["title"]), str(e["text"]) + stats, [
		{"label": "Chơi lại", "cb": _restart},
		{"label": "Thoát game", "cb": _quit}], str(e["text"]), "end_" + GameState.ending_id)


func _restart() -> void:
	hud.transition(_reload)


func _reload() -> void:
	GameState.reset()
	get_tree().reload_current_scene()


func _quit() -> void:
	get_tree().quit()


# ====================================================================== tương tác

func _on_interact(t: Node) -> void:
	var kind: String = str(t.get_meta("interact"))
	if kind in ["casino", "jewelry_shop", "shop", "creditor", "junk_npc"] and not _shops_open():
		_show_result("Đóng cửa", "Đã đóng cửa. Mở lại lúc 07:00 sáng. (Sau 23:00 chỉ còn quán ăn mở.)", [])
		return
	match kind:
		"door_old":
			if GameState.new_house:
				hud.toast("Bạn đã dọn sang nhà mới.")
			else:
				_go_room(false)
		"door_new":
			if GameState.new_house:
				_go_room(true)
			else:
				_menu_rent()
		"door_exit":
			hud.transition(_exit_room)
		"desk":
			_menu_desk()
		"bed":
			_menu_bed()
		"wife":
			if GameState.wife_asleep():
				_show_result("Vợ", "Vợ đang ngủ say. Đừng đánh thức cô ấy.", [])
			else:
				_menu_wife()
		"shop":
			_menu_shop("")
		"food":
			if GameState.day == 31 and not GameState.flags.has("story_31"):
				_linh_scene()
			else:
				_menu_food()
		"creditor":
			_menu_creditor("")
		"casino":
			_menu_casino()
		"pile":
			_menu_pile(t)
		"kitchen":
			_menu_kitchen()
		"dinner":
			var r: Dictionary = GameState.eat_dinner()
			_update_world()
			_show_result("Cơm vợ nấu", str(r["text"]), r["lines"])
		"junk_npc":
			_menu_junk("")
		"gate_guard":
			_show_result("Bảo vệ", "Công trường cấm vào. Cậu lảng vảng ở đây làm gì?", [])
		"coil":
			_take_coil()
		"site_dig":
			_menu_site_dig()
		"linh":
			_linh_scene()
		"npc":
			_talk_npc(t)
		"jewelry_shop":
			_menu_jewelry("")
		"site_gate":
			_menu_gate()
		"report":
			_intro_take_report(t)
		"paper":
			_intro_take_paper(t)


func _menu_rent() -> void:
	var g = GameState
	var body: String = "Căn nhà rộng, có góc stream đẹp. Đặt cọc %s, tiền nhà %s/tháng (phòng trọ hiện tại: %s/tháng). Stream trong studio mới được thêm khoảng 30%% view." % [
		g.fmt_money(g.NEW_HOUSE_DEPOSIT), g.fmt_money(g.RENT_NEW), g.fmt_money(g.RENT_OLD)]
	hud.show_menu("Nhà mới cho thuê", body, [
		{"label": "Thuê ngay", "disabled": g.money < g.NEW_HOUSE_DEPOSIT, "cb": _do_rent},
		{"label": "Để sau", "cb": _noop}])


func _do_rent() -> void:
	var r: Dictionary = GameState.rent_new_house()
	if bool(r["ok"]):
		hud.set_objective("")
	hud.toast(str(r["text"]), 3.0)
	if bool(r["ok"]):
		_go_room(true)


func _menu_desk() -> void:
	var g = GameState
	if not g.can_stream():
		_show_result("Máy hỏng", "Máy tính đã hỏng hẳn, không bật được. Hãy mang ra cửa hàng đồ máy tính sửa.", [])
		return
	if g.stream_hours_left() <= 0:
		if g.stream_min_today >= float(g.STREAM_MAX_MIN) - 59.0:
			_show_result("Bàn stream", "Hôm nay bạn đã stream đủ 8 tiếng rồi. Nghỉ thôi.", [])
		else:
			_show_result("Bàn stream", "Sắp nửa đêm rồi, không đủ 1 tiếng để stream nữa.", [])
		return
	var body: String = "Bây giờ là %s. %s, độ bền %d%%. Hôm nay còn stream được %d tiếng.\nGiờ vàng 20:00 - 23:00 đông người xem nhất; ngoài giờ đó người xem ít hơn nhiều.\n\nChọn nội dung:" % [g.clock_str(), g.pc_name(), int(g.pc_dur), g.stream_hours_left()]
	var labels: Dictionary = {
		"game": "Chơi game (ổn định, ít rủi ro)",
		"chat": "Trò chuyện / hài (nhẹ nhàng, hồi tinh thần)",
		"shock": "Thử thách gây sốc (nhiều view, nhưng vợ không thích, dễ bị chửi)",
	}
	var opts: Array = []
	for kind in ["game", "chat", "shock"]:
		opts.append({"label": str(labels[kind]), "cb": func(): _menu_stream_hours(kind)})
	opts.append({"label": "Thôi, chưa stream", "cb": _noop})
	hud.show_menu("Bàn stream", body, opts)


func _menu_stream_hours(kind: String) -> void:
	var g = GameState
	var opts: Array = []
	for h in range(1, mini(4, g.stream_hours_left()) + 1):
		var end_m: int = (int(g.minutes) + h * 60) % 1440
		opts.append({"label": "%d tiếng (đến %02d:%02d)" % [h, end_m / 60, end_m % 60], "cb": func(): _do_stream(kind, float(h))})
	opts.append({"label": "Quay lại", "cb": _menu_desk})
	hud.show_menu("Stream bao lâu?", "Bây giờ là %s. Còn %d tiếng stream hôm nay." % [g.clock_str(), g.stream_hours_left()], opts)


func _do_stream(kind: String, hours: float) -> void:
	var g = GameState
	game_live = false
	stream_kind = kind
	stream_rest = 0.0
	var start: float = g.minutes
	var end: float = start + hours * 60.0
	var at23: float = float(g.WIFE_SLEEP)
	# buổi stream vắt qua 23:00 khi vợ ở nhà -> dừng lại ở 23:00 cho cảnh vợ nhắc
	if start < at23 and end > at23 and start >= float(g.WIFE_HOME) and not g.new_house:
		var h1: float = (at23 - start) / 60.0
		stream_rest = hours - h1
		stream_res = g.do_stream(kind, h1)
		_play_live(stream_res, func(): hud.transition(_stream_2300, 0.8))
	else:
		stream_res = g.do_stream(kind, hours)
		_play_live(stream_res, func(): hud.transition(_stream_done_mid, 0.8))


## 23:00 — vợ đang ngủ trên giường lên tiếng
func _stream_2300() -> void:
	var w: Node3D = wives[1 if GameState.new_house else 0]
	w.visible = true
	w.position = w.get_meta("bed_pos")
	w.rotation = Vector3(0, 0, PI / 2.0)
	var origin: Vector3 = NEW_ORIGIN if GameState.new_house else OLD_ORIGIN
	var sz: Vector3 = NEW_SIZE if GameState.new_house else OLD_SIZE
	player.teleport(origin + Vector3(sz.x / 2.0 - 1.2, 1.0, -sz.z / 2.0 + 1.6), PI / 2.0)
	var t: String = "Anh ơi nghỉ đi, em không ngủ được đâu, sáng quá."
	hud.show_menu("Vợ (từ trên giường)  ·  23:00", t, [
		{"label": "Tắt stream", "cb": _stream_off},
		{"label": "Phớt lờ lời vợ, stream tiếp %s tiếng" % _fmt_h(stream_rest), "cb": _stream_ignore}], t, "stream_wife")


func _fmt_h(h: float) -> String:
	return str(int(h)) if absf(h - round(h)) < 0.01 else ("%.1f" % h).replace(".", ",")


func _stream_off() -> void:
	_say("Tôi", "Tôi off stream ở đây nhé anh em, hẹn gặp lại anh em vào ngày mai.", _stream_done, "stream_off")


func _stream_ignore() -> void:
	var g = GameState
	var extra: Dictionary = g.do_stream(stream_kind, stream_rest)
	g.apply({"wife": -g.IGNORE_WIFE_LOSS})
	for k in ["income", "donate", "ads", "growth"]:
		stream_res[k] = int(stream_res.get(k, 0)) + int(extra.get(k, 0))
	stream_res["hours"] = float(stream_res.get("hours", 0.0)) + float(extra.get("hours", 0.0))
	stream_res["extra_income"] = int(extra["income"])
	hud.transition(_stream_ignored_mid, 0.8)


func _stream_ignored_mid() -> void:
	var arr: Array = GameState.data.get("wife_ignore", [])
	var cmt: String = str(arr.pick_random()) if arr.size() > 0 else "\"Anh cứ làm đi.\""
	var t: String = "Bạn đeo tai nghe, stream tiếp (thêm %s). Vợ trùm chăn, quay mặt vào tường.\n\nTình cảm vợ -%d (còn %d)\n\nVợ: %s" % [
		GameState.fmt_money(int(stream_res.get("extra_income", 0))), GameState.IGNORE_WIFE_LOSS, GameState.wife, cmt]
	hud.show_menu("Phớt lờ lời vợ", t, [{"label": "Tiếp tục", "cb": _stream_done}], "Vợ: " + cmt, "")


func _stream_done() -> void:
	hud.transition(_stream_done_mid, 0.6)


## Bảng kết quả buổi stream
func _stream_done_mid() -> void:
	_reset_wives()
	var r: Dictionary = stream_res
	var g = GameState
	var lines: Array = []
	lines.append("Thời lượng: %s tiếng  ·  Bây giờ là %s" % [_fmt_h(float(r.get("hours", 0.0))), g.clock_str()])
	lines.append("Người xem đông nhất: %d" % int(r.get("viewers", 0)))
	lines.append("Donate: %s  ·  Quảng cáo: %s  ·  Tổng: %s" % [g.fmt_money(int(r.get("donate", 0))), g.fmt_money(int(r.get("ads", 0))), g.fmt_money(int(r.get("income", 0)))])
	lines.append("Follower mới: +%d (tổng %d)" % [int(r.get("growth", 0)), int(g.followers)])
	if r.has("chat") and r["chat"].size() > 0:
		lines.append("Chat: " + "  ·  ".join(PackedStringArray(r["chat"])))
	for n in r.get("notes", []):
		lines.append(str(n))
	if r.has("lines") and r["lines"].size() > 0:
		lines.append(", ".join(PackedStringArray(r["lines"])))
	hud.show_menu("KẾT THÚC BUỔI STREAM", "\n".join(PackedStringArray(lines)), [{"label": "Tiếp tục", "cb": _resume_play}])


func _menu_bed() -> void:
	var g = GameState
	var body: String = "Bây giờ là %s. Đi ngủ luôn đến 06:00 sáng mai?\n(Nếu không, 00:00 bạn sẽ tự đi ngủ.)" % g.clock_str()
	hud.show_menu("Đi ngủ", body, [
		{"label": "Ngủ đến 06:00", "cb": _sleep_now},
		{"label": "Chưa ngủ", "cb": _noop}])


func _sleep_now() -> void:
	game_live = false
	hud.transition(_sleep_mid, 1.0)


func _sleep_mid() -> void:
	_clear_robbers()
	_reset_wives()
	var lines: Array = GameState.sleep_early()
	_show_night_panel(lines, false)


func _menu_wife() -> void:
	var left: int = GameState.WIFE_TALK_MAX - GameState.talks_today
	var opts: Array = [{"label": "Nói chuyện (còn %d lần hôm nay)" % left, "disabled": left <= 0, "cb": _do_talk}]
	var has_j: bool = not _owned_of_type("jewelry").is_empty()
	opts.append({"label": "Tặng quà (trang sức)" if has_j else "Tặng quà (chưa có trang sức)", "disabled": not has_j, "cb": _menu_gift})
	opts.append({"label": "Thôi", "cb": _noop})
	hud.show_menu("Vợ", "Vợ đang ngồi nghỉ sau giờ làm, nhìn bạn. Tình cảm hiện tại: %d/100." % GameState.wife, opts)


func _owned_of_type(t: String) -> Array:
	var g = GameState
	var out: Array = []
	for id in g.items_db.get("items", {}).keys():
		if str(g.item_info(id).get("type", "")) == t and g.has_item(id):
			out.append(id)
	return out


func _menu_gift() -> void:
	var g = GameState
	var opts: Array = []
	for id in _owned_of_type("jewelry"):
		opts.append({"label": "%s (x%d)" % [g.item_name(id), g.count_item(id)], "cb": func(): _do_gift(id)})
	opts.append({"label": "Thôi", "cb": _noop})
	hud.show_menu("Tặng quà cho vợ", "Chọn món trang sức muốn tặng:", opts)


func _do_gift(id: String) -> void:
	var r: Dictionary = GameState.gift_wife(id)
	_show_result("Tặng quà", str(r["text"]), r["lines"])


func _do_talk() -> void:
	var r: Dictionary = GameState.talk_wife()
	_show_result("Vợ", str(r["text"]), r["lines"])


# ---------------------------------------------------------------- cửa hàng đồ máy tính

func _menu_shop(note: String) -> void:
	var g = GameState
	var body: String = (note + "\n\n") if note != "" else ""
	body += "Chủ cửa hàng: \"Đồ nghề xịn thì stream mới có người xem, donate mới về.\"\nĐang dùng: %s (độ bền %d%%), %d món đồ stream." % [g.pc_name(), int(g.pc_dur), g.gear.size()]
	hud.show_menu("Cửa hàng đồ máy tính", body, [
		{"label": "Xem dàn máy tính", "cb": _menu_shop_pc},
		{"label": "Xem đồ stream (mic, webcam, đèn, phông xanh, game)", "cb": _menu_shop_gear},
		{"label": "Sửa máy (800k, độ bền +40)", "disabled": g.money < 800000 or g.pc_dur >= 100.0, "cb": _shop_repair},
		{"label": "Rời đi", "cb": _noop}])


func _menu_shop_pc() -> void:
	var g = GameState
	var opts: Array = []
	var p: Array = g.pcs()
	for i in range(1, p.size()):
		var tier: int = i + 1
		var price: int = int(p[i]["price"])
		var lab: String = "%s — %s (+%d%% người xem)" % [str(p[i]["name"]), g.fmt_money(price), int(p[i]["view"])]
		if tier <= g.pc_level:
			lab = "%s — đã có" % str(p[i]["name"])
		opts.append({"label": lab, "disabled": tier <= g.pc_level or g.money < price, "cb": func(): _shop_after(g.buy_pc_tier(tier), _menu_shop_pc)})
	opts.append({"label": "Quay lại", "cb": func(): _menu_shop("")})
	hud.show_menu("Dàn máy tính", "Máy mạnh hơn: stream mượt, ít treo, nhiều người xem hơn. Bạn có %s." % g.fmt_money(g.money), opts)


func _menu_shop_gear() -> void:
	var g = GameState
	var opts: Array = []
	var all: Dictionary = g.items_db.get("gear", {})
	for id in all.keys():
		var it: Dictionary = all[id]
		var price: int = int(it["price"])
		var owned: bool = g.gear.has(id)
		var lab: String = "%s — %s (+%d%% xem, +%d%% donate)" % [str(it["name"]), g.fmt_money(price), int(it.get("view", 0)), int(it.get("donate", 0))]
		if owned:
			lab = "%s — đã có" % str(it["name"])
		var locked: bool = it.has("needs") and not g.gear.has(str(it["needs"]))
		if locked and not owned:
			lab += " (cần %s)" % str(all[str(it["needs"])]["name"])
		opts.append({"label": lab, "disabled": owned or locked or g.money < price, "cb": func(): _shop_after(g.buy_gear(id), _menu_shop_gear)})
	opts.append({"label": "Quay lại", "cb": func(): _menu_shop("")})
	hud.show_menu("Đồ stream", "Bạn có %s." % g.fmt_money(g.money), opts)


func _shop_repair() -> void:
	_shop_after(GameState.repair_pc(), func(): _menu_shop(""))


func _shop_after(r: Dictionary, back: Callable) -> void:
	hud.toast(str(r.get("text", "")), 2.5)
	back.call()


# ---------------------------------------------------------------- quán ăn

func _menu_food() -> void:
	var g = GameState
	var opts: Array = []
	for id in g.items_db.get("food_shop", []):
		var info: Dictionary = g.item_info(id)
		var price: int = int(info.get("buy", 0))
		opts.append({"label": "Mua %s (%s)" % [g.item_name(id).to_lower(), g.fmt_money(price)], "disabled": g.money < price, "cb": func(): _food_buy(id)})
	opts.append({"label": "Rủ vợ đi ăn (600k, tăng tình cảm)", "disabled": g.money < 600000, "cb": func(): _do_eat("date")})
	opts.append({"label": "Rời đi", "cb": _noop})
	hud.show_menu("Quán ăn", "Đồ mua sẽ vào túi đồ. Chọn trên thanh nhanh (1-5) rồi bấm F để ăn uống. Bạn có %s." % g.fmt_money(g.money), opts)


func _food_buy(id: String) -> void:
	var r: Dictionary = GameState.buy_item(id)
	hud.toast(str(r["text"]), 2.0)
	_menu_food()


# ---------------------------------------------------------------- chú Tư ve chai

func _menu_junk(note: String) -> void:
	var g = GameState
	var body: String = (note + "\n\n") if note != "" else ""
	body += "Chú Tư: \"Ve chai, đồng nát chú mua hết. Vàng bạc thì cháu mang sang tiệm vàng cạnh quán ăn ấy. À, chú còn có lockpick nếu cháu cần.\""
	var junk_n: int = 0
	for id in _owned_of_type("junk"):
		junk_n += g.count_item(id)
	var opts: Array = [{"label": "Bán hết ve chai (%d món)" % junk_n, "disabled": junk_n == 0, "cb": func(): _junk_after(g.sell_all_junk())}]
	for id in _owned_of_type("valuable"):
		var price: int = int(g.item_info(id).get("sell", 0))
		opts.append({"label": "Bán %s (%s/cái, có %d)" % [g.item_name(id).to_lower(), g.fmt_money(price), g.count_item(id)], "cb": func(): _junk_after(g.sell_items(id, 1))})
	var lp: int = int(g.item_info("lockpick").get("buy", 150000))
	if g.day >= g.LOCKPICK_DAY:
		opts.append({"label": "Mua lockpick (%s)" % g.fmt_money(lp), "disabled": g.money < lp, "cb": func(): _junk_after(g.buy_item("lockpick"))})
	opts.append({"label": "Rời đi", "cb": _noop})
	hud.show_menu("Chú Tư ve chai", body, opts)


# ---------------------------------------------------------------- nói chuyện với người đi đường

func _talk_npc(t: Node) -> void:
	var g = GameState
	var lines: Dictionary = g.data.get("npc_lines", {})
	var pool: Array = []
	pool.append_array(lines.get("general", []))
	var h: int = g.hour()
	if h < 11:
		pool.append_array(lines.get("morning", []))
	elif h >= 18:
		pool.append_array(lines.get("evening", []))
	if bool(t.get_meta("in_group", false)):
		pool.append_array(lines.get("group", []))
	if g.followers >= 100.0:
		for _i in 3:
			pool.append_array(lines.get("fan", []))
	if g.danger >= 50:
		pool.append_array(lines.get("danger", []))
	var text: String = str(pool.pick_random()) if pool.size() > 0 else "Chào cậu."
	var who: String = "%s (%s)" % [str(t.get_meta("npc_name", "Người qua đường")), str(t.get_meta("npc_role", ""))]
	if t is Node3D:
		var to_p: Vector3 = player.global_position - (t as Node3D).global_position
		(t as Node3D).rotation.y = atan2(-to_p.x, -to_p.z)
	_say(who, text, _noop, "")


# ---------------------------------------------------------------- tiệm vàng bạc

func _menu_jewelry(note: String) -> void:
	var g = GameState
	var body: String = (note + "\n\n") if note != "" else ""
	body += "Chủ tiệm: \"Vàng bạc thật thì tiệm mua giá tốt. Muốn mua quà tặng vợ cũng có đây.\" Bạn có %s." % g.fmt_money(g.money)
	hud.show_menu("Tiệm vàng bạc", body, [
		{"label": "Bán trang sức", "disabled": _owned_of_type("jewelry").is_empty(), "cb": _menu_jewelry_sell},
		{"label": "Mua trang sức (để tặng vợ)", "cb": _menu_jewelry_buy},
		{"label": "Rời đi", "cb": _noop}])


func _menu_jewelry_sell() -> void:
	var g = GameState
	var opts: Array = []
	for id in _owned_of_type("jewelry"):
		var price: int = int(g.item_info(id).get("sell", 0))
		opts.append({"label": "Bán %s (%s, có %d)" % [g.item_name(id).to_lower(), g.fmt_money(price), g.count_item(id)], "cb": func(): _jewelry_after(g.sell_items(id, 1), _menu_jewelry_sell)})
	opts.append({"label": "Quay lại", "cb": func(): _menu_jewelry("")})
	hud.show_menu("Bán trang sức", "Chọn món muốn bán:", opts)


func _menu_jewelry_buy() -> void:
	var g = GameState
	var opts: Array = []
	for id in g.items_db.get("items", {}).keys():
		var info: Dictionary = g.item_info(id)
		if str(info.get("type", "")) != "jewelry":
			continue
		var price: int = int(info.get("buy", 0))
		opts.append({"label": "%s — %s (+%d tình cảm khi tặng)" % [g.item_name(id), g.fmt_money(price), int(info.get("gift", 0))], "disabled": g.money < price, "cb": func(): _jewelry_after(g.buy_item(id), _menu_jewelry_buy)})
	opts.append({"label": "Quay lại", "cb": func(): _menu_jewelry("")})
	hud.show_menu("Mua trang sức", "Bạn có %s. Đồ mua sẽ vào túi đồ." % g.fmt_money(g.money), opts)


func _jewelry_after(r: Dictionary, back: Callable) -> void:
	hud.toast(str(r.get("text", "")), 2.5)
	if _owned_of_type("jewelry").is_empty() and back == Callable(self, "_menu_jewelry_sell"):
		_menu_jewelry(str(r.get("text", "")))
		return
	back.call()


func _junk_after(r: Dictionary) -> void:
	if hud.menu_open:
		return
	_menu_junk(str(r.get("text", "")))


# ---------------------------------------------------------------- cổng công trường

func _menu_gate() -> void:
	var g = GameState
	if g.flags.has("site_open"):
		return
	if g.day < g.SITE_DAY:
		_show_result("Bảo vệ", "Này! Công trường cấm vào, đi chỗ khác chơi!", [])
		return
	if not g.has_item("lockpick"):
		_show_result("Cổng công trường", "Cánh cổng tôn bị khóa bằng một ổ khóa rỉ sét. Cần lockpick để cạy.", [])
		return
	hud.show_menu("Cổng công trường", "Ổ khóa rỉ sét. Bạn có %d lockpick. Thử cạy? (khoảng 15 phút, lockpick có thể gãy)\nBên trong vẫn có bảo vệ đi tuần với đèn pin. Giữ Ctrl để cúi người, khó bị phát hiện hơn." % g.count_item("lockpick"), [
		{"label": "Cạy khóa", "cb": _do_pick},
		{"label": "Thôi", "cb": _noop}])


func _do_pick() -> void:
	var r: Dictionary = GameState.pick_lock()
	if bool(r["ok"]) and is_instance_valid(site_gate):
		site_gate.visible = false
		site_gate.collision_layer = 0
		site_gate.remove_meta("interact")
		hud.set_objective("")
	_show_result("Cạy khóa", str(r["text"]), [])


# ---------------------------------------------------------------- dùng đồ, hướng dẫn

func _use_item() -> void:
	if hud.menu_open or hud.fading or not game_live:
		return
	var r: Dictionary = GameState.use_selected()
	var t: String = str(r["text"])
	if r.has("lines") and r["lines"].size() > 0:
		t += "  (" + ", ".join(PackedStringArray(r["lines"])) + ")"
	hud.toast(t, 3.0)


func _on_item_first(id: String) -> void:
	if id != "lockpick":
		return
	call_deferred("_lockpick_tutorial")


func _lockpick_tutorial() -> void:
	var t: String = "Bạn vừa có một chiếc lockpick — dụng cụ cạy khóa.\n\nKhu CÔNG TRƯỜNG BỎ HOANG (hàng rào tôn, cạnh nhà cho thuê) có cổng đang khóa và bảo vệ canh suốt ngày đêm. Phải chờ thời cơ khi bảo vệ không gác cổng, rồi đến nhìn vào ổ khóa và bấm E để cạy."
	if hud.menu_open:
		await get_tree().create_timer(0.1).timeout
		while hud.menu_open:
			await get_tree().process_frame
	hud.show_menu("HƯỚNG DẪN: LOCKPICK", t, [{"label": "Đã hiểu", "cb": _noop}], t, "tut_lockpick")
	hud.set_objective("Chờ thời cơ cạy cổng công trường bỏ hoang")


func _menu_kitchen() -> void:
	var g = GameState
	hud.show_menu("Góc bếp", "Bình nước lọc và vài gói mì tôm trong tủ.", [
		{"label": "Uống nước (miễn phí, 5 phút)", "cb": func(): _do_eat("water")},
		{"label": "Nấu mì tôm (15k, 20 phút)", "disabled": g.money < 15000, "cb": func(): _do_eat("noodle")},
		{"label": "Thôi", "cb": _noop}])


func _do_eat(kind: String) -> void:
	var r: Dictionary = GameState.eat(kind)
	_show_result("Quán ăn", str(r["text"]), r["lines"])


func _menu_creditor(note: String) -> void:
	var g = GameState
	var m: Dictionary = g.next_milestone()
	var body: String = ""
	if note != "":
		body = note + "\n\n"
	body += "Nợ còn lại: %s\nĐã trả: %s\nMốc kế tiếp: ngày %d, cần tổng đã trả %s (còn thiếu %s)\nTiền trong túi: %s" % [
		g.fmt_money(g.remaining_debt()), g.fmt_money(g.paid), int(m["day"]), g.fmt_money(int(m["need"])),
		g.fmt_money(maxi(0, int(m["need"]) - g.paid)), g.fmt_money(g.money)]
	var opts: Array = []
	for amt in [1_000_000, 5_000_000, 10_000_000]:
		opts.append({"label": "Trả %s" % g.fmt_money(amt), "disabled": g.money < amt, "cb": func(): _pay(amt)})
	opts.append({"label": "Trả hết số tiền đang có", "disabled": g.money <= 0, "cb": func(): _pay(GameState.money)})
	opts.append({"label": "Rời đi", "cb": _noop})
	hud.show_menu("Nhà chủ nợ", body, opts)


func _pay(amount: int) -> void:
	var a: int = GameState.pay_debt(amount)
	if GameState.finished:
		_show_ending()
		return
	_menu_creditor("Bạn đã trả %s." % GameState.fmt_money(a))


func _menu_casino() -> void:
	var g = GameState
	if g.hour() < 14:
		_show_result("Đóng cửa", "Chỗ này chỉ mở từ 14:00 trở đi. Bây giờ mới %s." % g.clock_str(), [])
		return
	var body: String = "Đỏ đen: cược gấp đôi, nhưng xác suất thắng chỉ khoảng 47%. Mỗi ván mất khoảng 30 phút, việc chạy hàng mất 3 tiếng, và vợ có thể phát hiện."
	var opts: Array = []
	for bet in [200_000, 1_000_000, 5_000_000]:
		opts.append({"label": "Cược %s" % g.fmt_money(bet), "disabled": g.money < bet, "cb": func(): _menu_color(bet)})
	opts.append({"label": "All-in (tất cả tiền đang có)", "disabled": g.money <= 0, "cb": func(): _menu_color(GameState.money)})
	opts.append({"label": "Nhận việc chạy hàng lạ (+1,5–3tr, rủi ro bị đánh)", "cb": _do_gray})
	opts.append({"label": "Vay nóng 10tr (nợ tăng thêm 13tr, nguy hiểm tăng)", "cb": _do_loan})
	opts.append({"label": "Rời đi", "cb": _noop})
	hud.show_menu("Chỗ đỏ đen", body, opts)


func _menu_color(bet: int) -> void:
	hud.show_menu("Chọn màu", "Bạn cược %s. Chọn màu:" % GameState.fmt_money(bet), [
		{"label": "ĐỎ", "cb": func(): _do_gamble(bet, true)},
		{"label": "ĐEN", "cb": func(): _do_gamble(bet, false)},
		{"label": "Thôi, không cược", "cb": _noop}])


func _do_gamble(bet: int, red: bool) -> void:
	var r: Dictionary = GameState.gamble(bet, red)
	_show_result("Đỏ đen", str(r["text"]), r["lines"])


func _do_gray() -> void:
	var r: Dictionary = GameState.gray_job()
	_show_result("Việc xám", str(r["text"]), r["lines"])


func _do_loan() -> void:
	var r: Dictionary = GameState.take_loan()
	_show_result("Vay nóng", str(r["text"]), r["lines"])


func _menu_pile(t: Node) -> void:
	var kind: String = str(t.get_meta("pile", "trash"))
	var name_txt: String = "Đụn rác" if kind == "trash" else "Đụn lá"
	var body: String = "Một đụn rác bốc mùi nằm trên vỉa hè. Biết đâu có thứ gì đáng giá?" if kind == "trash" else "Một đụn lá khô ai đó quét dồn lại. Biết đâu có gì bên dưới?"
	body += " Bới mất khoảng 20 phút."
	hud.show_menu(name_txt, body, [
		{"label": "Bới tìm", "cb": func(): _dig_pile(t)},
		{"label": "Thôi", "cb": _noop}])


func _dig_pile(t: Node) -> void:
	if not is_instance_valid(t):
		return
	var kind: String = str(t.get_meta("pile", "trash"))
	piles.erase(t)
	t.queue_free()
	var r: Dictionary = GameState.dig_pile(kind)
	_show_result(str(r["title"]), str(r["text"]), r["lines"])
