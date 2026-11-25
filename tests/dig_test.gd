extends Node
## Đi tới đụn đầu tiên, bấm bới: chụp ảnh đụn, ảnh lúc đang bới, rồi kiểm tra có kết quả.
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var g = GameState
	m.hud.hide_menu()
	m.hud.fade_rect.color.a = 0.0
	m.hud.show_panels(true)
	m.in_room = false
	m.game_live = false
	g.minutes = 10 * 60.0
	m._apply_time()
	m._update_world_force()
	if m.piles.is_empty():
		m._spawn_piles()
	print("piles: ", m.piles.size())
	var shots: Array = []
	for i in mini(2, m.piles.size()):
		var t: Node3D = m.piles[i]
		print("pile ", i, " kind=", t.get_meta("pile"), " at ", t.global_position)
		var p: Vector3 = t.global_position + Vector3(1.3, 0.0, 0.9)
		var d: Vector3 = t.global_position - p
		m.player.teleport(p + Vector3(0, 0.9, 0), atan2(-d.x, -d.z))
		m.player.set_pitch(-0.55)
		for k in 8:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("/tmp/shots/pile_%d.png" % i)
	# bới đụn 0
	var t0: Node3D = m.piles[1]
	var money0: int = g.money
	var inv0: int = 0
	m._on_interact(t0)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/dig_mid.png")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/dig_mid2.png")
	print("digging=", m.digging, " locked=", m.player.locked)
	await get_tree().create_timer(4.3).timeout
	print("digging=", m.digging, " piles_left=", m.piles.size(), " money ", money0, "->", g.money)
	get_viewport().get_texture().get_image().save_png("/tmp/shots/dig_done.png")
	get_tree().quit()
