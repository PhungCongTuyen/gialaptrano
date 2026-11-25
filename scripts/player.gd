extends CharacterBody3D
## Nhân vật góc nhìn thứ nhất: WASD di chuyển, chuột nhìn, Shift chạy, Space nhảy, E tương tác,
## Q giơ tay xem đồng hồ. (Esc mở menu tạm dừng: xử lý trong hud.gd)

signal interact(target: Node)

const SPEED: float = 4.2
const SPRINT: float = 7.0
const JUMP: float = 4.2
const GRAVITY: float = 12.0
const SENS: float = 0.0025

var locked: bool = false
var crouching: bool = false  # Ctrl: cúi người (đi chậm, khó bị bảo vệ phát hiện)
var target: Node = null
var cam: Camera3D
var ray: RayCast3D
var pitch: float = 0.0
var viewmodel: Node3D
var wrist: Node3D      # tay trái (đeo đồng hồ)
var arm_r: Node3D      # tay phải
var watch_label: Label3D
var watch_raised: bool = false
# Hai tay luôn ở mép dưới màn hình (kiểu CS2). Toạ độ theo camera.
const ARM_IDLE_POS: Vector3 = Vector3(0.27, -0.25, -0.46)   # tay phải; tay trái lật dấu x
const ARM_IDLE_ROT: Vector3 = Vector3(0.34, 0.24, -0.3)    # tay phải; tay trái lật dấu y, z
# Xem đồng hồ (kiểu Green Hell): cẳng tay trái nằm ngang từ mép trái, nắm tay, mặt đồng hồ quay về camera
const WRIST_UP: Vector3 = Vector3(-0.035, -0.165, -0.36)
var WRIST_UP_ROT: Vector3 = (Basis(Vector3.UP, -PI / 2.0) * Basis(Vector3.BACK, deg_to_rad(-74.0)) * Basis(Vector3.RIGHT, 0.12)).get_euler()
# Cầm giấy hai tay: bàn tay dựng đứng hai mép, lòng bàn tay hướng vào giấy, ngón cái ở mặt trước
var DOC_ROT_R: Vector3 = (Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0)) * Basis(Vector3.RIGHT, -0.12)).get_euler()
var DOC_ROT_L: Vector3 = (Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0)) * Basis(Vector3.RIGHT, -0.12)).get_euler()
var _w_watch: float = 0.0   # 0..1: mức giơ tay xem đồng hồ
var _w_dig: float = 0.0     # 0..1: mức cúi người bới
var _bob_t: float = 0.0
var _bob_amp: float = 0.0
var _life_t: float = 0.0


func _ready() -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	add_child(cs)

	cam = Camera3D.new()
	cam.position = Vector3(0, 0.7, 0)
	cam.fov = 75.0
	add_child(cam)
	cam.make_current()

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -3.2)
	cam.add_child(ray)
	ray.add_exception(self)
	viewmodel = Node3D.new()
	viewmodel.scale = Vector3.ONE * 0.5  # thu nhỏ & kéo sát camera: hình y hệt nhưng không xuyên tường
	cam.add_child(viewmodel)
	wrist = _make_arm(-1.0, true)
	arm_r = _make_arm(1.0, false)
	_update_arms(0.0)


