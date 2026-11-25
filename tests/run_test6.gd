extends Node

var m
var g

func hm():
	if m.hud.menu_open: m.hud.hide_menu()
	if m.hud.live_open: m.hud._end_live()

func goto_day(d: int, minute: int) -> void:
	g.day = d; g.minutes = float(minute); g._new_day_vars(); g.pending_rollovers.clear(); g.morning_pending = false; g.wife_leave_pending = false

func _ready() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	g = GameState
	hm()
	m._show_intro(); m._intro_go_now(); m._intro_boss_enter(); m._intro_take_paper(m.boss_paper); m._intro_end_mid()
	m._day1_at_pc(); m._day1_wife_home(); m._day1_knock(); m._day1_door_mid(); m._day1_rude(); m._day1_rude_notice(); m._day1_begin_mid()
	hm()
	g.health = 100
	# ngày 1: thu nhập cố định 50k
	var r = g.do_stream("game", 3.0); print("D1 income ", r["income"], " viewers ", r["viewers"])
	r = g.do_stream("game", 2.0); print("D1 second stream income ", r["income"])
	goto_day(2, 20 * 60); r = g.do_stream("game", 2.0); print("D2 income ", r["income"])
	goto_day(3, 20 * 60); r = g.do_stream("game", 1.0); print("D3 first_donate ", r["first_donate"])
	m.stream_res = r
	m._play_live(r, func(): print("live done cb"))
	print("live open ", m.hud.live_open, " popups ", m.hud.live_info["popups"])
	for i in 12:
		m.hud._live_process(0.5)
	print("popup text: ", m.hud.live_popup.text, " | live_open ", m.hud.live_open)
	# ngày 13 chủ nợ, thiếu tiền
	goto_day(13, 20 * 60 + 1); g.money = 1_000_000; m.game_live = true
	print("story_poll d13 -> ", m._story_poll(), " ", m.hud.title_label.text)
	hm(); m._collect_door(); print(m.hud.title_label.text, "\n", m.hud.body_label.text); hm(); m._collect_end()
	print("paid ", g.paid, " pc_dur ", g.pc_dur, " smashed ", g.flags.has("smashed"), " repair ", g.repair_cost(), " can_stream ", g.can_stream())
	g.money = 5_000_000; print(g.repair_pc()); print("can_stream ", g.can_stream())
	# ngày 19 vợ
	goto_day(19, 18 * 60 + 30); g.wife_met_today = false; m.in_room = true
	m._check_first_meet(); print("D19: ", m.hud.body_label.text.substr(0, 60)); hm(); m._day19_2(); hm(); m._day19_3(); print("objective: ", m.hud.objective_label.text); hm()
	# ngày 27 chưa thuê nhà -> kết thúc
	goto_day(27, 23 * 60 + 59)
	g.advance(2.0); print("D27 no house -> finished ", g.finished, " ", g.ending_id)
	g.finished = false; g.ending_id = ""
	goto_day(27, 23 * 60 + 59); g.money = 5_000_000; m._do_rent(); hm(); g.advance(2.0); print("D27 with house -> day ", g.day, " finished ", g.finished, " objective '", m.hud.objective_label.text, "'")
	# ngày 31 Linh
	goto_day(31, 12 * 60); m._update_world(); print("Linh visible ", m.linh_npc.visible)
	m._on_interact(m.linh_npc); print("Linh: ", m.hud.body_label.text.substr(0, 50)); hm(); m._linh_2(); hm(); m._linh_3(); hm()
	# ngày 32 lockpick
	goto_day(30, 12 * 60); m._menu_junk(""); var has_lp := false
	for c in m.hud.options_box.get_children(): if "lockpick" in c.text: has_lp = true
	print("D30 lockpick for sale ", has_lp); hm()
	goto_day(32, 8 * 60); print("story32 ", m._story_poll(), " ", m.hud.title_label.text); hm()
	m._menu_junk(""); has_lp = false
	for c in m.hud.options_box.get_children(): if "lockpick" in c.text: has_lp = true
	print("D32 lockpick for sale ", has_lp); hm()
	g.money = 3_000_000; g.buy_item("lockpick"); g.buy_item("lockpick")
	await get_tree().process_frame; hm()
	# công trường trước 37
	m._update_site(0.1); print("D32 gate guard ", m.gate_guard.visible, " patrol ", m.patrol_guard.visible)
	m._menu_gate(); print("gate D32: ", m.hud.body_label.text); hm()
	goto_day(36, 8 * 60); print("story36 ", m._story_poll()); hm()
	goto_day(37, 8 * 60); print("story37 ", m._story_poll()); hm()
	m._update_site(0.1); print("D37 gate guard ", m.gate_guard.visible, " patrol ", m.patrol_guard.visible, " coil ", m.coil_node.visible)
	g.rng.seed = 5
	for i in 5:
		if g.flags.has("site_open"): break
		m._do_pick(); hm()
	print("site_open ", g.flags.has("site_open"))
	# bị bắt 3 lần
	for i in 3:
		m._take_coil()
		m._caught_mid(); print("caught ", i + 1, ": ", m.hud.title_label.text, " | coil in bag ", g.has_item("copper_coil"), " money ", g.money, " finished ", g.finished, " ", g.ending_id)
		hm()
	g.finished = false; g.ending_id = ""; g.flags["site_caught"] = 0
	# lấy cuộn đồng và thoát
	m.in_room = false
	m.player.global_position = m.site_c + Vector3(0, 1, 0)
	m._update_site(0.1); m._take_coil()
	m.player.global_position = m.site_c + Vector3(0, 1, -m.site_d / 2.0 - 2.0)
	m.patrol_guard.position = m.site_c + Vector3(5, 0, 8)
	m._update_site(0.1); print("escaped: site_free ", g.flags.has("site_free"), " ", m.hud.title_label.text); hm()
	m._update_site(0.1); print("digs active ", m.site_digs[0].visible, " patrol ", m.patrol_guard.visible)
	m._menu_site_dig(); hm(); m._do_site_dig(); print("dig: ", m.hud.body_label.text); hm()
	m._menu_junk(""); print("sell coil option present: ", m.hud.body_label.text != ""); hm(); print(g.sell_items("copper_coil", 1))
	# ngày 46 AI
	goto_day(46, 10 * 60); print("story46 ", m._story_poll(), " ", m.hud.title_label.text); hm(); m._ai_refuse(); hm()
	goto_day(49, 20 * 60); r = g.do_stream("game", 1.0); print("D49 rally ", r["rally"], " notes ", r["notes"])
	goto_day(56, 8 * 60); print("story56 ", m._story_poll(), " ", m.hud.body_label.text); hm()
	# ngày 60
	goto_day(60, 23 * 60 + 59); g.wife = 50; g.paid = g.debt_total; g.advance(2.0); print("D60 paid, wife 50 -> ", g.ending_id)
	g.finished = false; goto_day(60, 23 * 60 + 59); g.paid = 0; g.advance(2.0); print("D60 unpaid -> ", g.ending_id)
	m.ending_shown = false; m._show_ending(); print("ENDING: ", m.hud.title_label.text, " | ", m.hud.body_label.text.substr(m.hud.body_label.text.length() - 160))
	print("TEST6 DONE")
	get_tree().quit()
