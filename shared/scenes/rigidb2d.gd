# Just a short "extension" for the RigidBody2D so it's state can be reset.
# To do that, the custom integrator must be used

extends RigidBody2D

signal performed_reset

var _reset_to: Dictionary = {
	"reset": false,
	"transform": Transform2D(),
	"emit": false
}

func _process(_dt: float) -> void:
	if (_reset_to.emit):
		emit_signal("performed_reset")
		_reset_to.emit = false


func _integrate_forces(state: Physics2DDirectBodyState) -> void:
	if (_reset_to.reset):
		_reset_to.reset = false
		state.set_transform(_reset_to.transform)
		state.sleeping = false
		state.angular_velocity = 0.0
		state.linear_velocity = Vector2()
		
		_reset_to.emit = true
	
	# Integrate gravity
	state.linear_velocity.y += 98.0 * state.get_step()

func reset_to(t: Transform2D) -> void:
	_reset_to.reset = true
	_reset_to.transform = t

