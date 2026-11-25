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
	var tree: Vector3 = m._m(300, 255)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 60
	m.add_child(cam)
	cam.current = true
	for s in [["close_tiles", 16 * 60, tree + Vector3(-3.0, 0.35, 1.6), tree + Vector3(-4.2, 0.0, 0.6)],
			["close_leaves", 9 * 60, tree + Vector3(1.0, 0.45, 1.0), tree + Vector3(0.3, 0.0, 0.35)],
			["low_street", 16 * 60, tree + Vector3(-6.0, 0.6, 0.8), tree + Vector3(-1.0, 0.0, 0.2)]]:
		g.minutes = float(s[1])
		m._apply_time()
		m._update_world_force()
		cam.global_position = s[2]
		cam.look_at(s[3])
		for i in 10:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % s[0])
		print("saved ", s[0])
	get_tree().quit()
