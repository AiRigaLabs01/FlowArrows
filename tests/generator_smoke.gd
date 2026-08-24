extends SceneTree

const PieceScript = preload("res://src/core/piece.gd")
const BoardScript = preload("res://src/core/board_state.gd")
const ValidatorScript = preload("res://src/core/validator.gd")
const GeneratorScript = preload("res://src/core/generator.gd")

func _initialize() -> void:
	_test_valid_chain()
	_test_overlap_rejected()
	print("FlowArrows generator smoke tests passed")
	quit()

func _test_valid_chain() -> void:
	var generated := GeneratorScript.new(42).generate_chain(4, Vector2i(8, 8))
	var board = generated.board
	var validation := ValidatorScript.new().validate(board)
	assert(validation.valid)
	assert(not validation.solution.is_empty())
	assert(generated.difficulty.solution_length == validation.solution.size())

func _test_overlap_rejected() -> void:
	var a = PieceScript.new("A", [Vector2i(1, 1)], Vector2i.RIGHT)
	var b = PieceScript.new("B", [Vector2i(1, 1)], Vector2i.UP)
	var board = BoardScript.new(3, 3, [a, b])
	var validation := ValidatorScript.new().validate(board)
	assert(not validation.valid)
	assert(not validation.errors.is_empty())
