extends PanelContainer

enum GameMode { CLEAR, ENDLESS }

# Game Constants
const GRID_WIDTH: int = 20
const GRID_HEIGHT: int = 20
const BLOCK_SCENE: Resource = preload("res://Assets/Art/PolyominotrisBlockOutlineWhite.png")
# TODO: Eventually, make arrays of different pallettes to use for different levels.
const CLASSIC_COLORS: Array[Color] = [
	Color("00ffff"),
	Color("ffff00"),
	Color("800080"),
	Color("00ff00"),
	Color("ff0000"),
	Color("0000ff"),
	Color("ff7f00"),
	Color("7f7f7f"),
]
const EMPTY_COLOR: Color = Color(1, 1, 1, 0.1)
const GHOST_COLOR: Color = Color(1, 1, 1, 0.3)

# Game State
var current_mode: GameMode = GameMode.ENDLESS
var grid_data: Array = [] # 2D array (null or Color)
var grid_cells: Array = [] # 2D array (TextureRect references)
var shapes_library: Dictionary = {} # Dictionary { String: {"coords": Array[Vector2i], "size": int}}

# Game Stats
var score: int = 0
var high_score: int = 0
var lines_cleared: int = 0
var tiles_remaining: int = 0

# Active Piece State
var active_coords: Array = []
var active_pos: Vector2i = Vector2i.ZERO
var active_color: Color = Color.WHITE
var active_size: int = 0
var ghost_pos: Vector2i = Vector2i.ZERO
var next_shape_name: String = ""

# Timer
var fall_timer: Timer
var is_game_active: bool = false

# Grid containers
@onready var the_grid: GridContainer = $GameSections/MarginContainer2/TheGrid
@onready var next_piece_grid: GridContainer = $GameSections/MarginContainer/GUI/NextPolyomino
# Labels
@onready var high_score_label: Label = $GameSections/MarginContainer/GUI/Stats/HighScore
@onready var tiles_remaining_label: Label = $GameSections/MarginContainer/GUI/Stats/TilesRemainingValue
@onready var lines_cleared_label: Label = $GameSections/MarginContainer/GUI/Stats/LinesClearedValue
# Buttons
@onready var btn_new_clear: Button = $GameSections/MarginContainer/GUI/NewClearGame
@onready var btn_new_endless: Button = $GameSections/MarginContainer/GUI/NewEndlessGame
@onready var btn_pause: Button = $GameSections/MarginContainer/GUI/PauseGame
@onready var btn_quit: Button = $GameSections/MarginContainer/GUI/QuitGame


func _ready() -> void:
	load_shapes_from_scene()
	initialize_grid_visuals()
	setup_fall_timer()
	connect_signals()
	# Start in a waiting state TODO: Implement a sort of "demo" to run before the player selects the type of game they want to play.
	update_ui()


func connect_signals() -> void:
	btn_new_clear.pressed.connect(start_game.bind(GameMode.CLEAR))
	btn_new_endless.pressed.connect(start_game.bind(GameMode.ENDLESS))
	btn_pause.pressed.connect(toggle_pause)
	btn_quit.pressed.connect(get_tree().quit)


func setup_fall_timer() -> void:
	fall_timer = Timer.new()
	fall_timer.wait_time = 1.0
	fall_timer.timeout.connect(_on_fall_timer_timeout)
	add_child(fall_timer)


func initialize_grid_visuals() -> void:
	# Clear the grid
	for child: TextureRect in the_grid.get_children():
		child.queue_free()
	# Prep the grid
	the_grid.columns = GRID_WIDTH
	grid_cells.clear()
	# Fill the grid with empty cells
	for y in range(GRID_HEIGHT):
		var row_cells: Array[TextureRect] = []
		for x in range(GRID_WIDTH):
			var cell: TextureRect = TextureRect.new()
			cell.texture = BLOCK_SCENE
			cell.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			cell.modulate = EMPTY_COLOR
			# Update the row data
			the_grid.add_child(cell)
			row_cells.append(cell)
		# Update the grid data
		grid_cells.append(row_cells)


