extends Node

func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var g = GameState
	m.hud.hide_menu()
	m._show_intro(); m._intro_go_now(); m._intro_boss_enter(); m._intro_take_paper(m.boss_paper); m._intro_end_mid()
	m._day1_at_pc(); m._day1_wife_home(); m._day1_knock(); m._day1_door_mid(); m._day1_polite(); m._day1_begin_mid()
	m.hud.hide_menu()
	await get_tree().create_timer(1.0).timeout
	# ở ngoài đường lúc 23:20 -> 23:30 cảnh báo -> 00:00 mất 5%
	m._exit_room()
	g.minutes = 23 * 60 + 20; g.money = 1_000_000
	Engine.time_scale = 40.0
	var seen := []
	for i in 400:
		await get_tree().process_frame
		if m.hud.menu_open:
			seen.append(m.hud.title_label.text + " @" + g.clock_str())
			if m.hud.title_label.text.begins_with("HẾT NGÀY"):
				print("NIGHT PANEL:\n", m.hud.body_label.text)
			m.hud.hide_menu()
			if m.hud.title_label.text.begins_with("HẾT NGÀY"):
				m._night_done()
		if g.day == 2 and g.minutes >= 6 * 60 + 5 and seen.size() >= 2: break
	Engine.time_scale = 1.0
	print("seen: ", seen)
	print("after: day ", g.day, " ", g.clock_str(), " money ", g.money, " in_room ", m.in_room)
	# ở nhà lúc 0:00 -> không mất tiền
	g.minutes = 23 * 60 + 58; g.money = 1_000_000; m.in_room = true; m.game_live = true
	g.advance(5.0); print("home midnight pending ", g.midnight_pending, " clock ", g.clock_str())
	m._midnight_mid(); print("HOME PANEL: ", m.hud.title_label.text, " | money ", g.money, " clock ", g.clock_str()); m.hud.hide_menu(); m._night_done()
	# ngủ sớm lúc 21:00
	g.minutes = 21 * 60
	m._sleep_mid(); print("EARLY: ", m.hud.title_label.text, " | ", g.clock_str(), " day ", g.day); m.hud.hide_menu(); m._night_done()
	# giới hạn giờ stream trước 0:00
	g.minutes = 21 * 60 + 30; g.stream_min_today = 0
	print("stream hours left at 21:30: ", g.stream_hours_left())
	g.minutes = 23 * 60 + 20; print("stream hours left at 23:20: ", g.stream_hours_left())
	# 7:00 vợ đi làm (đã dậy 6:00)
	g.minutes = 6 * 60 + 58; m.in_room = true; g.advance(3.0); print("wife leave pending ", g.wife_leave_pending)
	print("TEST7 DONE")
	get_tree().quit()
