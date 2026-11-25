extends Node
## Chụp cây xanh: góc phố rộng, dưới tán nhìn lên, và buổi chiều.
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
	var t1: Vector3 = m._m(300, 255)
	var t2: Vector3 = m._m(150, 280)
	for s in [["tree_wide", 10 * 60, t1 + Vector3(-9.0, 1.7, 9.0), t1 + Vector3(0, 4.5, 0)],
			["tree_under", 11 * 60, t1 + Vector3(1.5, 1.6, 2.0), t1 + Vector3(-0.5, 6.5, -1.5)],
			["tree_street", 16 * 60, t2 + Vector3(4.0, 1.7, 14.0), t2 + Vector3(0, 3.5, -2.0)]]:
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