func start_game(mode: GameMode) -> void:
	current_mode = mode
	is_game_active = true
	score = 0
	lines_cleared = 0
	# Initialize data
	grid_data.clear()
	for y in range(GRID_HEIGHT):
		var row: Array = []
		row.resize(GRID_WIDTH)
		row.fill(null)
		grid_data.append(row)
	if mode == GameMode.CLEAR:
		generate_clear_mode_board()
	elif mode == GameMode.ENDLESS:
		# TODO: Implement continuously rising, repeating pattern
		pass
	# Pick first next piece then spawn
	next_shape_name = shapes_library.keys().pick_random()
	spawn_random_piece()
	fall_timer.start()
	update_ui()


func generate_clear_mode_board() -> void:
	# TODO: eventually, this will be "levels" with different pre-made patterns.
	# For now, populate the bottom 8 rows with some random blocks.
	for y in range(GRID_HEIGHT - 8, GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if randf() > 0.4: # 60% chance of a block
				grid_data[y][x] = CLASSIC_COLORS.pick_random()
	count_tiles()


func count_tiles() -> void:
	tiles_remaining = 0
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid_data[y][x] != null:
				tiles_remaining += 1 


func spawn_random_piece() -> void:
	# Move the next piece to be the active piece
	var data: Dictionary = shapes_library[next_shape_name]
	active_coords = data["coords"].duplicate()
	active_size = data["size"]
	active_color = CLASSIC_COLORS.pick_random()
	# Get the new next piece
	next_shape_name = shapes_library.keys().pick_random()
	update_next_piece_display()
	# Center the active piece at the top
	@warning_ignore("integer_division")
	active_pos = Vector2i((GRID_WIDTH / 2) - (active_size / 2), 0)
	if not is_valid_move(active_pos, active_coords):
		game_over()
	else:
		update_ghost_position()
		draw_grid()


func update_next_piece_display() -> void:
	# Clear the next display
	for child: TextureRect in next_piece_grid.get_children():
		child.queue_free()
	# Get the new next piece
	var data: Dictionary = shapes_library[next_shape_name]
	var coords: Array[Vector2i] = data["coords"]
	var shape_size: int = data["size"]
	next_piece_grid.columns = shape_size
	# Fill in the grid for the preview
	for y in range(shape_size):
		for x in range(shape_size):
			var cell: TextureRect = TextureRect.new()
			cell.texture = BLOCK_SCENE
			cell.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			cell.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			cell.custom_minimum_size = Vector2(25, 25)
			if Vector2i(x, y) in coords:
				# TODO: Figure out if this is necessary at all. I'm not sure if I want it to be a certain color or what.
				pass
			else:
				cell.modulate = EMPTY_COLOR
			next_piece_grid.add_child(cell)


func load_shapes_from_scene() -> void:
	# Instance the shapes scene to read its structure
	var shapes_scene: GridContainer = load("res://Scenes/shapes.tscn").instantiate()
	for shape_node: GridContainer in shapes_scene.get_children():
		var coords: Array[Vector2i] = []
		var columns: int = shape_node.columns
		var children: Array[Node] = shape_node.get_children() # This will be an array of TextureRects
		for i in range(children.size()):
			var child: TextureRect = children[i]
			# If the cell is visible, record its relative position
			if child.modulate.a > 0.0:
				@warning_ignore("integer_division")
				coords.append(Vector2i((i % columns), (i / columns)))
		if coords.size() > 0:
			# Store both coords and the bounding box size (columns) for rotation logic
			shapes_library[shape_node.name] = {
				"coords": coords,
				"size": columns
			}
	shapes_scene.queue_free()


func _input(event: InputEvent) -> void:
	if not is_game_active:
		return
	if event.is_action_pressed("ui_left"):
		try_move(Vector2i(-1, 0))
	elif event.is_action_pressed("ui_right"):
		try_move(Vector2i(1, 0))
	elif event.is_action_pressed("ui_down"):
		try_move(Vector2i(0, 1))
	elif event.is_action_pressed("ui_up"): # Rotation
		try_rotate()
	elif event.is_action_pressed("ui_accept"): # Hard drop
		hard_drop()


func try_move(direction: Vector2i) -> void:
	var new_pos: Vector2i = active_pos + direction
	if is_valid_move(new_pos, active_coords):
		active_pos = new_pos
		update_ghost_position()
		draw_grid()
	elif direction.y > 0:
		lock_piece()


func try_rotate() -> void:
	var new_coords: Array[Vector2i] = []
	# Rotate 90 degrees clockwise around the geometric center
	# Matrix rotation: (x, y) -> (size - 1 - y, x)
	for p: Vector2i in active_coords:
		new_coords.append(Vector2i(active_size - 1 - p.y, p.x))
	if is_valid_move(active_pos, new_coords):
		active_coords = new_coords
		update_ghost_position()
		draw_grid()


func hard_drop() -> void:
	active_pos = ghost_pos
	lock_piece()


func is_valid_move(pos: Vector2i, coords: Array[Vector2i]) -> bool:
	for p in coords:
		var grid_p: Vector2i = pos + p
		# Boundary checks
		if grid_p.x < 0 or grid_p.x >= GRID_WIDTH or grid_p.y >= GRID_HEIGHT:
			return false
		# Check existing blocks
		if grid_p.y >= 0:
			if grid_data[grid_p.y][grid_p.x] != null:
				return false
	return true


func update_ghost_position() -> void:
	var temp_y: int = active_pos.y
	while is_valid_move(Vector2i(active_pos.x, temp_y + 1), active_coords):
		temp_y += 1
	ghost_pos = Vector2i(active_pos.x, temp_y)


func lock_piece() -> void:
	for p in active_coords:
		var grid_p: Vector2i = active_pos + p
		if grid_p.y >= 0:
			grid_data[grid_p.y][grid_p.x] = active_color
	check_line_clears()
	if current_mode == GameMode.CLEAR:
		count_tiles()
		if tiles_remaining == 0:
			win_game()
			return
	spawn_random_piece()
	update_ui()


func apply_gravity(row_to_check: int) -> void:
	# Iterate from the row that was just cleared.
	for y in range(GRID_HEIGHT - (GRID_HEIGHT - row_to_check), -1, -1):
		for x in range(GRID_WIDTH):
			var current_color = grid_data[y][x]
			# If the current cell is empty, there's nothing to do.
			if current_color == null:
				continue
			# Otherwise, we need to find how far it can fall.
			var fall_to_y: int = y
			while fall_to_y + 1 < GRID_HEIGHT and grid_data[fall_to_y + 1][x] == null:
				fall_to_y += 1
			# If it can fall, then move it
			if fall_to_y != y:
				grid_data[fall_to_y][x] = current_color
				grid_data[y][x] = null


func check_line_clears() -> void:
	var cleared_rows: Array[int] = []
	# Check from the bottom to the top to find full rows
	for y in range(GRID_HEIGHT - 1, -1, -1):
		var is_full: bool = true
		for x in range(GRID_WIDTH):
			if grid_data[y][x] == null:
				is_full = false
				break
		if is_full:
			cleared_rows.append(y)
	if cleared_rows.size() > 0:
		# Update score and stats
		var rows_cleared_this_turn: int = cleared_rows.size()
		lines_cleared += rows_cleared_this_turn
		score += (rows_cleared_this_turn * 100) * rows_cleared_this_turn
		if score > high_score:
			high_score = score
		# Erase the cleared lines from the gird data
		for y in cleared_rows:
			for x in range(GRID_WIDTH):
				grid_data[y][x] = null
		# Apply gravity to settle the blocks above the lines cleared
		var lowest_line_cleared: int = cleared_rows.max()
		apply_gravity(lowest_line_cleared)


func draw_grid() -> void:
	# Clear visuals to base state
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if grid_data[y][x] != null:
				grid_cells[y][x].modulate = grid_data[y][x]
			else:
				grid_cells[y][x].modulate = EMPTY_COLOR
	# Draw the ghost piece
	for p: Vector2i in active_coords:
		var gp: Vector2i = ghost_pos + p
		if gp.y >= 0:
			grid_cells[gp.y][gp.x].modulate = GHOST_COLOR
		# Draw the active piece
		var ap: Vector2i = active_pos + p
		if ap.y >= 0:
			grid_cells[ap.y][ap.x].modulate = active_color


func update_ui() -> void:
	high_score_label.text = str(high_score)
	lines_cleared_label.text = str(lines_cleared)
	tiles_remaining_label.text = str(tiles_remaining)


func toggle_pause() -> void:
	if not is_game_active:
		return
	fall_timer.paused = !fall_timer.paused
	btn_pause.text = "Resume" if fall_timer.paused else "Pause Game"


func _on_fall_timer_timeout() -> void:
	try_move(Vector2i(0, 1))


func win_game() -> void:
	game_over()
	print("Board Cleared! You Win!")


func game_over() -> void:
	fall_timer.stop()
	print("Game Over")
