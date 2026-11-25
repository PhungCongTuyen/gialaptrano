extends Node
## Kiểm tra va chạm: bắn tia từ trên xuống đống gạch / bàn ghế / đụn rác, độ cao chạm phải khớp hình.
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var found: Dictionary = {}
	for b in m.find_children("*", "StaticBody3D", true, false):
		var owner_n: Node = b.get_parent()
		var nm: String = String(owner_n.name)
		var kind: String = ""
		if owner_n.has_meta("pile"):
			kind = "dun_" + str(owner_n.get_meta("pile"))
		elif b.has_meta("pile"):
			kind = "dun_" + str(b.get_meta("pile"))
		elif b.has_meta("model"):
			kind = str(b.get_meta("model"))
		if kind == "" or found.get(kind, 0) >= 2:
			continue
		found[kind] = found.get(kind, 0) + 1
		var at: Vector3 = (b as Node3D).global_position
		if kind.begins_with("ghe") or kind.begins_with("ban"):
			at += Vector3(0.06, 0, 0.03)  # tránh lỗ / rãnh
		var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3(0, 2, 0), at + Vector3(0, -1, 0))
		var hit: Dictionary = space.intersect_ray(q)
		print("%s tại (%.1f, %.1f): chạm ở y=%.3f, vật=%s" % [kind, at.x, at.z, (hit.get("position", Vector3(0, -9, 0)) as Vector3).y, hit.get("collider")])
	get_tree().quit()
