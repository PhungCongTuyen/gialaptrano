extends Node
## Chụp tư thế tay: đứng yên, giơ đồng hồ, đang bới.
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
	var t: Node3D = m.piles[0]
	var p: Vector3 = t.global_position + Vector3(1.2, 0.9, 0.8)
	var d: Vector3 = t.global_position - p
	m.player.teleport(p, atan2(-d.x, -d.z))
	m.player.set_pitch(-0.35)
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/arms_idle.png")
	m.player.raise_watch(true)
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/arms_watch.png")
	m.player.raise_watch(false)
	await get_tree().create_timer(0.4).timeout
	m._on_interact(t)
	await get_tree().create_timer(1.1).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/arms_dig1.png")
	await get_tree().create_timer(0.3).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/shots/arms_dig2.png")
	print("done")
	get_tree().quit()
