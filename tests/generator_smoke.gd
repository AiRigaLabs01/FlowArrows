extends Node

func _ready() -> void:
	_test_valid_chain()
	_test_overlap_rejected()
	print("FlowArrows generator smoke tests passed")
	get_tree().quit()

func _test_valid_chain() -> void:
	var generated := FlowGenerator.new(42).generate_chain(4, Vector2i(8, 8))
	var board: BoardState = generated.board
	var validation := FlowValidator.new().validate(board)
	assert(validation.valid)
	assert(not validation.solution.is_empty())
	assert(generated.difficulty.solution_length == validation.solution.size())

func _test_overlap_rejected() -> void:
	var a := FlowPiece.new("A", [Vector2i(1, 1)], Vector2i.RIGHT)
	var b := FlowPiece.new("B", [Vector2i(1, 1)], Vector2i.UP)
	var board := BoardState.new(3, 3, [a, b])
	var validation := FlowValidator.new().validate(board)
	assert(not validation.valid)
	assert(not validation.errors.is_empty())
