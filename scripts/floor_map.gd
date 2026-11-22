# ---------------------------------------------------------------------------
# floor_map.gd — Vista del grafo del piso actual (START → BOSS).
# Dibuja nodos por profundidad BFS, resalta la sala actual y permite elegir
# solo las rutas válidas (next_options) haciendo clic en el nodo.
# ---------------------------------------------------------------------------
extends Control

const VISUALS = preload("res://scripts/visual_assets.gd")

signal room_chosen(room_id: int)

var run: RunManager
var selectable: Dictionary = {} # room_id -> true
var positions: Dictionary = {} # room_id -> Vector2
var node_radius := 18.0

func setup(run_manager: RunManager, options: Array) -> void:
	run = run_manager
	selectable.clear()
	for option in options:
		selectable[option.room_id] = true
	custom_minimum_size = Vector2(900, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	queue_redraw()

func _layout() -> void:
	positions.clear()
	if run == null or run.floor_map.is_empty():
		return
	var depth: Dictionary = {}
	var queue: Array[int] = [0]
	depth[0] = 0
	while not queue.is_empty():
		var id: int = queue.pop_front()
		var room: RoomData = run.room(id)
		if room == null:
			continue
		for nxt in room.connections:
			if not depth.has(nxt):
				depth[nxt] = int(depth[id]) + 1
				queue.append(nxt)
	var columns: Dictionary = {} # depth -> Array[int]
	for id in depth.keys():
		var d: int = depth[id]
		if not columns.has(d):
			columns[d] = []
		columns[d].append(id)
	var max_depth := 0
	for d in columns.keys():
		max_depth = maxi(max_depth, int(d))
	var width := maxf(custom_minimum_size.x, 200.0)
	var height := maxf(custom_minimum_size.y, 120.0)
	for d in columns.keys():
		var ids: Array = columns[d]
		ids.sort()
		var x := 40.0 + float(d) * ((width - 80.0) / maxf(1.0, float(max_depth)))
		for i in range(ids.size()):
			var y := height * (float(i) + 1.0) / float(ids.size() + 1)
			positions[ids[i]] = Vector2(x, y)

func _draw() -> void:
	if run == null:
		return
	# Enlaces.
	for room in run.floor_map:
		if not positions.has(room.room_id):
			continue
		var from: Vector2 = positions[room.room_id]
		for nxt in room.connections:
			if not positions.has(nxt):
				continue
			var color := Color("6a5f8a")
			if room.completed or run.room(nxt).visited:
				color = Color("9ad0b0")
			draw_line(from, positions[nxt], color, 2.0, true)
	# Nodos.
	for room in run.floor_map:
		if not positions.has(room.room_id):
			continue
		var pos: Vector2 = positions[room.room_id]
		var fill := Color("2a2540")
		var border := Color("b49adc")
		if room.room_id == run.current_room_id:
			fill = Color("4a3a20")
			border = Color("ffd166")
		elif selectable.has(room.room_id):
			fill = Color("1f3d4d")
			border = Color("4cc9f0")
		elif room.completed or room.visited:
			fill = Color("243528")
			border = Color("7fbf8a")
		draw_circle(pos, node_radius, fill)
		draw_arc(pos, node_radius, 0.0, TAU, 32, border, 2.5, true)
		var icon := VISUALS.room_icon(room.room_type)
		if icon != null:
			var icon_size := Vector2(22, 22)
			draw_texture_rect(icon, Rect2(pos - icon_size * 0.5, icon_size), false)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var local: Vector2 = (event as InputEventMouseButton).position
	for room_id in selectable.keys():
		if not positions.has(room_id):
			continue
		if local.distance_to(positions[room_id]) <= node_radius + 6.0:
			room_chosen.emit(int(room_id))
			accept_event()
			return
