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
var wrist: Node3D
var watch_label: Label3D
var watch_raised: bool = false
const WRIST_DOWN: Vector3 = Vector3(-0.30, -0.30, -0.55)
const WRIST_UP: Vector3 = Vector3(-0.07, -0.13, -0.38)
const WRIST_DOWN_ROT: Vector3 = Vector3(0.55, 0.35, 0.25)
const WRIST_UP_ROT: Vector3 = Vector3(1.15, 0.05, 0.0)


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
	_build_wrist()
	_build_hands()


## Cánh tay trái đeo đồng hồ, gắn vào camera. Vẽ đè lên mọi thứ để không bị tường che.
func _build_wrist() -> void:
	wrist = Node3D.new()
	wrist.position = WRIST_DOWN
	wrist.rotation = WRIST_DOWN_ROT
	cam.add_child(wrist)
	var arm: MeshInstance3D = MeshInstance3D.new()
	var am: BoxMesh = BoxMesh.new()
	am.size = Vector3(0.09, 0.07, 0.45)
	arm.mesh = am
	arm.position = Vector3(0, 0, 0.2)
	arm.material_override = _overlay_mat(Color(0.85, 0.65, 0.5))
	wrist.add_child(arm)
	var sleeve: MeshInstance3D = MeshInstance3D.new()
	var sm: BoxMesh = BoxMesh.new()
	sm.size = Vector3(0.11, 0.09, 0.2)
	sleeve.mesh = sm
	sleeve.position = Vector3(0, 0, 0.4)
	sleeve.material_override = _overlay_mat(Color(0.25, 0.3, 0.45))
	wrist.add_child(sleeve)
	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.1, 0.02, 0.085)
	body.mesh = bm
	body.position = Vector3(0, 0.043, 0.02)
	body.material_override = _overlay_mat(Color(0.06, 0.06, 0.07))
	wrist.add_child(body)
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
	wrist.add_child(watch_label)


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
	if watch_raised == up:
		return
	watch_raised = up
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(wrist, "position", WRIST_UP if up else WRIST_DOWN, 0.2)
	tw.tween_property(wrist, "rotation", WRIST_UP_ROT if up else WRIST_DOWN_ROT, 0.2)


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
		cam_h = 0.2  # ngồi xổm bới
	cam.position.y = lerpf(cam.position.y, cam_h, minf(1.0, delta * 8.0))
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

	target = null
	if not locked and ray.is_colliding():
		var c: Object = ray.get_collider()
		if c != null and c is Node and (c as Node).has_meta("interact"):
			target = c as Node


# ---------------------------------------------------------------- hai tay bới đụn rác / lá

var hands: Node3D
var _hand_arms: Array = []
var dig_time: float = -1.0
var dig_len: float = 5.0


func _build_hands() -> void:
	hands = Node3D.new()
	hands.visible = false
	cam.add_child(hands)
	var skin: StandardMaterial3D = _overlay_mat(Color(0.85, 0.65, 0.5))
	var shirt: StandardMaterial3D = _overlay_mat(Color(0.25, 0.3, 0.45))
	for side in [-1.0, 1.0]:
		var arm: Node3D = Node3D.new()
		hands.add_child(arm)
		_hand_arms.append([arm, side])
		var parts: Array = [
			[Vector3(0.07, 0.062, 0.3), Vector3(0, 0, 0.15), skin],         # cẳng tay
			[Vector3(0.078, 0.07, 0.1), Vector3(0, 0.002, 0.33), shirt],   # tay áo
			[Vector3(0.085, 0.028, 0.095), Vector3(0, -0.004, -0.04), skin], # bàn tay
		]
		for k in 4:  # ngón tay
			parts.append([Vector3(0.016, 0.017, 0.062), Vector3(-0.03 + float(k) * 0.02, -0.012, -0.112), skin])
		parts.append([Vector3(0.019, 0.019, 0.05), Vector3(0.048 * -side, -0.004, -0.06), skin])  # ngón cái
		for pt in parts:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = pt[0]
			mi.mesh = bm
			mi.position = pt[1]
			mi.material_override = pt[2]
			if (pt[0] as Vector3).z < 0.08 and (pt[1] as Vector3).z < -0.1:
				mi.rotation.x = 0.5  # ngón co lại như đang cào
			arm.add_child(mi)


## Bắt đầu hoạt ảnh hai tay đào bới trong `seconds` giây.
func play_dig(seconds: float) -> void:
	dig_len = seconds
	dig_time = 0.0
	hands.visible = true
	wrist.visible = false
	_update_hands()


func stop_dig() -> void:
	dig_time = -1.0
	hands.visible = false
	wrist.visible = true


func _process(delta: float) -> void:
	if dig_time >= 0.0:
		dig_time += delta
		_update_hands()


func _update_hands() -> void:
	var t: float = dig_time
	var enter: float = clampf(t / 0.3, 0.0, 1.0) * clampf((dig_len - t) / 0.3, 0.0, 1.0)  # thò tay vào / rút ra
	for e in _hand_arms:
		var arm: Node3D = e[0]
		var side: float = e[1]
		var ph: float = t * TAU * 1.7 + (0.0 if side < 0.0 else PI)
		var sc: float = sin(ph)
		var dn: float = maxf(0.0, sc)
		arm.position = Vector3(0.13 * side - 0.03 * side * sc, -0.2 - 0.07 * dn - 0.3 * (1.0 - enter), -0.62 - 0.1 * sc)
		arm.rotation = Vector3(-0.7 - 0.45 * dn + 0.2 * maxf(0.0, -sc), 0.22 * side, 0.3 * side * cos(ph))
