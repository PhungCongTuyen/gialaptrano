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
	var cam: Camera3D = Camera3D.new()
	cam.fov = 70
	m.add_child(cam)
	cam.current = true
	var hw: float = m.MAP_W * m.PX / 2.0
	var hd: float = m.MAP_H * m.PX / 2.0
	var t1: Vector3 = m._m(300, 255)
	for s in [["wall_1", 10 * 60, Vector3(-hw + 5.0, 1.6, 0.0), Vector3(-hw, 1.8, -2.0)],
			["wall_2", 15 * 60, Vector3(0.0, 1.6, hd - 6.0), Vector3(-6.0, 1.6, hd)],
			["wall_corner", 9 * 60, Vector3(hw - 9.0, 1.7, -hd + 8.0), Vector3(hw, 1.5, -hd)],
			["tree_under", 11 * 60, m._m(470, 258) + Vector3(1.0, 1.6, 1.0), m._m(470, 258) + Vector3(-0.5, 7.0, -0.8)]]:
		g.minutes = float(s[1])
		m._apply_time()
		m._update_world_force()
		cam.global_position = s[2]
		cam.look_at(s[3])
		for i in 12:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % s[0])
		print("saved ", s[0])
	get_tree().quit()
