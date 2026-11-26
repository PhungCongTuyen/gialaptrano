extends Node
## Kiểm tra va chạm văn phòng + phòng giám đốc: bản đồ ô đi được (o nối liền chỗ xuất phát, . bị cô lập, # bị chặn),
## và tia nhìn có trúng báo cáo / giấy nghỉ việc không.
func free_map(m, origin: Vector3, size: Vector3, start: Vector3) -> int:
	var shape_node: CollisionShape3D = m.player.find_children("*", "CollisionShape3D", true, false)[0]
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = shape_node.shape
	q.exclude = [m.player.get_rid()]
	var space: PhysicsDirectSpaceState3D = m.player.get_world_3d().direct_space_state
	var step: float = 0.2
	var nx: int = int(size.x / step)
	var nz: int = int(size.z / step)
	var grid: Array = []
	for j in nz:
		var row: Array = []
		for i in nx:
			var p: Vector3 = origin + Vector3(-size.x / 2 + (i + 0.5) * step, 1.0 + shape_node.position.y + 0.04, -size.z / 2 + (j + 0.5) * step)
			q.transform = Transform3D(shape_node.global_transform.basis, p)
			row.append(space.intersect_shape(q, 1).is_empty())
		grid.append(row)
	var si: int = int((start.x + size.x / 2) / step)
	var sj: int = int((start.z + size.z / 2) / step)
	var seen: Dictionary = {}
	var stack: Array = [Vector2i(si, sj)]
	while stack.size() > 0:
		var c: Vector2i = stack.pop_back()
		if seen.has(c) or c.x < 0 or c.y < 0 or c.x >= nx or c.y >= nz or not grid[c.y][c.x]:
			continue
		seen[c] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(c + d)
	var free_n: int = 0
	var lines: String = ""
	for j in nz:
		var l: String = ""
		for i in nx:
			if not grid[j][i]:
				l += "#"
			else:
				free_n += 1
				l += "o" if seen.has(Vector2i(i, j)) else "."
		lines += l + "\n"
	print(lines)
	print("o tu do: ", free_n, "  noi lien: ", seen.size(), "  bi co lap: ", free_n - seen.size())
	return free_n - seen.size()


func aim(m, target: Node3D) -> void:
	var eye: Vector3 = m.player.cam.global_position
	var to: Vector3 = target.global_position - eye
	m.player.rotation.y = atan2(-to.x, -to.z)
	m.player.set_pitch(atan2(to.y, Vector2(to.x, to.z).length()))


func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().create_timer(2.0).timeout
	m.title_menu.start_game.emit()
	await get_tree().create_timer(1.0).timeout
	m.hud.hide_menu()
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("== VAN PHONG ==")
	free_map(m, m.OFFICE_ORIGIN, m.OFFICE_SIZE, Vector3(-3.0, 0, -2.25))
	m._intro_report_task()
	aim(m, m.office_report)
	await get_tree().physics_frame
	await get_tree().physics_frame
	m.player.ray.force_raycast_update()
	print("tia trung bao cao: ", m.player.ray.get_collider() == m.office_report)
	m.hud.hide_menu()
	m._intro_boss_enter()
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("== PHONG GIAM DOC ==")
	free_map(m, m.BOSS_ORIGIN, m.BOSS_SIZE, Vector3(0, 0, 1.2))
	m.hud.hide_menu()
	m.player.teleport(m.BOSS_ORIGIN + Vector3(-0.3, 1.0, -0.2), 0.0)
	await get_tree().physics_frame
	aim(m, m.boss_paper)
	await get_tree().physics_frame
	m.player.ray.force_raycast_update()
	print("tia trung giay nghi viec: ", m.player.ray.get_collider() == m.boss_paper)
	get_tree().quit()
