extends Node
func shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/shots/%s.png" % n)
	print("saved ", n)

func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.0).timeout
	m.title_menu.start_game.emit()
	await get_tree().create_timer(2.6).timeout
	shot("s1_phu_de")
	print("sub_mode=", m.hud.sub_mode, " body=", m.hud.body_label.text.left(40))
	# chờ tự chuyển sang câu Linh (có lựa chọn)
	var t0: int = Time.get_ticks_msec()
	while m.hud.sub_mode and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	print("auto advanced after ", Time.get_ticks_msec() - t0, " ms; sub_mode=", m.hud.sub_mode, " title=", m.hud.title_label.text)
	await get_tree().create_timer(4.0).timeout
	shot("s2_lua_chon")
	# chọn đi ngay -> câu Linh trả lời (phụ đề) -> thử Space bỏ qua
	m.hud._choose(m._intro_go_now)
	await get_tree().create_timer(0.8).timeout
	print("before space: ", m.hud.title_label.text, " / ", m.hud.body_label.text.left(30))
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_SPACE
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().create_timer(0.8).timeout
	print("after space: sub_mode=", m.hud.sub_mode, " menu_open=", m.hud.menu_open)
	shot("s3_sau_space")
	get_tree().quit()
