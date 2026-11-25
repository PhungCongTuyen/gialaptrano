extends Node
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var g = GameState
	m.hud.hide_menu()
	m.hud.fade_rect.color.a = 0.0
	m.hud.show_panels(false)
	m.in_room = false
	m.game_live = false
	var walks: Array = m._sidewalk_rects_world()
	var holes: Array = m.town.plan_holes(walks, [], 0)  # chỉ để lấy hàm; dùng dữ liệu đã dựng bên dưới
	# tìm lại hố đã dựng: các Node3D con có nhiều gạch
	var rects: Array = []
	var avoid: Array = []
	for k in m.door_spots.keys():
		avoid.append(m.door_spots[k]["pos"])
	for p in m.TREE_PIXELS:
		avoid.append(m._m(p[0], p[1]))
	avoid.append(m._m(255, 240))
	holes = m.town.plan_holes(walks, avoid, 9)
	print("holes: ", holes.size())
	var shots: Array = []
	for i in mini(3, holes.size()):
		var c2: Vector2 = (holes[i]["rect"] as Rect2).get_center()
		shots.append(["hole_%d" % i, 11 * 60, Vector3(c2.x, 0, c2.y), Vector3(1.4, 1.1, 1.5), -0.6])
	shots.append(["leaves_tree", 9 * 60, m._m(300, 255), Vector3(2.5, 1.6, 2.5), -0.5])
	shots.append(["hole_far", 15 * 60, Vector3((holes[0]["rect"] as Rect2).get_center().x, 0, (holes[0]["rect"] as Rect2).get_center().y), Vector3(4.0, 1.6, 4.5), -0.3])
	for s in shots:
		g.minutes = float(s[1])
		m._apply_time()
		m._update_world_force()
		var c: Vector3 = s[2]
		var p: Vector3 = c + s[3]
		var d: Vector3 = c - p
		m.player.teleport(p, atan2(-d.x, -d.z))
		m.player.set_pitch(s[4])
		for i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % s[0])
		print("saved ", s[0])
	get_tree().quit()