## Một cánh tay gắn vào camera (trong khung "viewmodel" thu nhỏ 1/2 để không bao giờ xuyên tường).
## Dùng mô hình Blender (models/tay/tay_<tư thế>.glb); thiếu file thì dựng bằng khối hộp.
## Tay trái là bản lật gương của tay phải và có đồng hồ ở cổ tay.
func _make_arm(side: float, watch: bool) -> Node3D:
	var arm: Node3D = Node3D.new()
	viewmodel.add_child(arm)
	var mir: Node3D = Node3D.new()
	mir.name = "mirror"
	mir.scale = Vector3(side, 1, 1)
	arm.add_child(mir)
	if _load_pose_meshes():
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "hand"
		mi.mesh = _pose_meshes["tha_long"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mir.add_child(mi)
		_apply_hand_mats(mi)
	else:
		_box_arm(mir, side)
	var grip: Node3D = Node3D.new()
	grip.name = "grip"
	grip.position = GRIP_POS
	mir.add_child(grip)
	if watch:
		# mặt đồng hồ tròn trên cổ tay (kiểu Green Hell), dây đeo quấn quanh cổ tay
		var strap: MeshInstance3D = MeshInstance3D.new()
		var sb: BoxMesh = BoxMesh.new()
		sb.size = Vector3(0.066, 0.046, 0.022)
		strap.mesh = sb
		strap.position = Vector3(0, 0.0, 0.04)
		var smat: StandardMaterial3D = StandardMaterial3D.new()
		smat.albedo_color = Color(0.1, 0.09, 0.08)
		smat.roughness = 0.8
		strap.material_override = smat
		arm.add_child(strap)
		var case_mi: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.026
		cm.bottom_radius = 0.027
		cm.height = 0.012
		cm.radial_segments = 28
		case_mi.mesh = cm
		case_mi.position = Vector3(0, 0.026, 0.04)
		var cmat: StandardMaterial3D = StandardMaterial3D.new()
		cmat.albedo_color = Color(0.55, 0.22, 0.08)  # vỏ cam đậm
		cmat.roughness = 0.5
		case_mi.material_override = cmat
		arm.add_child(case_mi)
		var face_mi: MeshInstance3D = MeshInstance3D.new()
		var fm: CylinderMesh = CylinderMesh.new()
		fm.top_radius = 0.021
		fm.bottom_radius = 0.021
		fm.height = 0.002
		fm.radial_segments = 28
		face_mi.mesh = fm
		face_mi.position = Vector3(0, 0.0325, 0.04)
		var fmat: StandardMaterial3D = StandardMaterial3D.new()
		fmat.albedo_color = Color(0.05, 0.06, 0.08)
		fmat.roughness = 0.15
		face_mi.material_override = fmat
		arm.add_child(face_mi)
		watch_label = Label3D.new()
		watch_label.position = Vector3(0, 0.0345, 0.04)
		# nằm trên mặt đồng hồ; chữ đứng thẳng khi giơ tay xem (đầu chữ hướng về phía khuỷu... xoay 90°)
		watch_label.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
		watch_label.pixel_size = 0.000125
		watch_label.font_size = 64
		watch_label.outline_size = 0
		watch_label.modulate = Color(0.55, 1.0, 0.65)
		watch_label.double_sided = false
		watch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		watch_label.text = "07:00"
		arm.add_child(watch_label)
	return arm


const HAND_POSES: Array = ["tha_long", "cao", "nam", "kep"]
const GRIP_POS: Vector3 = Vector3(0.0, -0.032, -0.072)  # tâm nắm tay (toạ độ bàn tay)
var _pose_meshes: Dictionary = {}


func _load_pose_meshes() -> bool:
	if not _pose_meshes.is_empty():
		return true
	for p in HAND_POSES:
		var path: String = "res://models/tay/tay_%s.glb" % p
		if not ResourceLoader.exists(path):
			_pose_meshes.clear()
			return false
		var n: Node = (load(path) as PackedScene).instantiate()
		var mis: Array = n.find_children("*", "MeshInstance3D", true, false)
		if not mis.is_empty():
			_pose_meshes[p] = (mis[0] as MeshInstance3D).mesh
		n.free()
	return _pose_meshes.size() == HAND_POSES.size()


func _set_pose(arm: Node3D, pose: String) -> void:
	var hand: MeshInstance3D = arm.get_node_or_null("mirror/hand") as MeshInstance3D
	if hand != null and _pose_meshes.has(pose) and hand.mesh != _pose_meshes[pose]:
		hand.mesh = _pose_meshes[pose]
		_apply_hand_mats(hand)


# ---- chất liệu da / vải / móng cho tay (thay vật liệu trơn trong file glb)
var _mat_skin: StandardMaterial3D
var _mat_cloth: StandardMaterial3D
var _mat_nail: StandardMaterial3D


func _hand_mats() -> void:
	if _mat_skin != null:
		return
	_mat_skin = StandardMaterial3D.new()
	_mat_skin.albedo_color = Color(0.8, 0.62, 0.53)
	_mat_skin.vertex_color_use_as_albedo = true      # đầu ngón, khớp hồng hơn; lòng bàn tay sáng; cẳng tay rám
	_mat_skin.roughness = 0.62
	_mat_skin.specular = 0.35
	_mat_skin.rim_enabled = true                      # viền sáng mềm như da thật
	_mat_skin.rim = 0.15
	_mat_skin.rim_tint = 0.4
	_mat_skin.subsurf_scatter_enabled = true          # ánh sáng xuyên da (Forward+)
	_mat_skin.subsurf_scatter_strength = 0.3
	_mat_skin.subsurf_scatter_skin_mode = true
	_mat_cloth = StandardMaterial3D.new()
	_mat_cloth.albedo_color = Color(0.17, 0.22, 0.34)
	_mat_cloth.roughness = 0.95
	_mat_cloth.specular = 0.15
	_mat_nail = StandardMaterial3D.new()
	_mat_nail.albedo_color = Color(0.86, 0.66, 0.62)
	_mat_nail.roughness = 0.3
	_mat_nail.vertex_color_use_as_albedo = false
	for spec in [[_mat_skin, "da_chi_tiet", "da_normal", "da_nham", 0.05], [_mat_cloth, "vai_chi_tiet", "vai_normal", "", 0.12]]:
		var m: StandardMaterial3D = spec[0]
		var a: String = "res://textures/tay/%s.png" % spec[1]
		if ResourceLoader.exists(a):
			m.albedo_texture = load(a)
		var n: String = "res://textures/tay/%s.png" % spec[2]
		if ResourceLoader.exists(n):
			m.normal_enabled = true
			m.normal_texture = load(n)
			m.normal_scale = 0.7
		if str(spec[3]) != "" and ResourceLoader.exists("res://textures/tay/%s.png" % spec[3]):
			m.roughness_texture = load("res://textures/tay/%s.png" % spec[3])
			m.roughness = 1.0
		# chiếu theo toạ độ của chính bàn tay: lặp mỗi vài cm, không cần UV
		m.uv1_triplanar = true
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3.ONE / float(spec[4])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func _apply_hand_mats(hand: MeshInstance3D) -> void:
	_hand_mats()
	for i in hand.mesh.get_surface_count():
		var sm: Material = hand.mesh.surface_get_material(i)
		var nm: String = sm.resource_name.to_lower() if sm != null else ""
		if nm.begins_with("da"):
			hand.set_surface_override_material(i, _mat_skin)
		elif nm.begins_with("ao"):
			hand.set_surface_override_material(i, _mat_cloth)
		elif nm.begins_with("mong"):
			hand.set_surface_override_material(i, _mat_nail)


func _box_arm(parent: Node3D, side: float) -> void:
	var skin: StandardMaterial3D = _overlay_mat(Color(0.85, 0.65, 0.5))
	var shirt: StandardMaterial3D = _overlay_mat(Color(0.25, 0.3, 0.45))
	for pt in [[Vector3(0.085, 0.07, 0.45), Vector3(0, 0, 0.2), skin], [Vector3(0.11, 0.09, 0.2), Vector3(0, 0, 0.42), shirt],
			[Vector3(0.09, 0.03, 0.12), Vector3(0, -0.006, -0.08), skin]]:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = pt[0]
		mi.mesh = bm
		mi.position = pt[1]
		mi.material_override = pt[2]
		parent.add_child(mi)


func _overlay_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func set_watch(text: String) -> void:
	if watch_label != null:
		watch_label.text = text


func raise_watch(up: bool) -> void:
	watch_raised = up


func set_pitch(p: float) -> void:
	pitch = p
	cam.rotation.x = p


func face(yaw: float) -> void:
	rotation = Vector3(0, yaw, 0)
	pitch = 0.0
	cam.rotation = Vector3.ZERO


func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	face(yaw)


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * SENS)
		pitch = clampf(pitch - event.relative.y * SENS, -1.45, 1.45)
		cam.rotation.x = pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_Q:
			raise_watch(not watch_raised)
		elif event.physical_keycode == KEY_E and target != null:
			interact.emit(target)
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var dir_in: Vector2 = Vector2.ZERO
	var sprint: bool = false
	var jump: bool = false
	if not locked:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			dir_in.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			dir_in.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			dir_in.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			dir_in.x += 1.0
		sprint = Input.is_physical_key_pressed(KEY_SHIFT)
		jump = Input.is_physical_key_pressed(KEY_SPACE)
	crouching = (not locked) and Input.is_physical_key_pressed(KEY_CTRL)
	var cam_h: float = 0.7
	if crouching:
		cam_h = 0.15
	elif dig_time >= 0.0:
		cam_h = 0.25  # cúi người xuống bới
	cam.position.y = lerpf(cam.position.y, cam_h, minf(1.0, delta * 8.0))
	cam.position.z = lerpf(cam.position.z, -0.28 if dig_time >= 0.0 else 0.0, minf(1.0, delta * 8.0))  # chồm về phía trước
	var d: Vector3 = (transform.basis * Vector3(dir_in.x, 0.0, dir_in.y)).normalized()
	var spd: float = SPRINT if sprint else SPEED
	if crouching:
		spd = 1.8
	velocity.x = d.x * spd
	velocity.z = d.z * spd
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif jump:
		velocity.y = JUMP
	move_and_slide()
	var hs: float = Vector2(velocity.x, velocity.z).length()
	_bob_amp = lerpf(_bob_amp, clampf(hs / SPEED, 0.0, 1.6) if is_on_floor() else 0.0, minf(1.0, delta * 8.0))
	_bob_t += delta * (6.0 + hs * 1.2)

	target = null
	if not locked and ray.is_colliding():
		var c: Object = ray.get_collider()
		if c != null and c is Node and (c as Node).has_meta("interact"):
			target = c as Node


