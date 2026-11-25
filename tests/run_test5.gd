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
	m._exit_room()
	g.minutes = 9 * 60
	Engine.time_scale = 20.0
	var hidden_seen := 0
	var max_path := 0
	for i in 300:
		await get_tree().process_frame
		if m.hud.menu_open:
			m.hud.hide_menu()
		for wk in m.walkers:
			if not wk["node"].visible: hidden_seen += 1
	Engine.time_scale = 1.0
	print(g.clock_str(), " walkers ", m.walkers.size(), " groups ", m.groups.size(), " group sizes ", m.groups.map(func(x): return x.size()), " hidden(in shop) frames ", hidden_seen)
	# đi người có nằm trong khu đi lại không
	var bad := 0
	for wk in m.walkers:
		var p: Vector3 = wk["node"].position
		var inside := false
		for c in m.CORRIDORS.size():
			var w = m._corr_world(c)
			if p.x >= w[0] - 0.5 and p.x <= w[2] + 0.5 and p.z >= w[1] - 0.5 and p.z <= w[3] + 0.5: inside = true
		if not inside: bad += 1
	print("walkers ngoài khu đi lại: ", bad)
	var npc = m.groups[0][0]
	m._talk_npc(npc); print("TALK: ", m.hud.title_label.text, " — ", m.hud.body_label.text); m.hud.hide_menu()
	m._talk_npc(m.walkers[0]["node"]); print("TALK: ", m.hud.title_label.text, " — ", m.hud.body_label.text); m.hud.hide_menu()
	g.minutes = 19 * 60; m._update_world(); print("evening walkers ", m.walkers.size(), " groups ", m.groups.size())
	g.minutes = 23 * 60 + 30; m._update_world(); print("night walkers ", m.walkers.size(), " groups ", m.groups.size(), " robbers ", m.robbers.size())
	print("TEST5 DONE")
	get_tree().quit()
