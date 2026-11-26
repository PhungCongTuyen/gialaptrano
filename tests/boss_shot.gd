extends Node
## Chụp phòng giám đốc trong intro.
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
	print("saved ", n)

func cam(m, pos: Vector3, at: Vector3, n: String) -> void:
	var c: Camera3D = Camera3D.new()
	m.add_child(c)
	c.fov = 72
	c.global_position = m.BOSS_ORIGIN + pos
	c.look_at(m.BOSS_ORIGIN + at)
	c.current = true
	await get_tree().create_timer(0.4).timeout
	shot(n)
	c.queue_free()

func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.0).timeout
	m.title_menu.start_game.emit()
	await get_tree().create_timer(1.0).timeout
	m.hud.hide_menu()
	m._intro_boss_enter()
	await get_tree().create_timer(1.0).timeout
	shot("bgd1_vao_phong")
	m.hud.hide_menu()
	m._intro_boss_1()
	await get_tree().create_timer(1.8).timeout
	shot("bgd2_ngang_dau")
	m.hud.hide_menu()
	await cam(m, Vector3(3.3, 2.2, 2.6), Vector3(-1.0, 0.9, -1.3), "bgd3_toan_canh")
	await cam(m, Vector3(1.6, 1.4, 1.8), Vector3(-2.8, 0.7, 0.4), "bgd4_sofa")
	await cam(m, Vector3(0.35, 1.25, -0.6), Vector3(0.0, 1.2, -2.2), "bgd5_giam_doc")
	await cam(m, Vector3(-0.5, 1.5, 0.5), Vector3(-2.6, 1.3, -2.8), "bgd6_tu_sach")
	get_tree().quit()