# ---------------------------------------------------------------- tư thế hai tay: đứng / đi / xem đồng hồ / bới / cầm đồ

var dig_time: float = -1.0
var dig_len: float = 5.0
var held_id: String = ""        # món đang cầm ở tay phải (ô đang chọn trên thanh đồ)
var held_node: Node3D = null
var doc_kind: String = ""       # "report" / "paper": cầm giấy tờ bằng hai tay (intro)
var doc_node: Node3D = null
var use_time: float = -1.0      # đang ăn / uống
var use_len: float = 1.6
var use_kind: String = ""       # "eat" / "drink"
var _w_hold: float = 0.0
var _w_doc: float = 0.0
var _w_use: float = 0.0

# món -> [model, tỉ lệ, tư thế tay, xoay thêm]
const HOLD_MODELS: Dictionary = {
	"water": ["chai_nuoc", 1.0, "nam"], "bottle": ["chai_nuoc", 0.95, "nam"],
	"soda": ["lon_nuoc", 1.0, "nam"], "can": ["lon_nuoc", 0.95, "nam"],
	"banhmi": ["banh_mi", 1.0, "nam", Vector3(-1.0, 0, 0)], "mi_ly": ["ly_mi", 1.0, "nam"], "com_hop": ["hop_com", 1.0, "nam"],
	"paper": ["to_giay", 0.6, "kep"], "phone_broken": ["dien_thoai", 1.0, "nam"], "lighter": ["bat_lua", 1.0, "nam"],
	"copper": ["cuon_day_dong", 0.8, "nam"], "copper_s": ["cuon_day_dong", 0.6, "nam"], "copper_m": ["cuon_day_dong", 0.8, "nam"],
	"copper_l": ["cuon_day_dong", 1.0, "nam"], "copper_coil": ["cuon_day_dong", 1.5, "nam"],
}


