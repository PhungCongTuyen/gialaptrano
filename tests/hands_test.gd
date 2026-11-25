extends Node
## Chụp tay mô hình Blender ở các tư thế: đứng, cầm chai nước, uống, cầm bánh mì, ăn, cầm báo cáo, giấy nghỉ việc, xem đồng hồ.
func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/shots/h_%s.png" % name)

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
	g.minutes = 10 * 60.0
	m._apply_time()
	m._update_world_force()
	var pl = m.player
	pl.teleport(m._m(300, 245) + Vector3(0, 0.9, 0), 0.6)
	pl.set_pitch(-0.15)
	await get_tree().create_timer(0.5).timeout
	shot("1_dung")
	var seq: Array = [["water", "2_chai_nuoc", ""], ["water", "3_uong", "drink"], ["banhmi", "4_banh_mi", ""], ["banhmi", "5_an", "eat"], ["soda", "6_lon", ""], ["com_hop", "7_hop_com", ""], ["ring_gold", "8_nhan", ""]]
	m.game_live = true
	for s in seq:
		g.inventory[g.selected] = {"id": s[0], "count": 1}
		if s[2] != "":
			pl.play_use(s[2], 1.6)
			await get_tree().create_timer(0.8).timeout
			shot(s[1])
			await get_tree().create_timer(1.0).timeout
		else:
			await get_tree().create_timer(0.5).timeout
			shot(s[1])
	g.inventory[g.selected] = {}
	m.game_live = false
	pl.hold_document("report")
	await get_tree().create_timer(0.6).timeout
	shot("9_bao_cao")
	pl.hold_document("paper")
	await get_tree().create_timer(0.6).timeout
	shot("10_giay_nghi_viec")
	pl.hold_document("")
	pl.raise_watch(true)
	await get_tree().create_timer(0.5).timeout
	shot("11_dong_ho")
	print("done")
	get_tree().quit()
