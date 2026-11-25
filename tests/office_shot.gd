extends Node
## Chụp văn phòng intro: Linh đi tới, đồng nghiệp ngồi gõ phím, vài góc nhìn.
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
	print("saved ", n)

func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.0).timeout
	m.title_menu.start_game.emit()
	await get_tree().create_timer(2.2).timeout
	shot("vp1_mo_dau")
	await get_tree().create_timer(2.4).timeout
	var cam: Camera3D = m.player.cam
	# góc nhìn ra phía cửa thấy Linh đang đi tới
	var saved: Transform3D = m.player.global_transform
	m.player.rotation.y = PI
	await get_tree().process_frame
	shot("vp2_linh_di_toi")
	m.player.global_transform = saved
	var t0: int = Time.get_ticks_msec()
	while not m.intro_linh_ready and Time.get_ticks_msec() - t0 < 12000:
		await get_tree().process_frame
	await get_tree().create_timer(1.6).timeout
	shot("vp3_linh_noi")
	# camera tự do: toàn cảnh văn phòng
	var c2: Camera3D = Camera3D.new()
	m.add_child(c2)
	c2.fov = 75
	c2.global_position = m.OFFICE_ORIGIN + Vector3(5.2, 2.5, 4.0)
	c2.look_at(m.OFFICE_ORIGIN + Vector3(-1.5, 0.8, -1.0))
	c2.current = true
	await get_tree().create_timer(0.5).timeout
	shot("vp4_toan_canh")
	c2.global_position = m.OFFICE_ORIGIN + Vector3(-0.3, 1.5, 3.3)
	c2.look_at(m.OFFICE_ORIGIN + Vector3(-3.5, 0.9, 1.0))
	await get_tree().create_timer(0.3).timeout
	shot("vp5_dong_nghiep")
	c2.global_position = m.OFFICE_ORIGIN + Vector3(-1.0, 1.6, -0.4)
	c2.look_at(m.OFFICE_ORIGIN + Vector3(-5.5, 1.0, 3.5))
	await get_tree().create_timer(0.3).timeout
	shot("vp6_tu_ho_so")
	c2.global_position = m.OFFICE_ORIGIN + Vector3(-1.45, 1.45, -2.75)
	c2.look_at(m.OFFICE_ORIGIN + Vector3(-2.2, 1.2, -1.9))
	await get_tree().create_timer(0.3).timeout
	shot("vp7_linh_gan")
	get_tree().quit()