## Bắt đầu động tác bới trong `seconds` giây (người cúi xuống, hai tay cào bới).
func play_dig(seconds: float) -> void:
	dig_len = seconds
	dig_time = 0.0
	watch_raised = false


func stop_dig() -> void:
	dig_time = -1.0


## Động tác ăn ("eat") hoặc uống ("drink") món đang cầm.
func play_use(kind: String, seconds: float = 1.6) -> void:
	use_kind = kind
	use_len = seconds
	use_time = 0.0
	watch_raised = false


## Cầm món `id` ở tay phải ("" = tay không).
func hold_item(id: String) -> void:
	if id == held_id:
		return
	held_id = id
	if held_node != null:
		held_node.queue_free()
		held_node = null
	if id == "":
		return
	held_node = _make_held(id)
	(arm_r.get_node("mirror/grip") as Node3D).add_child(held_node)


func _make_held(id: String) -> Node3D:
	var root: Node3D = Node3D.new()
	var spec: Array = HOLD_MODELS.get(id, [])
	var item: Node3D = null
	if not spec.is_empty() and ResourceLoader.exists("res://models/do_cam/%s.glb" % spec[0]):
		item = (load("res://models/do_cam/%s.glb" % spec[0]) as PackedScene).instantiate()
		item.scale = Vector3.ONE * float(spec[1])
		if spec.size() > 3:
			item.rotation = spec[3]  # xoay thêm cho tự nhiên (vd. bánh mì chúc về trước)
	else:
		item = _small_item_mesh(id)
	root.add_child(item)
	# trục dài của đồ (Y) nằm ngang theo nắm tay (X)
	root.rotation = Vector3(0, 0, PI / 2.0)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Đồ nhỏ không có model Blender: trang sức, lockpick, sắt vụn...
