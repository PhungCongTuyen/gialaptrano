extends Node3D
## Dựng khu phố kiểu Việt Nam bằng code: dãy nhà ống, biển hiệu, ban công, cửa cuốn,
## cục nóng điều hòa, bồn nước inox, cột điện dây chằng, xe máy, ghế nhựa, cây xanh.
## Mọi thứ dùng một bộ sinh số ngẫu nhiên cố định (seed) nên lần chơi nào khu phố cũng giống nhau.

const FLOOR_H: float = 3.2

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var mats: Dictionary = {}
var window_mats: Array = []     # kính cửa sổ: sáng đèn vào buổi tối
var sign_mats: Array = []       # biển hiệu: phát sáng buổi tối
var lamps: Array = []           # đèn đường (OmniLight3D)
var bike_spots: Array = []
var shutter_tex: ImageTexture
var tile_tex: ImageTexture
var asphalt_tex: ImageTexture

const WALL_COLORS: Array = [
	Color(0.96, 0.87, 0.55), Color(0.93, 0.93, 0.88), Color(0.78, 0.9, 0.82), Color(0.98, 0.8, 0.72),
	Color(0.75, 0.85, 0.95), Color(0.95, 0.75, 0.8), Color(0.9, 0.9, 0.7), Color(0.85, 0.8, 0.72),
	Color(0.97, 0.95, 0.9), Color(0.8, 0.88, 0.7)]
const SHOP_SIGNS: Array = ["TẠP HÓA", "SỬA XE MÁY", "CẮT TÓC NAM", "PHOTO COPY", "NƯỚC MÍA", "THUỐC TÂY",
	"BÁNH MÌ", "ĐIỆN THOẠI", "MAY ĐO", "GẠO - NƯỚC MẮM", "VÁ XE", "CÀ PHÊ"]


func _init() -> void:
	rng.seed = 20261125
	_make_textures()


# ====================================================================== tiện ích

