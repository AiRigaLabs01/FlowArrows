extends SceneTree

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const SolverScript = preload("res://src/core/solver.gd")

func _initialize() -> void:
	_test_single_piece()
	_test_dependency_chain()
	print("FlowArrows core smoke tests passed")
	quit()

func _test_single_piece() -> void:
	var a = PieceScript.new("A", [Vector2i(1, 1)], Vector2i.RIGHT)
	var board = BoardScript.new(3, 3, [a])
	assert(board.legal_moves() == ["A"])
	assert(SolverScript.new().solve(board) == ["A"])

func _test_dependency_chain() -> void:
	var a = PieceScript.new("A", [Vector2i(0, 1)], Vector2i.RIGHT)
	var b = PieceScript.new("B", [Vector2i(2, 1)], Vector2i.UP)
	var board = BoardScript.new(3, 3, [a, b])
	assert(board.legal_moves() == ["B"])
	assert(SolverScript.new().solve(board) == ["B", "A"])