func _small_item_mesh(id: String) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var m: StandardMaterial3D = StandardMaterial3D.new()
	var info: Dictionary = GameState.item_info(id)
	var typ: String = str(info.get("type", ""))
	if typ == "jewelry":
		var tm: TorusMesh = TorusMesh.new()
		var big: bool = id.begins_with("necklace") or id.begins_with("bracelet")
		tm.inner_radius = 0.028 if big else 0.008
		tm.outer_radius = 0.033 if big else 0.011
		mi.mesh = tm
		m.albedo_color = Color(0.95, 0.75, 0.25) if id.ends_with("gold") else Color(0.85, 0.86, 0.9)
		m.metallic = 1.0
		m.roughness = 0.2
		mi.rotation.x = PI / 2.0
	elif id == "lockpick":
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.004, 0.11, 0.008)
		mi.mesh = bm
		m.albedo_color = Color(0.7, 0.7, 0.72)
		m.metallic = 1.0
	else:
		var bm2: BoxMesh = BoxMesh.new()
		bm2.size = Vector3(0.05, 0.08, 0.03)
		mi.mesh = bm2
		m.albedo_color = Color(0.45, 0.42, 0.4)
		m.metallic = 0.6
	mi.material_override = m
	return mi


## Cầm giấy tờ bằng hai tay trước mặt: "report" (bản báo cáo), "paper" (giấy cho nghỉ việc), "" = cất đi.
func hold_document(kind: String) -> void:
	doc_kind = kind
	if doc_node != null:
		doc_node.queue_free()
		doc_node = null
	if kind == "":
		return
	doc_node = Node3D.new()
	var model: String = "bia_bao_cao" if kind == "report" else "to_giay"
	var path: String = "res://models/do_cam/%s.glb" % model
	if ResourceLoader.exists(path):
		doc_node.add_child((load(path) as PackedScene).instantiate())
	else:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.21, 0.297, 0.002)
		mi.mesh = bm
		doc_node.add_child(mi)
	var lb: Label3D = Label3D.new()
	lb.pixel_size = 0.00042
	lb.font_size = 32
	lb.outline_size = 0
	lb.modulate = Color(0.08, 0.08, 0.1)
	lb.width = 420
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.position = Vector3(0, 0.02, 0.0075 if kind == "report" else 0.0035)
	if kind == "report":
		lb.text = "BÁO CÁO CÔNG VIỆC\nQUÝ IV\n\nPhòng Vận hành\nNgười lập: ..."
		lb.modulate = Color(0.95, 0.95, 0.95)
		lb.font_size = 40
	else:
		lb.text = "CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM\nĐộc lập - Tự do - Hạnh phúc\n\nQUYẾT ĐỊNH\nV/v chấm dứt hợp đồng lao động\n\nĐiều 1. Chấm dứt hợp đồng lao động đối với nhân viên kể từ ngày ký.\nLý do: cơ cấu lại nhân sự, ứng dụng hệ thống AI.\n\nGIÁM ĐỐC"
	doc_node.add_child(lb)
	if kind == "paper":
		var stamp: Label3D = Label3D.new()
		stamp.text = "◯"
		stamp.font_size = 160
		stamp.pixel_size = 0.0004
		stamp.modulate = Color(0.85, 0.1, 0.1, 0.8)
		stamp.position = Vector3(0.05, -0.105, 0.004)
		doc_node.add_child(stamp)
	for mi in doc_node.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewmodel.add_child(doc_node)
	doc_node.position = DOC_POS
	doc_node.rotation = DOC_ROT


const DOC_POS: Vector3 = Vector3(0.0, -0.015, -0.43)
const DOC_ROT: Vector3 = Vector3(-0.12, 0.0, 0.0)
const HOLD_POS: Vector3 = Vector3(0.2, -0.2, -0.42)      # tay phải cầm đồ
const HOLD_ROT: Vector3 = Vector3(0.25, 0.3, -1.35)
const MOUTH_POS: Vector3 = Vector3(0.05, -0.12, -0.2)    # đưa lên miệng
const MOUTH_ROT: Vector3 = Vector3(0.55, 0.35, -1.4)


func _process(delta: float) -> void:
	_life_t += delta
	if dig_time >= 0.0:
		dig_time += delta
	if use_time >= 0.0:
		use_time += delta
		if use_time >= use_len:
			use_time = -1.0
	_update_arms(delta)