func _make_textures() -> void:
	# cửa cuốn: sọc ngang
	var img: Image = Image.create(4, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		var v: float = 0.62 if y % 2 == 0 else 0.5
		for x in 4:
			img.set_pixel(x, y, Color(v, v, v * 1.02))
	shutter_tex = ImageTexture.create_from_image(img)
	# gạch lát vỉa hè
	var t: Image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var edge: bool = x % 16 == 0 or y % 16 == 0
			var base: float = 0.5 + float((x * 7 + y * 13) % 5) * 0.012
			var c: Color = Color(base, base * 0.96, base * 0.9) if not edge else Color(0.36, 0.34, 0.32)
			if (x / 16 + y / 16) % 2 == 1 and not edge:
				c = Color(0.58, 0.38, 0.3)  # gạch đỏ xen kẽ
			t.set_pixel(x, y, c)
	tile_tex = ImageTexture.create_from_image(t)
	# nhựa đường
	var a: Image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	var r2: RandomNumberGenerator = RandomNumberGenerator.new()
	r2.seed = 7
	for y in 32:
		for x in 32:
			var g: float = 0.2 + r2.randf() * 0.06
			a.set_pixel(x, y, Color(g, g, g * 1.05))
	asphalt_tex = ImageTexture.create_from_image(a)


func mat(c: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if mats.has(key):
		return mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	mats[key] = m
	return m


## Khối hộp trang trí (không va chạm)
func deco(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Khối hộp có va chạm
func solid(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	b.position = pos
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	b.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	parent.add_child(b)
	return b


func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Thanh nối hai điểm (dây điện)
func beam(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = a.distance_to(b)
	cm.radial_segments = 4
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	parent.add_child(mi)
	mi.global_position = (a + b) / 2.0
	var dir: Vector3 = (b - a).normalized()
	var up: Vector3 = Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD
	mi.global_transform.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0)


func text3d(parent: Node3D, txt: String, pos: Vector3, size: float, col: Color, outline: Color = Color(0, 0, 0, 0.6)) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = txt
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = col
	l.outline_modulate = outline
	l.outline_size = 8
	l.position = pos
	l.double_sided = false
	parent.add_child(l)
	return l


# ====================================================================== nền phố

const SIDEWALK_ALBEDO: String = "res://textures/via_he/via_he_albedo.jpg"
const SIDEWALK_NORMAL: String = "res://textures/via_he/via_he_normal.png"
const SIDEWALK_ROUGH: String = "res://textures/via_he/via_he_rough.png"
const SIDEWALK_HEIGHT: String = "res://textures/via_he/via_he_height.png"
const SIDEWALK_REPEAT_M: float = 2.4  # 8 viên x 30 cm
const SIDEWALK_PARALLAX: float = 1.2  # độ sâu parallax (càng lớn kẽ/ô vuông càng lõm)


func build_ground(size: Vector3, roads: Array, holes: Array = []) -> void:
	var tile: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists(SIDEWALK_ALBEDO):
		# gạch bát giác + ô vuông kiểu vỉa hè Hà Nội (textures/via_he, tạo bằng tools/tao_gach_via_he.py)
		tile.albedo_texture = load(SIDEWALK_ALBEDO)
		tile.albedo_color = Color(0.84, 0.84, 0.84)  # giảm chói dưới nắng
		if ResourceLoader.exists(SIDEWALK_NORMAL):
			tile.normal_enabled = true
			tile.normal_texture = load(SIDEWALK_NORMAL)
			tile.normal_scale = 1.4
		if ResourceLoader.exists(SIDEWALK_ROUGH):
			tile.roughness_texture = load(SIDEWALK_ROUGH)
			tile.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		tile.roughness = 1.0
		tile.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		# bản cho gạch 3D quanh hố: chiếu texture theo toạ độ thế giới (khớp với lưới UV của mặt vỉa hè)
		var tri: StandardMaterial3D = tile.duplicate()
		tri.uv1_triplanar = true
		tri.uv1_world_triplanar = true
		tri.uv1_scale = Vector3.ONE / SIDEWALK_REPEAT_M
		sidewalk_mat = tri
		# độ cao: bát giác nhô hơn ô vuông, kẽ cát lõm (parallax)
		if ResourceLoader.exists(SIDEWALK_HEIGHT):
			tile.heightmap_enabled = true
			tile.heightmap_texture = load(SIDEWALK_HEIGHT)
			tile.heightmap_scale = SIDEWALK_PARALLAX
			tile.heightmap_deep_parallax = true
			tile.heightmap_min_layers = 8
			tile.heightmap_max_layers = 24
	else:
		tile.albedo_texture = tile_tex
		tile.uv1_triplanar = true
		tile.uv1_world_triplanar = true
		tile.uv1_scale = Vector3.ONE / 1.2
		tile.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		tile.roughness = 0.95
	# va chạm mặt đất (phẳng ở y = 0, kể cả chỗ hố bong gạch)
	var gb: StaticBody3D = StaticBody3D.new()
	gb.position = Vector3(0, -0.5, 0)
	var gcs: CollisionShape3D = CollisionShape3D.new()
	var gsh: BoxShape3D = BoxShape3D.new()
	gsh.size = Vector3(size.x, 1.0, size.z)
	gcs.shape = gsh
	gb.add_child(gcs)
	add_child(gb)
	# lớp cát nền bên dưới gạch (lộ ra ở chỗ gạch bong)
	deco(self, Vector3(size.x, 0.9, size.z), Vector3(0, -TILE_T - 0.45, 0), _sand_mat())
	# lớp gạch dày 6 cm, chừa các ô hố
	if sidewalk_mat == null:
		sidewalk_mat = tile
	_build_slabs(size, holes, tile)
	# mặt đường nhựa + mép vỉa hè
	var asph: StandardMaterial3D = StandardMaterial3D.new()
	asph.albedo_texture = asphalt_tex
	asph.roughness = 1.0
	var curb: StandardMaterial3D = mat(Color(0.62, 0.6, 0.58))
	for r in roads:
		var c: Vector3 = r["center"]
		var sz: Vector3 = r["size"]
		var m2: StandardMaterial3D = asph.duplicate()
		m2.uv1_scale = Vector3(sz.x / 2.0, sz.z / 2.0, 1)
		deco(self, Vector3(sz.x, 0.04, sz.z), c + Vector3(0, 0.02, 0), m2)
		# mép vỉa hè hai bên (chỉ để nhìn)
		if sz.x > sz.z:
			for s in [-1.0, 1.0]:
				deco(self, Vector3(sz.x, 0.08, 0.18), c + Vector3(0, 0.04, s * (sz.z / 2.0 + 0.09)), curb)
		else:
			for s in [-1.0, 1.0]:
				deco(self, Vector3(0.18, 0.08, sz.z), c + Vector3(s * (sz.x / 2.0 + 0.09), 0.04, 0), curb)


# ====================================================================== dãy nhà ống

## Dựng một dãy nhà ống lấp đầy ô (center, frontage dài L, sâu D), mặt tiền quay theo yaw.
## spec: {"kind", "sign", "floors"}. Trả về thông tin cửa của căn chính (nếu có).
func build_block(center: Vector3, L: float, D: float, yaw: float, spec: Dictionary) -> Dictionary:
	var root: Node3D = Node3D.new()
	root.position = center
	root.rotation = Vector3(0, yaw, 0)
	add_child(root)
	var n: int = maxi(1, int(round(L / 4.6)))
	var widths: Array = []
	var total: float = 0.0
	for i in n:
		var wv: float = rng.randf_range(0.85, 1.15)
		widths.append(wv)
		total += wv
	for i in n:
		widths[i] = float(widths[i]) / total * L
	var kind: String = str(spec.get("kind", ""))
	var main_i: int = n / 2
	var x: float = -L / 2.0
	var result: Dictionary = {}
	for i in n:
		var hw: float = widths[i]
		var cx: float = x + hw / 2.0
		x += hw
		var is_main: bool = kind != "" and i == main_i
		var floors: int = rng.randi_range(2, 4)
		if is_main and spec.has("floors"):
			floors = int(spec["floors"])
		var opts: Dictionary = {}
		if is_main:
			opts = spec.duplicate()
		else:
			var r: float = rng.randf()
			if r < 0.35:
				opts = {"front": "shop", "sign": str(SHOP_SIGNS[rng.randi_range(0, SHOP_SIGNS.size() - 1)])}
			elif r < 0.75:
				opts = {"front": "shutter"}
			else:
				opts = {"front": "gate"}
		var info: Dictionary = _tube_house(root, cx, hw, D, floors, opts)
		if is_main:
			result = info
		elif rng.randf() < 0.55:
			bike_spots.append({"pos": root.to_global(Vector3(cx + rng.randf_range(-0.8, 0.8), 0, D / 2.0 + 1.3)), "yaw": yaw_of(root) + rng.randf_range(-0.25, 0.25)})
	return result


func yaw_of(n: Node3D) -> float:
	return n.rotation.y


func _tube_house(root: Node3D, cx: float, hw: float, D: float, floors: int, o: Dictionary) -> Dictionary:
	var H: float = float(floors) * FLOOR_H
	var front: float = D / 2.0
	var wall: Color = WALL_COLORS[rng.randi_range(0, WALL_COLORS.size() - 1)]
	var wall_m: StandardMaterial3D = mat(wall)
	var trim_m: StandardMaterial3D = mat(wall.darkened(0.25))
	# thân nhà (có va chạm)
	solid(root, Vector3(hw - 0.04, H, D), Vector3(cx, H / 2.0, 0), wall_m)
	# gờ chia tầng
	for f in range(1, floors):
		deco(root, Vector3(hw - 0.04, 0.12, 0.1), Vector3(cx, float(f) * FLOOR_H, front + 0.05), trim_m)
	var kind: String = str(o.get("kind", ""))
	var fr: String = str(o.get("front", "shop" if kind in ["food", "jewelry_shop", "shop", "casino"] else "gate"))
	var info: Dictionary = {}
	# ---- tầng trệt
	var open_w: float = hw - 0.7
	match fr:
		"shop":
			deco(root, Vector3(open_w, 2.6, 0.06), Vector3(cx, 1.3, front + 0.02), mat(Color(0.12, 0.1, 0.09)))
			# ánh đèn bên trong quán
			var glow: StandardMaterial3D = StandardMaterial3D.new()
			glow.albedo_color = Color(1.0, 0.92, 0.75)
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.85, 0.6)
			glow.emission_energy_multiplier = 0.6
			deco(root, Vector3(open_w * 0.8, 0.08, 0.05), Vector3(cx, 2.45, front + 0.05), glow)
			# hộp cửa cuốn kéo lên
			deco(root, Vector3(open_w + 0.1, 0.3, 0.3), Vector3(cx, 2.75, front + 0.12), mat(Color(0.55, 0.55, 0.57), 0.6, 0.4))
			# kệ hàng / tủ kính bên trong
			deco(root, Vector3(open_w * 0.7, 0.9, 0.4), Vector3(cx, 0.45, front - 0.3), mat(Color(0.6, 0.5, 0.35)))
		"shutter":
			var sm: StandardMaterial3D = StandardMaterial3D.new()
			sm.albedo_texture = shutter_tex
			sm.uv1_scale = Vector3(1, 10, 1)
			sm.metallic = 0.3
			sm.roughness = 0.6
			deco(root, Vector3(open_w, 2.6, 0.06), Vector3(cx, 1.3, front + 0.03), sm)
			deco(root, Vector3(open_w + 0.1, 0.3, 0.3), Vector3(cx, 2.75, front + 0.12), mat(Color(0.55, 0.55, 0.57), 0.6, 0.4))
		_:
			# cửa sắt / cửa gỗ nhà ở
			deco(root, Vector3(open_w * 0.6, 2.4, 0.08), Vector3(cx, 1.2, front + 0.04), mat(Color(0.2, 0.32, 0.28), 0.5, 0.3))
			for k in 5:
				deco(root, Vector3(0.03, 2.3, 0.1), Vector3(cx - open_w * 0.3 + float(k) * open_w * 0.15, 1.2, front + 0.09), mat(Color(0.15, 0.2, 0.18), 0.5, 0.4))
	# ---- biển hiệu
	var sign: String = str(o.get("sign", ""))
	if sign != "":
		var bg: Color = o.get("sign_bg", Color.from_hsv(rng.randf(), 0.75, 0.75))
		var fg: Color = o.get("sign_fg", Color(1, 1, 0.85))
		var sm2: StandardMaterial3D = StandardMaterial3D.new()
		sm2.albedo_color = bg
		sm2.emission_enabled = true
		sm2.emission = bg
		sm2.emission_energy_multiplier = 0.0
		sign_mats.append(sm2)
		deco(root, Vector3(hw - 0.2, 1.1, 0.14), Vector3(cx, 3.6, front + 0.12), sm2)
		var fs: float = clampf((hw - 0.7) / (maxf(float(sign.length()), 4.0) * 0.6), 0.18, 0.55)
		text3d(root, sign, Vector3(cx, 3.72 if o.has("sub") else 3.6, front + 0.2), fs, fg)
		if o.has("sub"):
			var fs2: float = clampf((hw - 0.7) / (maxf(float(str(o["sub"]).length()), 4.0) * 0.6), 0.1, 0.2)
			text3d(root, str(o["sub"]), Vector3(cx, 3.3, front + 0.2), fs2, fg)
	# ---- các tầng trên: ban công, cửa sổ, cục nóng, cây
	for f in range(1, floors):
		var y: float = float(f) * FLOOR_H
		if f == 1 and sign != "":
			# tầng 1 bị biển hiệu che phần dưới: chỉ có cửa sổ phía trên biển
			var gm1: StandardMaterial3D = StandardMaterial3D.new()
			gm1.albedo_color = Color(0.25, 0.32, 0.38)
			gm1.roughness = 0.15
			gm1.emission_enabled = true
			gm1.emission = Color(1.0, 0.82, 0.55)
			gm1.emission_energy_multiplier = 0.0
			window_mats.append(gm1)
			deco(root, Vector3((hw - 0.4) * 0.6, 1.0, 0.05), Vector3(cx, y + 2.0, front + 0.03), gm1)
			continue
		deco(root, Vector3(hw - 0.3, 0.15, 0.9), Vector3(cx, y + 0.07, front + 0.45), trim_m)
		if rng.randf() < 0.5:
			deco(root, Vector3(hw - 0.3, 0.9, 0.08), Vector3(cx, y + 0.6, front + 0.86), wall_m)  # lan can xây
		else:
			var rail: StandardMaterial3D = mat(Color(0.18, 0.18, 0.2), 0.5, 0.6)
			deco(root, Vector3(hw - 0.3, 0.05, 0.05), Vector3(cx, y + 1.05, front + 0.86), rail)
			for k in int((hw - 0.4) / 0.35):
				deco(root, Vector3(0.03, 0.95, 0.03), Vector3(cx - (hw - 0.4) / 2.0 + 0.15 + float(k) * 0.35, y + 0.55, front + 0.86), rail)
		# cửa kính / cửa sổ
		var gm: StandardMaterial3D = StandardMaterial3D.new()
		gm.albedo_color = Color(0.25, 0.32, 0.38)
		gm.roughness = 0.2
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.82, 0.55)
		gm.emission_energy_multiplier = 0.0
		if rng.randf() < 0.6:
			window_mats.append(gm)
		var ww: float = (hw - 0.4) * rng.randf_range(0.5, 0.7)
		deco(root, Vector3(ww, 2.2, 0.05), Vector3(cx, y + 1.25, front + 0.03), gm)
		deco(root, Vector3(ww + 0.12, 0.08, 0.08), Vector3(cx, y + 2.38, front + 0.05), trim_m)
		if rng.randf() < 0.55:
			var ax: float = cx + (hw / 2.0 - 0.6) * (1.0 if rng.randf() < 0.5 else -1.0)
			deco(root, Vector3(0.75, 0.5, 0.28), Vector3(ax, y + 2.55, front + 0.16), mat(Color(0.93, 0.93, 0.9), 0.6))
			cyl(root, 0.17, 0.17, 0.05, Vector3(ax, y + 2.55, front + 0.31), mat(Color(0.3, 0.3, 0.3)), Vector3(PI / 2.0, 0, 0))
		for k in rng.randi_range(0, 2):
			var px: float = cx + rng.randf_range(-hw / 2.0 + 0.5, hw / 2.0 - 0.5)
			cyl(root, 0.16, 0.12, 0.25, Vector3(px, y + 0.27, front + 0.6), mat(Color(0.55, 0.3, 0.2)))
			var leaf: MeshInstance3D = MeshInstance3D.new()
			var sp: SphereMesh = SphereMesh.new()
			sp.radius = 0.25
			sp.height = 0.45
			leaf.mesh = sp
			leaf.material_override = mat(Color(0.25, 0.55, 0.25))
			leaf.position = Vector3(px, y + 0.6, front + 0.6)
			root.add_child(leaf)
	# ---- mái
	deco(root, Vector3(hw - 0.04, 0.9, 0.12), Vector3(cx, H + 0.45, front - 0.06), wall_m)
	var roof_r: float = rng.randf()
	if roof_r < 0.45:
		var tin: StandardMaterial3D = mat(Color.from_hsv(rng.randf_range(0.0, 0.6), 0.45, 0.55), 0.5, 0.5)
		var tm: MeshInstance3D = deco(root, Vector3(hw - 0.2, 0.06, D * 0.55), Vector3(cx, H + 1.0, -D * 0.12), tin)
		tm.rotation = Vector3(deg_to_rad(9.0), 0, 0)
		for k in 2:
			deco(root, Vector3(0.08, 1.2, 0.08), Vector3(cx - hw / 2.0 + 0.3 + float(k) * (hw - 0.6), H + 0.6, -D * 0.12 + D * 0.25), mat(Color(0.3, 0.3, 0.3)))
	if rng.randf() < 0.75:
		var inox: StandardMaterial3D = mat(Color(0.82, 0.83, 0.86), 0.25, 0.9)
		var tx: float = cx + rng.randf_range(-hw / 4.0, hw / 4.0)
		cyl(root, 0.45, 0.45, 1.3, Vector3(tx, H + 1.2, -D / 2.0 + 1.2), inox, Vector3(0, 0, PI / 2.0))
		deco(root, Vector3(1.1, 0.5, 0.6), Vector3(tx, H + 0.25, -D / 2.0 + 1.2), mat(Color(0.4, 0.4, 0.42)))
	# ---- số nhà
	var num_m: StandardMaterial3D = mat(Color(0.15, 0.35, 0.7))
	var nx: float = cx + hw / 2.0 - 0.35
	deco(root, Vector3(0.32, 0.22, 0.03), Vector3(nx, 2.3, front + 0.02), num_m)
	text3d(root, str(rng.randi_range(2, 98)), Vector3(nx, 2.3, front + 0.04), 0.12, Color(1, 1, 1), Color(0, 0, 0, 0))
	# ---- vị trí cửa (cho tương tác)
	info["door_local"] = Vector3(cx, 1.2, front + 0.15)
	info["root"] = root
	info["width"] = open_w
	return info


# ====================================================================== đồ vật đường phố

func build_motorbike(pos: Vector3, yaw: float) -> void:
	var r: Node3D = Node3D.new()
	r.position = pos
	r.rotation = Vector3(0, yaw, 0)
	add_child(r)
	var body: Color = [Color(0.8, 0.1, 0.1), Color(0.1, 0.2, 0.6), Color(0.1, 0.1, 0.1), Color(0.9, 0.9, 0.9), Color(0.2, 0.5, 0.3)][rng.randi_range(0, 4)]
	var tire: StandardMaterial3D = mat(Color(0.08, 0.08, 0.08))
	for z in [-0.6, 0.6]:
		var w: MeshInstance3D = cyl(r, 0.28, 0.28, 0.1, Vector3(0, 0.28, z), tire, Vector3(0, 0, PI / 2.0))
		w.name = "wheel"
	deco(r, Vector3(0.3, 0.35, 1.0), Vector3(0, 0.55, 0.05), mat(body, 0.4, 0.3))
	deco(r, Vector3(0.28, 0.12, 0.55), Vector3(0, 0.8, -0.15), mat(Color(0.12, 0.1, 0.1)))  # yên
	deco(r, Vector3(0.12, 0.7, 0.12), Vector3(0, 0.75, 0.55), mat(body, 0.4, 0.3))
	deco(r, Vector3(0.65, 0.05, 0.05), Vector3(0, 1.1, 0.55), mat(Color(0.2, 0.2, 0.2), 0.4, 0.7))  # ghi đông
	deco(r, Vector3(0.18, 0.15, 0.08), Vector3(0, 0.95, 0.68), mat(Color(1, 1, 0.85)))
	# va chạm nhỏ
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: BoxShape3D = BoxShape3D.new()
	sh.size = Vector3(0.6, 1.0, 1.7)
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	b.add_child(cs)
	r.add_child(b)


const STOOL_MODELS: Array = ["res://models/ban_ghe/ghe_nhua_xanh_reu.glb", "res://models/ban_ghe/ghe_nhua_vang.glb", "res://models/ban_ghe/ghe_nhua_do.glb", "res://models/ban_ghe/ghe_nhua_xanh.glb"]
const TABLE_MODELS: Array = ["res://models/ban_ghe/ban_nhua_xanh_reu.glb", "res://models/ban_ghe/ban_nhua_do.glb"]
var _shape_cache: Dictionary = {}


## Đặt model .glb; collide = true thì thêm khối va chạm bao lồi (convex) đúng theo hình model.
func _place_model(parent: Node3D, path: String, pos: Vector3, yaw: float, collide: bool = true) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var ps: PackedScene = load(path)
	if ps == null:
		return false
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation = Vector3(0, yaw, 0)
	parent.add_child(n)
	if collide:
		add_model_collision(n, path)
	return true


## Thêm StaticBody3D + CollisionShape3D bao lồi cho model (dùng chung shape cho cùng một file).
func add_model_collision(n: Node3D, key: String) -> void:
	var mis: Array = n.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		return
	var mi: MeshInstance3D = mis[0]
	if not _shape_cache.has(key):
		_shape_cache[key] = mi.mesh.create_convex_shape(true, true)
	var body: StaticBody3D = StaticBody3D.new()
	body.set_meta("model", key.get_file().get_basename())
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = _shape_cache[key]
	var t: Transform3D = Transform3D()
	var cur: Node = mi
	while cur != null and cur != n:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	cs.transform = t
	body.add_child(cs)
	n.add_child(body)


func build_stools(center: Vector3, yaw: float) -> void:
	# Bộ bàn ghế nhựa vỉa hè (models/ban_ghe, dựng bằng Blender); thiếu file thì dựng khối đơn giản.
	var r: Node3D = Node3D.new()
	r.position = center
	r.rotation = Vector3(0, yaw, 0)
	add_child(r)
	var cols: Array = [Color(0.85, 0.15, 0.15), Color(0.15, 0.35, 0.8), Color(0.95, 0.75, 0.1)]
	for t in 2:
		var tx: float = -1.2 + float(t) * 2.4
		var tyaw: float = rng.randf_range(-0.12, 0.12)
		if not _place_model(r, TABLE_MODELS[rng.randi_range(0, TABLE_MODELS.size() - 1)], Vector3(tx, 0, 0), tyaw):
			var tc: Color = cols[rng.randi_range(0, 2)]
			solid(r, Vector3(0.7, 0.04, 0.7), Vector3(tx, 0.5, 0), mat(tc, 0.5))
			for lx in [-0.3, 0.3]:
				for lz in [-0.3, 0.3]:
					deco(r, Vector3(0.04, 0.5, 0.04), Vector3(tx + lx, 0.25, lz), mat(tc, 0.5))
		# bàn dài 0,7 m theo trục x: mỗi bên dài 2 ghế, thỉnh thoảng 1 ghế ở đầu bàn
		var seats: Array = [Vector3(-0.2, 0, -0.55), Vector3(0.2, 0, -0.55), Vector3(-0.2, 0, 0.55), Vector3(0.2, 0, 0.55)]
		if rng.randf() < 0.5:
			seats.append(Vector3(0.72 if rng.randf() < 0.5 else -0.72, 0, 0))
		for sp0 in seats:
			if rng.randf() < 0.15:
				continue  # ghế bị kéo đi chỗ khác
			var sp: Vector3 = Vector3(tx, 0, 0) + sp0.rotated(Vector3.UP, tyaw) + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
			if not _place_model(r, STOOL_MODELS[rng.randi_range(0, STOOL_MODELS.size() - 1)], sp, rng.randf_range(-0.35, 0.35)):
				var sc: Color = cols[rng.randi_range(0, 2)]
				solid(r, Vector3(0.32, 0.04, 0.32), sp + Vector3(0, 0.3, 0), mat(sc, 0.5))
				cyl(r, 0.14, 0.17, 0.28, sp + Vector3(0, 0.14, 0), mat(sc, 0.5))


const TREE_MODELS: Array = ["res://models/cay/cay_1.glb", "res://models/cay/cay_2.glb", "res://models/cay/cay_3.glb"]
var _tree_leaf_mat: ShaderMaterial
var _tree_bark_mat: StandardMaterial3D


## Cây xanh đường phố dựng bằng Blender (models/cay): thân thẳng ~3 m, tán vòm lá kép lông chim.
## Thiếu file thì dựng cây khối đơn giản như cũ.
func _place_tree_model(r: Node3D) -> bool:
	var path: String = TREE_MODELS[rng.randi_range(0, TREE_MODELS.size() - 1)]
	if not ResourceLoader.exists(path):
		return false
	if _tree_leaf_mat == null:
		_tree_leaf_mat = ShaderMaterial.new()
		_tree_leaf_mat.shader = load("res://shaders/la_cay.gdshader")
		_tree_leaf_mat.set_shader_parameter("albedo_tex", load("res://textures/cay/la_cay_atlas.png"))
		_tree_bark_mat = StandardMaterial3D.new()
		_tree_bark_mat.albedo_texture = load("res://textures/cay/vo_cay.png")
		_tree_bark_mat.normal_enabled = true
		_tree_bark_mat.normal_texture = load("res://textures/cay/vo_cay_normal.png")
		_tree_bark_mat.roughness = 0.95
		_tree_bark_mat.albedo_color = Color(0.95, 0.92, 0.88)
	var n: Node3D = (load(path) as PackedScene).instantiate()
	n.rotation.y = rng.randf() * TAU
	n.scale = Vector3.ONE * rng.randf_range(0.74, 0.88)  # phố hẹp: tán ~6-7 m để bớt chạm tường nhà
	r.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for i in m.mesh.get_surface_count():
			var sm: Material = m.mesh.surface_get_material(i)
			var nm: String = sm.resource_name.to_lower() if sm != null else ""
			if nm.begins_with("la"):
				m.set_surface_override_material(i, _tree_leaf_mat)
			else:
				m.set_surface_override_material(i, _tree_bark_mat)
	return true


func build_tree(pos: Vector3) -> void:
	var r: Node3D = Node3D.new()
	r.position = pos
	add_child(r)
	cyl(r, 0.42, 0.42, 0.08, Vector3(0, 0.04, 0), mat(Color(0.55, 0.55, 0.52)))  # bồn gốc cây
	if not _place_tree_model(r):
		var h: float = rng.randf_range(3.5, 5.5)
		cyl(r, 0.12, 0.18, h, Vector3(0, h / 2.0, 0), mat(Color(0.4, 0.3, 0.2)))
		for k in 3:
			var leaf: MeshInstance3D = MeshInstance3D.new()
			var sp: SphereMesh = SphereMesh.new()
			var rad: float = rng.randf_range(1.0, 1.5)
			sp.radius = rad
			sp.height = rad * 1.6
			sp.radial_segments = 10
			sp.rings = 6
			leaf.mesh = sp
			leaf.material_override = mat(Color(0.2 + rng.randf() * 0.1, 0.45 + rng.randf() * 0.15, 0.2))
			leaf.position = Vector3(rng.randf_range(-0.6, 0.6), h + rng.randf_range(-0.3, 0.5), rng.randf_range(-0.6, 0.6))
			r.add_child(leaf)
	var b: StaticBody3D = StaticBody3D.new()
	var cs: CollisionShape3D = CollisionShape3D.new()
	var sh: CylinderShape3D = CylinderShape3D.new()
	sh.radius = 0.24
	sh.height = 3.0
	cs.shape = sh
	cs.position = Vector3(0, 1.5, 0)
	b.add_child(cs)
	r.add_child(b)


## Hàng cột điện bê tông dọc một đoạn đường, dây điện chằng giữa các cột, đèn đường trên cột
func build_pole_line(a: Vector3, b: Vector3, spacing: float, lamp_side: Vector3) -> void:
	var dist: float = a.distance_to(b)
	var n: int = maxi(2, int(dist / spacing) + 1)
	var concrete: StandardMaterial3D = mat(Color(0.62, 0.62, 0.6))
	var wire: StandardMaterial3D = mat(Color(0.05, 0.05, 0.05), 0.8)
	var tops: Array = []
	for i in n:
		var p: Vector3 = a.lerp(b, float(i) / float(n - 1))
		cyl(self, 0.1, 0.16, 7.5, p + Vector3(0, 3.75, 0), concrete)
		var dir: Vector3 = (b - a).normalized()
		var across: Vector3 = Vector3(-dir.z, 0, dir.x)
		var arm: MeshInstance3D = deco(self, Vector3(0.08, 0.08, 1.4), p + Vector3(0, 7.0, 0), mat(Color(0.3, 0.3, 0.3), 0.5, 0.5))
		arm.rotation.y = atan2(across.x, across.z)
		if i % 3 == 1:
			cyl(self, 0.35, 0.35, 0.8, p + Vector3(0, 5.6, 0) + across * 0.3, mat(Color(0.45, 0.47, 0.45), 0.5, 0.5))  # biến áp
		# bó dây quấn quanh cột
		for k in 3:
			cyl(self, 0.2, 0.2, 0.12, p + Vector3(0, 6.2 + float(k) * 0.15, 0), wire)
		tops.append(p)
		# đèn đường
		if i % 2 == 0:
			var arm2: Vector3 = p + Vector3(0, 6.0, 0) + lamp_side * 1.2
			beam(self, p + Vector3(0, 6.0, 0), arm2, 0.04, mat(Color(0.3, 0.3, 0.3), 0.5, 0.5))
			var bulb: StandardMaterial3D = StandardMaterial3D.new()
			bulb.albedo_color = Color(1, 0.95, 0.8)
			bulb.emission_enabled = true
			bulb.emission = Color(1, 0.85, 0.55)
			bulb.emission_energy_multiplier = 0.0
			sign_mats.append(bulb)
			deco(self, Vector3(0.35, 0.1, 0.2), arm2 + Vector3(0, -0.05, 0), bulb)
			var l: OmniLight3D = OmniLight3D.new()
			l.position = arm2 + Vector3(0, -0.3, 0)
			l.omni_range = 16.0
			l.omni_attenuation = 0.8
			l.light_energy = 0.0
			l.light_color = Color(1.0, 0.82, 0.55)
			add_child(l)
			lamps.append(l)
	# dây điện võng giữa các cột (nhiều sợi, độ cao khác nhau)
	for i in range(n - 1):
		var p0: Vector3 = tops[i]
		var p1: Vector3 = tops[i + 1]
		for k in 4:
			var h: float = 6.3 + float(k) * 0.22
			var off: Vector3 = Vector3(0, 0, 0)
			var mid: Vector3 = (p0 + p1) / 2.0 + Vector3(0, h - 0.5 - float(k) * 0.1, 0) + off
			beam(self, p0 + Vector3(0, h, 0), mid, 0.015, wire)
			beam(self, mid, p1 + Vector3(0, h, 0), 0.015, wire)


## Ban đêm: bật đèn cửa sổ, biển hiệu, đèn đường. t = 0 (ngày) .. 1 (đêm)
func set_night(t: float) -> void:
	for i in window_mats.size():
		(window_mats[i] as StandardMaterial3D).emission_energy_multiplier = t * (1.2 + 1.2 * float(i % 3) / 2.0)
	for m in sign_mats:
		(m as StandardMaterial3D).emission_energy_multiplier = t * 1.5
	for l in lamps:
		(l as OmniLight3D).light_energy = t * 4.0


# ====================================================================== người

const SKINS: Array = [Color(0.93, 0.76, 0.6), Color(0.85, 0.66, 0.5), Color(0.76, 0.57, 0.42), Color(0.95, 0.8, 0.66)]
const HAIRS: Array = [Color(0.06, 0.05, 0.05), Color(0.12, 0.08, 0.06), Color(0.2, 0.15, 0.1)]
const PANTS: Array = [Color(0.15, 0.17, 0.25), Color(0.25, 0.22, 0.2), Color(0.1, 0.1, 0.12), Color(0.35, 0.33, 0.3), Color(0.3, 0.4, 0.55)]


## Dựng một người low-poly, gốc ở chân. Trả về các khớp để làm chuyển động đi bộ.
## o: shirt, pants, skin, hair, female (tóc dài), hat (nón lá), rng
func humanoid(parent: Node3D, o: Dictionary = {}) -> Dictionary:
	var r: RandomNumberGenerator = o.get("rng", rng)
	var root: Node3D = Node3D.new()
	root.name = "Body"
	parent.add_child(root)
	var skin: Color = o.get("skin", SKINS[r.randi_range(0, SKINS.size() - 1)])
	var shirt: Color = o.get("shirt", Color.from_hsv(r.randf(), r.randf_range(0.25, 0.7), r.randf_range(0.45, 0.92)))
	var pants: Color = o.get("pants", PANTS[r.randi_range(0, PANTS.size() - 1)])
	var hair: Color = o.get("hair", HAIRS[r.randi_range(0, HAIRS.size() - 1)])
	var female: bool = bool(o.get("female", r.randf() < 0.5))
	var sk: StandardMaterial3D = mat(skin, 0.8)
	var sh: StandardMaterial3D = mat(shirt, 0.85)
	var pm: StandardMaterial3D = mat(pants, 0.9)
	var hm: StandardMaterial3D = mat(hair, 0.7)
	var shoe: StandardMaterial3D = mat(Color(0.1, 0.1, 0.1))
	var legs: Array = []
	for sx in [-0.1, 0.1]:
		var hip: Node3D = Node3D.new()
		hip.position = Vector3(sx, 0.86, 0)
		root.add_child(hip)
		deco(hip, Vector3(0.15, 0.82, 0.17), Vector3(0, -0.41, 0), pm)
		deco(hip, Vector3(0.15, 0.08, 0.26), Vector3(0, -0.82, -0.04), shoe)
		legs.append(hip)
	deco(root, Vector3(0.42, 0.62, 0.24), Vector3(0, 1.17, 0), sh)
	var arms: Array = []
	for sx in [-0.27, 0.27]:
		var sho: Node3D = Node3D.new()
		sho.position = Vector3(sx, 1.44, 0)
		root.add_child(sho)
		deco(sho, Vector3(0.12, 0.34, 0.13), Vector3(0, -0.15, 0), sh)
		deco(sho, Vector3(0.1, 0.3, 0.11), Vector3(0, -0.45, 0), sk)
		arms.append(sho)
	deco(root, Vector3(0.12, 0.08, 0.12), Vector3(0, 1.51, 0), sk)
	var head: Node3D = Node3D.new()
	head.position = Vector3(0, 1.66, 0)
	root.add_child(head)
	deco(head, Vector3(0.24, 0.26, 0.24), Vector3.ZERO, sk)
	deco(head, Vector3(0.26, 0.09, 0.26), Vector3(0, 0.12, 0.0), hm)
	deco(head, Vector3(0.26, 0.16, 0.06), Vector3(0, 0.04, 0.11), hm)
	if female:
		deco(head, Vector3(0.26, 0.4, 0.08), Vector3(0, -0.1, 0.12), hm)
	# mắt
	for ex in [-0.055, 0.055]:
		deco(head, Vector3(0.035, 0.035, 0.01), Vector3(ex, 0.01, -0.121), mat(Color(0.05, 0.05, 0.05)))
	if bool(o.get("hat", false)):
		var cone: MeshInstance3D = cyl(head, 0.0, 0.32, 0.2, Vector3(0, 0.23, 0), mat(Color(0.88, 0.8, 0.55)))
		cone.name = "NonLa"
	return {"root": root, "legs": legs, "arms": arms}


## Cử động đi bộ: phase tăng theo thời gian; moving = false thì đứng yên
func animate_walk(parts: Dictionary, phase: float, moving: bool) -> void:
	var a: float = sin(phase) * 0.55 if moving else 0.0
	var legs: Array = parts.get("legs", [])
	var arms: Array = parts.get("arms", [])
	if legs.size() == 2:
		(legs[0] as Node3D).rotation.x = a
		(legs[1] as Node3D).rotation.x = -a
	if arms.size() == 2:
		(arms[0] as Node3D).rotation.x = -a * 0.8
		(arms[1] as Node3D).rotation.x = a * 0.8


# ====================================================================== gạch vỉa hè 3D, hố bong gạch, lá rụng

const TILE_P: float = 0.3      # chu kỳ viên gạch (khớp texture: 8 viên / 2,4 m)
const TILE_T: float = 0.06     # độ dày viên gạch
const TILE_OCT_MODEL: String = "res://models/via_he/gach_bat_giac.glb"
const TILE_SQ_MODEL: String = "res://models/via_he/gach_vuong.glb"
const LEAF_MODEL: String = "res://models/via_he/la_rung.glb"
var dmg_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _sand: StandardMaterial3D
var sidewalk_mat: Material  # vật liệu mặt gạch (texture theo toạ độ thế giới) - gạch 3D tại chỗ dùng chung để liền mạch


func _sand_mat() -> StandardMaterial3D:
	if _sand != null:
		return _sand
	var img: Image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 515
	for y in 64:
		for x in 64:
			var v: float = r.randf_range(-0.07, 0.07)
			if r.randf() < 0.04:
				v -= 0.18  # sỏi sẫm
			img.set_pixel(x, y, Color(0.56 + v, 0.5 + v, 0.41 + v))
	_sand = StandardMaterial3D.new()
	_sand.albedo_texture = ImageTexture.create_from_image(img)
	_sand.uv1_triplanar = true
	_sand.uv1_world_triplanar = true
	_sand.uv1_scale = Vector3.ONE / 0.35
	_sand.roughness = 1.0
	return _sand


## Lát mặt gạch thành các tấm chữ nhật, chừa ra hình chữ nhật của từng hố.
func _build_slabs(size: Vector3, holes: Array, tile: Material) -> void:
	var x0: float = -size.x / 2.0
	var x1: float = size.x / 2.0
	var z0: float = -size.z / 2.0
	var z1: float = size.z / 2.0
	var xs: Array = [x0, x1]
	for h in holes:
		var hr: Rect2 = h["rect"]
		xs.append(hr.position.x)
		xs.append(hr.end.x)
	xs.sort()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in xs.size() - 1:
		var xa: float = xs[i]
		var xb: float = xs[i + 1]
		if xb - xa < 0.001:
			continue
		var cuts: Array = []
		for h in holes:
			var hr2: Rect2 = h["rect"]
			if hr2.position.x < xb - 0.0001 and hr2.end.x > xa + 0.0001:
				cuts.append(Vector2(hr2.position.y, hr2.end.y))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var cur: float = z0
		for c in cuts:
			if c.x > cur + 0.0001:
				_slab(st, xa, xb, cur, c.x)
			cur = maxf(cur, c.y)
		if z1 > cur + 0.0001:
			_slab(st, xa, xb, cur, z1)
	st.generate_tangents()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = tile
	add_child(mi)


## Một tấm gạch chữ nhật: mặt trên (UV theo toạ độ thế giới để khớp texture) + 4 mặt bên dày 6 cm.
func _slab(st: SurfaceTool, xa: float, xb: float, za: float, zb: float) -> void:
	var k: float = 1.0 / SIDEWALK_REPEAT_M
	var y0: float = -TILE_T
	_quad(st, [Vector3(xa, 0, za), Vector3(xb, 0, za), Vector3(xb, 0, zb), Vector3(xa, 0, zb)], Vector3.UP, k)
	_quad(st, [Vector3(xa, 0, zb), Vector3(xb, 0, zb), Vector3(xb, y0, zb), Vector3(xa, y0, zb)], Vector3.BACK, k)
	_quad(st, [Vector3(xb, 0, za), Vector3(xa, 0, za), Vector3(xa, y0, za), Vector3(xb, y0, za)], Vector3.FORWARD, k)
	_quad(st, [Vector3(xb, 0, zb), Vector3(xb, 0, za), Vector3(xb, y0, za), Vector3(xb, y0, zb)], Vector3.RIGHT, k)
	_quad(st, [Vector3(xa, 0, za), Vector3(xa, 0, zb), Vector3(xa, y0, zb), Vector3(xa, y0, za)], Vector3.LEFT, k)


func _quad(st: SurfaceTool, v: Array, n: Vector3, k: float) -> void:
	# thứ tự đỉnh theo chiều kim đồng hồ khi nhìn từ phía pháp tuyến (mặt trước của Godot)
	for idx in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = v[idx]
		st.set_normal(n)
		if n == Vector3.UP:
			st.set_uv(Vector2(p.x, p.z) * k)
		elif absf(n.x) > 0.5:
			st.set_uv(Vector2(p.z, -p.y) * k)
		else:
			st.set_uv(Vector2(p.x, -p.y) * k)
		st.add_vertex(p)


## Chọn chỗ vỉa hè bị bong gạch. walks: các Rect2 (x, z) của vỉa hè; avoid: các điểm cần tránh.
func plan_holes(walks: Array, avoid: Array, count: int) -> Array:
	dmg_rng.seed = 6060
	var out: Array = []
	var tries: int = 0
	while out.size() < count and tries < 600:
		tries += 1
		var r: Rect2 = walks[dmg_rng.randi_range(0, walks.size() - 1)]
		var cw: int = dmg_rng.randi_range(4, 6)
		var cd: int = dmg_rng.randi_range(3, 5)
		var w: float = float(cw) * TILE_P
		var d: float = float(cd) * TILE_P
		if r.size.x < w + 1.2 or r.size.y < d + 1.2:
			continue
		var x: float = ceilf(dmg_rng.randf_range(r.position.x + 0.5, r.end.x - 0.5 - w) / TILE_P) * TILE_P
		var z: float = ceilf(dmg_rng.randf_range(r.position.y + 0.5, r.end.y - 0.5 - d) / TILE_P) * TILE_P
		var rect: Rect2 = Rect2(x, z, w, d)
		if not r.encloses(rect):
			continue
		var bad: bool = false
		for o in out:
			if (o["rect"] as Rect2).grow(1.5).intersects(rect):
				bad = true
		for a in avoid:
			if rect.grow(1.4).has_point(Vector2(a.x, a.z)):
				bad = true
		if bad:
			continue
		var missing: Dictionary = {}
		missing[Vector2i(dmg_rng.randi_range(1, cw - 2), dmg_rng.randi_range(1, cd - 2))] = true
		var want: int = dmg_rng.randi_range(2, mini(7, (cw - 2) * (cd - 2)))
		var guard: int = 0
		var dirs: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		while missing.size() < want and guard < 60:
			guard += 1
			var keys: Array = missing.keys()
			var k: Vector2i = keys[dmg_rng.randi_range(0, keys.size() - 1)]
			var nb: Vector2i = k + (dirs[dmg_rng.randi_range(0, 3)] as Vector2i)
			if nb.x >= 1 and nb.x <= cw - 2 and nb.y >= 1 and nb.y <= cd - 2:
				missing[nb] = true
		out.append({"rect": rect, "cw": cw, "cd": cd, "missing": missing})
	return out


func _put(parent: Node3D, ps: PackedScene, pos: Vector3, rot: Vector3, top: Material = null, collide: bool = false) -> void:
	var n: Node3D = ps.instantiate()
	n.position = pos
	n.rotation = rot
	parent.add_child(n)
	if collide:
		add_model_collision(n, ps.resource_path)
	if top != null:
		for c in n.find_children("*", "MeshInstance3D", true, false):
			(c as MeshInstance3D).set_surface_override_material(0, top)


## Dựng các viên gạch 3D trong vùng hố: gạch còn lại, gạch lỏng quanh hố, đống gạch bị cạy chất bên cạnh.
func build_tile_patches(holes: Array) -> void:
	if holes.is_empty() or not ResourceLoader.exists(TILE_OCT_MODEL) or not ResourceLoader.exists(TILE_SQ_MODEL):
		return
	var oct: PackedScene = load(TILE_OCT_MODEL)
	var sq: PackedScene = load(TILE_SQ_MODEL)
	for h in holes:
		var root: Node3D = Node3D.new()
		add_child(root)
		var R: Rect2 = h["rect"]
		var cw: int = h["cw"]
		var cd: int = h["cd"]
		var missing: Dictionary = h["missing"]
		for i in cw:
			for j in cd:
				var key: Vector2i = Vector2i(i, j)
				if missing.has(key):
					continue
				var near: bool = missing.has(key + Vector2i(1, 0)) or missing.has(key - Vector2i(1, 0)) or missing.has(key + Vector2i(0, 1)) or missing.has(key - Vector2i(0, 1))
				var c: Vector3 = Vector3(R.position.x + (float(i) + 0.5) * TILE_P, 0.002, R.position.y + (float(j) + 0.5) * TILE_P)
				var rot: Vector3 = Vector3.ZERO
				if near:
					# gạch lỏng: lún / kênh nhẹ
					c.y += dmg_rng.randf_range(-0.014, 0.01)
					rot = Vector3(dmg_rng.randf_range(-0.06, 0.06), dmg_rng.randf_range(-0.04, 0.04), dmg_rng.randf_range(-0.06, 0.06))
				_put(root, oct, c, rot, sidewalk_mat)
		var loose_sq: int = 0
		for i in cw + 1:
			for j in cd + 1:
				var adj: int = 0
				for di in [-1, 0]:
					for dj in [-1, 0]:
						if missing.has(Vector2i(i + di, j + dj)):
							adj += 1
				if adj >= 2 or (adj == 1 and dmg_rng.randf() < 0.5):
					loose_sq += 1
					continue
				var c2: Vector3 = Vector3(R.position.x + float(i) * TILE_P, 0.002, R.position.y + float(j) * TILE_P)
				var rot2: Vector3 = Vector3.ZERO
				if adj == 1:
					c2.y += dmg_rng.randf_range(-0.01, 0.008)
					rot2 = Vector3(dmg_rng.randf_range(-0.08, 0.08), 0, dmg_rng.randf_range(-0.08, 0.08))
				_put(root, sq, c2, rot2, sidewalk_mat)
		# đống gạch bị cạy lên, chất cạnh hố
		var side: int = dmg_rng.randi_range(0, 3)
		var pc: Vector3
		match side:
			0: pc = Vector3(R.position.x - 0.45, 0, R.get_center().y)
			1: pc = Vector3(R.end.x + 0.45, 0, R.get_center().y)
			2: pc = Vector3(R.get_center().x, 0, R.position.y - 0.45)
			_: pc = Vector3(R.get_center().x, 0, R.end.y + 0.45)
		var n_oct: int = missing.size()
		for k in n_oct:
			var layer: int = k / 3
			var jit: Vector3 = Vector3(dmg_rng.randf_range(-0.16, 0.16), 0, dmg_rng.randf_range(-0.16, 0.16))
			var tilt: Vector3 = Vector3(dmg_rng.randf_range(-0.12, 0.12), dmg_rng.randf() * TAU, dmg_rng.randf_range(-0.12, 0.12))
			if k % 4 == 3:
				tilt.x = dmg_rng.randf_range(0.35, 0.6)  # viên dựng nghiêng
			_put(root, oct, pc + jit + Vector3(0, TILE_T + float(layer) * (TILE_T + 0.004) + absf(tilt.x) * 0.1, 0), tilt, mat(Color(0.47, 0.27, 0.24), 0.9), true)
		for k in loose_sq:
			var jit2: Vector3 = Vector3(dmg_rng.randf_range(-0.3, 0.3), 0, dmg_rng.randf_range(-0.3, 0.3))
			var rot3: Vector3 = Vector3(0, dmg_rng.randf() * TAU, 0)
			if dmg_rng.randf() < 0.3:
				rot3.x = PI / 2.0  # nằm nghiêng lộ thân bê tông
			_put(root, sq, pc + jit2 + Vector3(0, TILE_T, 0), rot3, mat(Color(0.64, 0.57, 0.38), 0.9), true)


## Rải lá vàng rụng trên vỉa hè (MultiMesh, nhiều quanh gốc cây).
func scatter_leaves(walks: Array, trees: Array, holes: Array, density: float = 0.9) -> void:
	if not ResourceLoader.exists(LEAF_MODEL):
		return
	var tmp: Node = (load(LEAF_MODEL) as PackedScene).instantiate()
	var meshes: Array = []
	for c in tmp.find_children("*", "MeshInstance3D", true, false):
		meshes.append((c as MeshInstance3D).mesh)
	tmp.free()
	if meshes.is_empty():
		return
	var weights: Array = [0.42, 0.2, 0.16, 0.22]
	var lr: RandomNumberGenerator = RandomNumberGenerator.new()
	lr.seed = 909
	var per: Array = []
	for m in meshes:
		per.append([])
	var add_leaf: Callable = func(x: float, z: float) -> void:
		for h in holes:
			if (h["rect"] as Rect2).grow(0.05).has_point(Vector2(x, z)):
				return
		var pick: float = lr.randf()
		var idx: int = 0
		var acc: float = 0.0
		for wi in meshes.size():
			acc += weights[wi % weights.size()]
			if pick <= acc:
				idx = wi
				break
		var b: Basis = Basis.from_euler(Vector3(lr.randf_range(-0.18, 0.18), lr.randf() * TAU, lr.randf_range(-0.18, 0.18)))
		b = b.scaled(Vector3.ONE * lr.randf_range(0.9, 1.5))
		per[idx].append(Transform3D(b, Vector3(x, 0.004 + lr.randf() * 0.004, z)))
	for r in walks:
		var rr: Rect2 = r
		var n: int = int(rr.get_area() * density)
		for i in n:
			add_leaf.call(lr.randf_range(rr.position.x, rr.end.x), lr.randf_range(rr.position.y, rr.end.y))
	for t in trees:
		var tp: Vector3 = t
		for i in 160:
			var ang: float = lr.randf() * TAU
			var rad: float = absf(lr.randfn(0.0, 1.6)) + 0.35
			add_leaf.call(tp.x + cos(ang) * rad, tp.z + sin(ang) * rad)
	for i in meshes.size():
		var list: Array = per[i]
		if list.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)


# ====================================================================== đụn lá khô / đụn rác

const DRY_TINTS: Array = [Color(0.62, 0.46, 0.38), Color(0.5, 0.36, 0.3), Color(0.72, 0.6, 0.5), Color(0.44, 0.3, 0.27), Color(0.58, 0.42, 0.37), Color(0.78, 0.68, 0.58)]
const PILE_LEAF_WEIGHTS: Dictionary = {"la_nau": 0.6, "la_cam": 0.22, "la_vang": 0.13, "la_vang_xanh": 0.05}
var _pile_meshes: Array = []
var _pile_mats: Array = []
var _pile_names: Array = []


func _ensure_pile_meshes() -> bool:
	if not _pile_meshes.is_empty():
		return true
	if not ResourceLoader.exists(LEAF_MODEL):
		return false
	var tmp: Node = (load(LEAF_MODEL) as PackedScene).instantiate()
	for c in tmp.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (c as MeshInstance3D).mesh
		var src: Material = mesh.surface_get_material(0)
		var m2: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
		m2.vertex_color_use_as_albedo = true  # nhân màu từng lá (MultiMesh) -> lá khô nhiều sắc nâu
		m2.cull_mode = BaseMaterial3D.CULL_DISABLED
		_pile_meshes.append(mesh)
		_pile_mats.append(m2)
		_pile_names.append(String(c.name).to_lower())
	tmp.free()
	return not _pile_meshes.is_empty()


func _pick_leaf(r: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for n in _pile_names:
		total += float(PILE_LEAF_WEIGHTS.get(_leaf_key(n), 0.1))
	var x: float = r.randf() * total
	for i in _pile_names.size():
		x -= float(PILE_LEAF_WEIGHTS.get(_leaf_key(_pile_names[i]), 0.1))
		if x <= 0.0:
			return i
	return 0


func _leaf_key(n: String) -> String:
	for k in PILE_LEAF_WEIGHTS.keys():
		if n.begins_with(k) and not (k == "la_vang" and n.begins_with("la_vang_xanh")):
			return k
	return n


## Dựng một đụn lá khô (rất nhiều lá gom lại thành ụ) vào node vis. Trả về Vector2(bán kính, chiều cao).
func build_leaf_pile(vis: Node3D, kind: String, r: RandomNumberGenerator) -> Vector2:
	var R: float = r.randf_range(0.38, 0.5)
	var H: float = r.randf_range(0.27, 0.36) * (0.85 if kind == "trash" else 1.0)
	# lõi sẫm màu bên trong để không nhìn xuyên qua kẽ lá
	var core: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = R * 0.7
	sm.height = H * 1.5
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	core.material_override = mat(Color(0.2, 0.13, 0.08), 1.0)
	vis.add_child(core)
	if not _ensure_pile_meshes():
		core.material_override = mat(Color(0.55, 0.36, 0.18), 1.0)
		return Vector2(R, H)
	var per: Array = []
	for i in _pile_meshes.size():
		per.append([])
	var n_main: int = 175 if kind == "leaves" else 110
	for i in n_main:
		var u: float = sqrt(r.randf())
		var th: float = r.randf() * TAU
		var h: float = H * pow(maxf(0.0, 1.0 - u * u), 0.7)
		var p: Vector3 = Vector3(cos(th) * u * R, maxf(0.012, h - r.randf_range(0.0, 0.04)), sin(th) * u * R)
		var nrm: Vector3 = Vector3(cos(th) * u * 1.3, 1.0, sin(th) * u * 1.3).normalized()
		var b: Basis = Basis(Quaternion(Vector3.UP, nrm)) * Basis(Vector3.UP, r.randf() * TAU)
		b = b * Basis(Vector3.RIGHT, r.randf_range(-1.0, 1.0)) * Basis(Vector3.BACK, r.randf_range(-0.7, 0.7))
		b = b.scaled(Vector3.ONE * r.randf_range(1.8, 2.8))
		per[_pick_leaf(r)].append([Transform3D(b, p), DRY_TINTS[r.randi_range(0, DRY_TINTS.size() - 1)]])
	# lá rơi vãi quanh chân đụn
	for i in 30:
		var th2: float = r.randf() * TAU
		var rr: float = R * r.randf_range(0.95, 1.8)
		var b2: Basis = Basis.from_euler(Vector3(r.randf_range(-0.25, 0.25), r.randf() * TAU, r.randf_range(-0.25, 0.25))).scaled(Vector3.ONE * r.randf_range(1.3, 2.0))
		per[_pick_leaf(r)].append([Transform3D(b2, Vector3(cos(th2) * rr, 0.008, sin(th2) * rr)), DRY_TINTS[r.randi_range(0, DRY_TINTS.size() - 1)]])
	for i in _pile_meshes.size():
		var list: Array = per[i]
		if list.is_empty():
			continue
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _pile_meshes[i]
		mm.instance_count = list.size()
		for k in list.size():
			mm.set_instance_transform(k, list[k][0])
			mm.set_instance_color(k, list[k][1])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _pile_mats[i]
		vis.add_child(mmi)
	# vài cành que khô chọc ra
	for i in r.randi_range(2, 4):
		var tw: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.003
		cm.bottom_radius = 0.005
		cm.height = r.randf_range(0.3, 0.55)
		cm.radial_segments = 5
		tw.mesh = cm
		tw.material_override = mat(Color(0.42, 0.36, 0.3), 1.0)
		var th3: float = r.randf() * TAU
		tw.position = Vector3(cos(th3) * R * 0.4, H * 0.45, sin(th3) * R * 0.4)
		tw.rotation = Vector3(r.randf_range(1.0, 1.4), th3, 0)
		vis.add_child(tw)
	return Vector2(R, H)


## Rác lẫn trong đụn: túi nilon, cốc nhựa, giấy, lon, chai.
func add_trash_bits(vis: Node3D, R: float, H: float, r: RandomNumberGenerator) -> void:
	var n: int = r.randi_range(6, 9)
	for i in n:
		var u: float = sqrt(r.randf()) * 0.9
		var th: float = r.randf() * TAU
		var h: float = H * pow(maxf(0.0, 1.0 - u * u), 0.7)
		var p: Vector3 = Vector3(cos(th) * u * R, h - 0.02, sin(th) * u * R)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var kind: int = r.randi_range(0, 4)
		match kind:
			0, 1:  # túi nilon
				var sp: SphereMesh = SphereMesh.new()
				var rad: float = r.randf_range(0.07, 0.13)
				sp.radius = rad
				sp.height = rad * r.randf_range(1.0, 1.5)
				sp.radial_segments = 7
				sp.rings = 4
				mi.mesh = sp
				var bag_cols: Array = [Color(0.06, 0.06, 0.07), Color(0.06, 0.06, 0.07), Color(0.14, 0.24, 0.45), Color(0.5, 0.12, 0.1), Color(0.82, 0.82, 0.8)]
				mi.material_override = mat(bag_cols[r.randi_range(0, 4)], 0.35)
				mi.scale = Vector3(1.0, r.randf_range(0.6, 0.9), r.randf_range(0.8, 1.2))
			2:  # cốc nhựa / lon
				var cy: CylinderMesh = CylinderMesh.new()
				var can: bool = r.randf() < 0.5
				cy.top_radius = 0.033 if can else 0.042
				cy.bottom_radius = 0.033 if can else 0.03
				cy.height = 0.12 if can else 0.1
				cy.radial_segments = 10
				mi.mesh = cy
				var m: StandardMaterial3D = mat(Color(0.75, 0.1, 0.1) if can else Color(0.92, 0.92, 0.9), 0.3)
				m.metallic = 0.6 if can else 0.0
				mi.material_override = m
				mi.rotation = Vector3(r.randf_range(1.1, 1.6), r.randf() * TAU, 0)
			3:  # giấy, hộp xốp
				var bx: BoxMesh = BoxMesh.new()
				bx.size = Vector3(r.randf_range(0.1, 0.18), 0.004, r.randf_range(0.08, 0.14))
				mi.mesh = bx
				mi.material_override = mat(Color(0.88, 0.86, 0.8), 0.9)
				mi.rotation = Vector3(r.randf_range(-0.8, 0.8), r.randf() * TAU, r.randf_range(-0.8, 0.8))
			_:  # chai nhựa
				var cy2: CylinderMesh = CylinderMesh.new()
				cy2.top_radius = 0.02
				cy2.bottom_radius = 0.035
				cy2.height = 0.2
				cy2.radial_segments = 10
				mi.mesh = cy2
				var mb: StandardMaterial3D = mat(Color(0.7, 0.85, 0.8), 0.15)
				mi.material_override = mb
				mi.rotation = Vector3(r.randf_range(1.2, 1.5), r.randf() * TAU, 0)
		mi.position = p
		vis.add_child(mi)


# ====================================================================== tường gạch bao quanh khu phố

const WALL_H: float = 3.2         # cao tường
const WALL_T: float = 0.22        # dày tường
const WALL_SEG: float = 4.0       # mỗi đoạn 4 m ứng với 1 ô trong atlas 2x2 (textures/tuong)


## Dựng tường gạch quanh hình chữ nhật (hw, hd = nửa rộng, nửa sâu). Mặt trong dùng 4 biến thể ngẫu nhiên
## (vữa bong, giấy dán, chữ quảng cáo vẽ tay), có lật ngang để bớt lặp; đỉnh tường trát xi măng.
func build_perimeter_wall(hw: float, hd: float) -> void:
	var mat_w: StandardMaterial3D = StandardMaterial3D.new()
	if ResourceLoader.exists("res://textures/tuong/tuong_gach.jpg"):
		mat_w.albedo_texture = load("res://textures/tuong/tuong_gach.jpg")
		mat_w.normal_enabled = true
		mat_w.normal_texture = load("res://textures/tuong/tuong_gach_normal.png")
		mat_w.normal_scale = 1.2
	else:
		mat_w.albedo_color = Color(0.7, 0.36, 0.22)
	mat_w.roughness = 0.92
	mat_w.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wr: RandomNumberGenerator = RandomNumberGenerator.new()
	wr.seed = 3204
	# 4 cạnh: điểm đầu, điểm cuối, pháp tuyến hướng vào trong phố
	var sides: Array = [
		[Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd), Vector3(0, 0, 1)],
		[Vector3(hw, 0, -hd), Vector3(hw, 0, hd), Vector3(-1, 0, 0)],
		[Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(0, 0, -1)],
		[Vector3(-hw, 0, hd), Vector3(-hw, 0, -hd), Vector3(1, 0, 0)],
	]
	for sd in sides:
		var a: Vector3 = sd[0]
		var b: Vector3 = sd[1]
		var n: Vector3 = sd[2]
		var length: float = a.distance_to(b)
		var dir: Vector3 = (b - a) / length
		var segs: int = maxi(1, int(ceil(length / WALL_SEG)))
		for i in segs:
			var p0: Vector3 = a + dir * (float(i) * WALL_SEG)
			var p1: Vector3 = a + dir * minf(float(i + 1) * WALL_SEG, length)
			var frac: float = p0.distance_to(p1) / WALL_SEG
			var v: int = wr.randi_range(0, 3)
			var u0: float = float(v % 2) * 0.5
			var v0: float = float(v / 2) * 0.5
			var flip: bool = v == 2 and wr.randf() < 0.5  # chỉ lật ô không có chữ
			var ua: float = u0 + (0.5 - 0.5 * frac if flip else 0.0)
			var ub: float = ua + 0.5 * frac
			if flip:
				var tmp: float = ua
				ua = ub
				ub = tmp
			var q0: Vector3 = p0 + n * WALL_T * 0.0
			var q1: Vector3 = p1
			# mặt trong
			_wall_quad(st, [q0 + Vector3(0, WALL_H, 0), q1 + Vector3(0, WALL_H, 0), q1, q0], n,
					[Vector2(ua, v0), Vector2(ub, v0), Vector2(ub, v0 + 0.5), Vector2(ua, v0 + 0.5)])
			# đỉnh tường (trát vữa, lấy mảng vữa ở mép trên ô)
			var o0: Vector3 = q0 - n * WALL_T
			var o1: Vector3 = q1 - n * WALL_T
			_wall_quad(st, [o0 + Vector3(0, WALL_H, 0), o1 + Vector3(0, WALL_H, 0), q1 + Vector3(0, WALL_H, 0), q0 + Vector3(0, WALL_H, 0)], Vector3.UP,
					[Vector2(ua, v0 + 0.002), Vector2(ub, v0 + 0.002), Vector2(ub, v0 + 0.02), Vector2(ua, v0 + 0.02)])
			# mặt ngoài (ít khi thấy)
			_wall_quad(st, [o1 + Vector3(0, WALL_H, 0), o0 + Vector3(0, WALL_H, 0), o0, o1], -n,
					[Vector2(ub, v0), Vector2(ua, v0), Vector2(ua, v0 + 0.5), Vector2(ub, v0 + 0.5)])
			# lớp vữa trát dày, nổi khỏi mặt gạch
			_add_plaster(v, flip, p0, dir, n, p0.distance_to(p1), mat_w)
	st.generate_tangents()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat_w
	add_child(mi)


# ---- lớp vữa trát nổi (khối dày 2,5 cm dựng từ mặt nạ textures/tuong/tuong_vua_mask.png)
const PLASTER_T: float = 0.025
const PL_COLS: int = 200        # điểm mặt nạ theo chiều ngang mỗi ô (2 cm / điểm)
const PL_ROWS: int = 160
var _pl_mask: Image
var _pl_cache: Dictionary = {}
var _pl_side_mat: StandardMaterial3D


func _add_plaster(v: int, flip: bool, p0: Vector3, dir: Vector3, n: Vector3, length: float, mat_w: Material) -> void:
	if _pl_mask == null:
		if not ResourceLoader.exists("res://textures/tuong/tuong_vua_mask.png"):
			return
		_pl_mask = (load("res://textures/tuong/tuong_vua_mask.png") as Texture2D).get_image()
		_pl_side_mat = StandardMaterial3D.new()
		_pl_side_mat.albedo_color = Color(0.8, 0.78, 0.71)  # vữa lót xám trắng ở mép vỡ
		_pl_side_mat.roughness = 1.0
	var cols: int = clampi(int(round(length / WALL_SEG * float(PL_COLS))), 1, PL_COLS)
	var key: String = "%d_%s_%d" % [v, flip, cols]
	if not _pl_cache.has(key):
		_pl_cache[key] = _plaster_mesh(v, flip, cols, mat_w)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _pl_cache[key]
	mi.transform = Transform3D(Basis(dir, Vector3.UP, n), p0)
	add_child(mi)


func _pl_on(v: int, flip: bool, c: int, r: int) -> bool:
	if c < 0 or c >= PL_COLS or r < 0 or r >= PL_ROWS:
		return false
	var cc: int = (PL_COLS - 1 - c) if flip else c
	var ox: int = (v % 2) * PL_COLS
	var oy: int = (v / 2) * PL_ROWS
	return _pl_mask.get_pixel(ox + cc, oy + r).r > 0.5


## Khối vữa: mặt trên ghép thành dải theo từng hàng (ít tam giác), thành bên dựng ở mọi mép vỡ.
## Toạ độ cục bộ: x dọc tường, y lên trên, z hướng vào phố.
func _plaster_mesh(v: int, flip: bool, cols: int, mat_w: Material) -> ArrayMesh:
	var cw: float = WALL_SEG / float(PL_COLS)
	var rh: float = WALL_H / float(PL_ROWS)
	var u0: float = float(v % 2) * 0.5
	var v0: float = float(v / 2) * 0.5
	var top: SurfaceTool = SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side: SurfaceTool = SurfaceTool.new()
	side.begin(Mesh.PRIMITIVE_TRIANGLES)
	var T: float = PLASTER_T
	var uvf: Callable = func(x: float, y: float) -> Vector2:
		var ux: float = x / WALL_SEG
		if flip:
			ux = 1.0 - ux
		return Vector2(u0 + ux * 0.5, v0 + (1.0 - y / WALL_H) * 0.5)
	for r in PL_ROWS:
		var y1: float = WALL_H - float(r) * rh
		var y0: float = y1 - rh
		var c: int = 0
		while c < cols:
			if not _pl_on(v, flip, c, r):
				c += 1
				continue
			var c0: int = c
			while c < cols and _pl_on(v, flip, c, r):
				c += 1
			var x0: float = float(c0) * cw
			var x1: float = float(c) * cw
			var q: Array = [Vector3(x0, y1, T), Vector3(x1, y1, T), Vector3(x1, y0, T), Vector3(x0, y0, T)]
			for idx in [0, 2, 1, 0, 3, 2]:
				top.set_normal(Vector3.BACK)
				top.set_uv(uvf.call(q[idx].x, q[idx].y))
				top.add_vertex(q[idx])
		# thành bên: trên/dưới của từng ô, trái/phải
		for cc in cols:
			if not _pl_on(v, flip, cc, r):
				continue
			var xa: float = float(cc) * cw
			var xb: float = xa + cw
			if not _pl_on(v, flip, cc, r - 1):
				_pl_side(side, Vector3(xa, y1, 0), Vector3(xb, y1, 0), Vector3.UP, T)
			if not _pl_on(v, flip, cc, r + 1):
				_pl_side(side, Vector3(xb, y0, 0), Vector3(xa, y0, 0), Vector3.DOWN, T)
			if cc == 0 or not _pl_on(v, flip, cc - 1, r):
				_pl_side(side, Vector3(xa, y0, 0), Vector3(xa, y1, 0), Vector3.LEFT, T)
			if cc == cols - 1 or not _pl_on(v, flip, cc + 1, r):
				_pl_side(side, Vector3(xb, y1, 0), Vector3(xb, y0, 0), Vector3.RIGHT, T)
	top.generate_tangents()
	var mesh: ArrayMesh = top.commit()
	mesh.surface_set_material(0, mat_w)
	side.commit(mesh)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _pl_side_mat)
	return mesh


func _pl_side(st: SurfaceTool, a: Vector3, b: Vector3, nrm: Vector3, t: float) -> void:
	var q: Array = [a + Vector3(0, 0, t), b + Vector3(0, 0, t), b, a]
	for idx in [0, 2, 1, 0, 3, 2]:
		st.set_normal(nrm)
		st.add_vertex(q[idx])


func _wall_quad(st: SurfaceTool, v: Array, n: Vector3, uv: Array) -> void:
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_normal(n)
		st.set_uv(uv[idx])
		st.add_vertex(v[idx])
