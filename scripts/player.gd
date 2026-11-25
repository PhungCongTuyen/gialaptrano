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
var wrist: Node3D      # tay trái (đeo đồng hồ)
var arm_r: Node3D      # tay phải
var watch_label: Label3D
var watch_raised: bool = false
# Hai tay luôn ở mép dưới màn hình (kiểu CS2). Toạ độ theo camera.
const ARM_IDLE_POS: Vector3 = Vector3(0.27, -0.25, -0.46)   # tay phải; tay trái lật dấu x
const ARM_IDLE_ROT: Vector3 = Vector3(0.34, 0.24, -0.3)    # tay phải; tay trái lật dấu y, z
const WRIST_UP: Vector3 = Vector3(-0.07, -0.13, -0.38)
const WRIST_UP_ROT: Vector3 = Vector3(1.15, 0.05, 0.0)
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
	wrist = _make_arm(-1.0, true)
	arm_r = _make_arm(1.0, false)
	_update_arms(0.0)


## Một cánh tay (cẳng tay, tay áo, bàn tay, ngón tay) gắn vào camera, vẽ đè lên mọi thứ để không bị tường che.
## Tay trái có đồng hồ đeo ở cổ tay.
func _make_arm(side: float, watch: bool) -> Node3D:
	var arm: Node3D = Node3D.new()
	cam.add_child(arm)
	var skin: StandardMaterial3D = _overlay_mat(Color(0.85, 0.65, 0.5))
	var shirt: StandardMaterial3D = _overlay_mat(Color(0.25, 0.3, 0.45))
	var parts: Array = [
		[Vector3(0.085, 0.07, 0.45), Vector3(0, 0, 0.2), skin, 0.0],          # cẳng tay
		[Vector3(0.11, 0.09, 0.2), Vector3(0, 0, 0.42), shirt, 0.0],           # tay áo
		[Vector3(0.09, 0.03, 0.1), Vector3(0, -0.006, -0.07), skin, 0.0],      # bàn tay
		[Vector3(0.022, 0.022, 0.055), Vector3(0.05 * -side, -0.002, -0.07), skin, 0.0],  # ngón cái
	]
	for k in 4:  # ngón tay, hơi co
		parts.append([Vector3(0.017, 0.018, 0.065), Vector3(-0.032 + float(k) * 0.021, -0.02, -0.14), skin, 0.45])
	for pt in parts:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = pt[0]
		mi.mesh = bm
		mi.position = pt[1]
		mi.rotation.x = pt[3]
		mi.material_override = pt[2]
		arm.add_child(mi)
	if watch:
		var body: MeshInstance3D = MeshInstance3D.new()
		var wb: BoxMesh = BoxMesh.new()
		wb.size = Vector3(0.1, 0.02, 0.085)
		body.mesh = wb
		body.position = Vector3(0, 0.043, 0.02)
		body.material_override = _overlay_mat(Color(0.06, 0.06, 0.07))
		arm.add_child(body)
		watch_label = Label3D.new()
		watch_label.position = Vector3(0, 0.055, 0.02)
		watch_label.rotation = Vector3(-PI / 2.0, 0, 0)
		watch_label.pixel_size = 0.00028
		watch_label.font_size = 64
		watch_label.outline_size = 0
		watch_label.modulate = Color(0.55, 1.0, 0.65)
		watch_label.no_depth_test = true
		watch_label.render_priority = 12
		watch_label.double_sided = false
		watch_label.text = "07:00"
		arm.add_child(watch_label)
	return arm


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


# ---------------------------------------------------------------- tư thế hai tay: đứng / đi / xem đồng hồ / bới

var dig_time: float = -1.0
var dig_len: float = 5.0


## Bắt đầu động tác bới trong `seconds` giây (người cúi xuống, hai tay cào bới).
func play_dig(seconds: float) -> void:
	dig_len = seconds
	dig_time = 0.0
	watch_raised = false


func stop_dig() -> void:
	dig_time = -1.0


func _process(delta: float) -> void:
	_life_t += delta
	if dig_time >= 0.0:
		dig_time += delta
	_update_arms(delta)


func _update_arms(delta: float) -> void:
	var k: float = minf(1.0, delta * 10.0) if delta > 0.0 else 1.0
	_w_watch = lerpf(_w_watch, 1.0 if watch_raised else 0.0, k)
	_w_dig = lerpf(_w_dig, 1.0 if dig_time >= 0.0 else 0.0, minf(1.0, delta * 7.0) if delta > 0.0 else 1.0)
	var breathe: float = sin(_life_t * 1.6) * 0.004
	for e in [[wrist, -1.0], [arm_r, 1.0]]:
		var arm: Node3D = e[0]
		var side: float = e[1]
		# đứng yên / đi: ở góc dưới màn hình, nhún theo bước chân
		var bob: Vector3 = Vector3(sin(_bob_t) * 0.012 * side, -absf(cos(_bob_t)) * 0.016, 0.0) * _bob_amp
		var pos: Vector3 = Vector3(ARM_IDLE_POS.x * side, ARM_IDLE_POS.y + breathe, ARM_IDLE_POS.z) + bob
		var rot: Vector3 = Vector3(ARM_IDLE_ROT.x, ARM_IDLE_ROT.y * side, ARM_IDLE_ROT.z * side)
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
			rot = rot.lerp(WRIST_UP_ROT, _w_watch)
		arm.position = pos
		arm.rotation = rot
