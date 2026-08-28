extends SceneTree

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const ValidatorScript = preload("res://src/core/validator.gd")
const GeneratorScript = preload("res://src/core/generator.gd")

func _initialize() -> void:
	_test_valid_chain()
	_test_overlap_rejected()
	_test_disconnected_piece_rejected()
	print("FlowArrows generator smoke tests passed")
	quit()

func _test_valid_chain() -> void:
	var generated := GeneratorScript.new(42).generate_chain(4, Vector2i(8, 8))
	var board = generated.board
	var validation := ValidatorScript.new().validate(board)
	assert(validation.valid)
	assert(not validation.solution.is_empty())
	assert(generated.difficulty.solution_length == validation.solution.size())
	assert(generated.difficulty.score >= 0)
	assert(generated.difficulty.dependency_depth >= 1)
	assert(generated.difficulty.initial_legal_moves >= 1)
	assert(generated.difficulty.max_legal_moves >= generated.difficulty.min_legal_moves)
	assert(generated.difficulty.forced_ratio >= 0.0 and generated.difficulty.forced_ratio <= 1.0)
	assert(generated.difficulty.board_density > 0.0 and generated.difficulty.board_density <= 1.0)
	var multicell_count := 0
	for piece_id in board.pieces:
		var piece = board.pieces[piece_id]
		if piece.cells.size() > 1:
			multicell_count += 1
		for i in range(1, piece.cells.size()):
			var delta: Vector2i = piece.cells[i] - piece.cells[i - 1]
			assert(abs(delta.x) + abs(delta.y) == 1)
	assert(multicell_count > 0)

func _test_overlap_rejected() -> void:
	var a = PieceScript.new("A", [Vector2i(1, 1)], Vector2i.RIGHT)
	var b = PieceScript.new("B", [Vector2i(1, 1)], Vector2i.UP)
	var board = BoardScript.new(3, 3, [a, b])
	var validation := ValidatorScript.new().validate(board)
	assert(not validation.valid)
	assert(not validation.errors.is_empty())

func _test_disconnected_piece_rejected() -> void:
	var a = PieceScript.new("A", [Vector2i(0, 0), Vector2i(2, 0)], Vector2i.RIGHT)
	var board = BoardScript.new(3, 3, [a])
	var validation := ValidatorScript.new().validate(board)
	assert(not validation.valid)
