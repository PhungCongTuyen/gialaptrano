extends Node
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
	print("saved ", n)

func _ready() -> void:
	# tạo 2 bản lưu mẫu
	var g = GameState
	g.day = 12; g.money = 1350000
	g.save_game(1, {"in_room": false, "pos": [0, 1, 0], "yaw": 0.0})
	g.day = 27; g.money = 420000
	g.save_game(3, {"in_room": false, "pos": [0, 1, 0], "yaw": 0.0})
	g.day = 1; g.money = 0
	Settings.lang = "vi"; Settings.apply()
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.5).timeout
	shot("t1_title")
	m.title_menu._open_saves()
	await get_tree().create_timer(0.6).timeout
	shot("t2_saves")
	m.title_menu._close_overlay()
	m.title_menu._open_options()
	await get_tree().create_timer(0.6).timeout
	shot("t3_options")
	Settings.lang = "en"; Settings.apply()
	await get_tree().create_timer(0.3).timeout
	shot("t4_options_en")
	m.title_menu.overlay.close()
	await get_tree().create_timer(0.4).timeout
	shot("t5_title_en")
	Settings.lang = "vi"; Settings.apply()
	m.title_menu.start_game.emit()
	await get_tree().create_timer(3.0).timeout
	shot("t6_intro")
	print("title_menu=", m.title_menu, " cam=", m.title_cam, " minutes=", g.minutes)
	m._menu_pause()
	await get_tree().create_timer(1.5).timeout
	m._pause_options()
	await get_tree().create_timer(0.5).timeout
	shot("t7_pause_options")
	get_tree().quit()