func _update_arms(delta: float) -> void:
	var k: float = minf(1.0, delta * 10.0) if delta > 0.0 else 1.0
	var k2: float = minf(1.0, delta * 7.0) if delta > 0.0 else 1.0
	_w_watch = lerpf(_w_watch, 1.0 if watch_raised else 0.0, k)
	_w_dig = lerpf(_w_dig, 1.0 if dig_time >= 0.0 else 0.0, k2)
	_w_doc = lerpf(_w_doc, 1.0 if doc_kind != "" else 0.0, k2)
	_w_hold = lerpf(_w_hold, 1.0 if (held_id != "" and doc_kind == "") else 0.0, k2)
	var use_w: float = 0.0
	if use_time >= 0.0:
		use_w = clampf(use_time / 0.35, 0.0, 1.0) * clampf((use_len - use_time) / 0.35, 0.0, 1.0)
	_w_use = use_w
	if held_node != null:
		held_node.visible = doc_kind == "" and dig_time < 0.0
	# tư thế ngón tay
	var pose_r: String = "tha_long"
	var pose_l: String = "tha_long"
	if dig_time >= 0.0:
		pose_r = "cao"
		pose_l = "cao"
	elif doc_kind != "":
		pose_r = "kep"
		pose_l = "kep"
	elif held_id != "":
		pose_r = str(HOLD_MODELS.get(held_id, ["", 1.0, "kep"])[2])
	if watch_raised and dig_time < 0.0 and doc_kind == "":
		pose_l = "nam"
	_set_pose(arm_r, pose_r)
	_set_pose(wrist, pose_l)
	var breathe: float = sin(_life_t * 1.6) * 0.004
	for e in [[wrist, -1.0], [arm_r, 1.0]]:
		var arm: Node3D = e[0]
		var side: float = e[1]
		var bob: Vector3 = Vector3(sin(_bob_t) * 0.012 * side, -absf(cos(_bob_t)) * 0.016, 0.0) * _bob_amp
		var pos: Vector3 = Vector3(ARM_IDLE_POS.x * side, ARM_IDLE_POS.y + breathe, ARM_IDLE_POS.z) + bob
		var rot: Vector3 = Vector3(ARM_IDLE_ROT.x, ARM_IDLE_ROT.y * side, ARM_IDLE_ROT.z * side)
		# tay phải cầm đồ: đưa ra trước, ngón cái hướng lên
		if side > 0.0 and _w_hold > 0.001:
			pos = pos.lerp(HOLD_POS + bob + Vector3(0, breathe, 0), _w_hold)
			rot = rot.lerp(HOLD_ROT, _w_hold)
			if _w_use > 0.001:
				var chew: float = sin(use_time * TAU * 2.2) * 0.012 if use_kind == "eat" else 0.0
				var mrot: Vector3 = MOUTH_ROT + (Vector3(0.6, 0, 0) if use_kind == "drink" else Vector3.ZERO)
				pos = pos.lerp(MOUTH_POS + Vector3(0, chew, 0), _w_use)
				rot = rot.lerp(mrot, _w_use)
		# hai tay cầm giấy tờ ở hai mép dưới
		if _w_doc > 0.001:
			var dp: Vector3 = DOC_POS + Vector3(0.138 * side, -0.165, -0.014)
			var dr: Vector3 = DOC_ROT_R if side > 0.0 else DOC_ROT_L
			pos = pos.lerp(dp + Vector3(0, breathe, 0), _w_doc)
			rot = Quaternion.from_euler(rot).slerp(Quaternion.from_euler(dr), _w_doc).get_euler()
		# bới: hai bàn tay thay nhau cào xuống đụn
		if _w_dig > 0.001:
			var t: float = maxf(dig_time, 0.0)
			var ph: float = t * TAU * 1.7 + (0.0 if side < 0.0 else PI)
			var sc: float = sin(ph)
			var dn: float = maxf(0.0, sc)
			var dpos: Vector3 = Vector3(0.14 * side - 0.035 * side * sc, -0.25 - 0.06 * dn + 0.03 * maxf(0.0, -sc), -0.64 - 0.13 * sc)
			var drot: Vector3 = Vector3(0.12 + 0.35 * dn - 0.12 * maxf(0.0, -sc), 0.32 * side, 0.25 * side * cos(ph))
			pos = pos.lerp(dpos, _w_dig)
			rot = rot.lerp(drot, _w_dig)
		# tay trái giơ lên xem đồng hồ
		if side < 0.0 and _w_watch > 0.001:
			pos = pos.lerp(WRIST_UP, _w_watch)
			rot = Quaternion.from_euler(rot).slerp(Quaternion.from_euler(WRIST_UP_ROT), _w_watch).get_euler()
		arm.position = pos
		arm.rotation = rot
	if doc_node != null:
		doc_node.position = DOC_POS + Vector3(0, breathe, 0)
