extends Node

func _ready() -> void:
	_test_single_piece()
	_test_dependency_chain()
	print("FlowArrows core smoke tests passed")
	get_tree().quit()

func _test_single_piece() -> void:
	var a := FlowPiece.new("A", [Vector2i(1, 1)], Vector2i.RIGHT)
	var board := BoardState.new(3, 3, [a])
	assert(board.legal_moves() == ["A"])
	assert(FlowSolver.new().solve(board) == ["A"])

func _test_dependency_chain() -> void:
	# A exits right but B blocks its row. B can leave upward first.
	var a := FlowPiece.new("A", [Vector2i(0, 1)], Vector2i.RIGHT)
	var b := FlowPiece.new("B", [Vector2i(2, 1)], Vector2i.UP)
	var board := BoardState.new(3, 3, [a, b])
	assert(board.legal_moves() == ["B"])
	assert(FlowSolver.new().solve(board) == ["B", "A"])
