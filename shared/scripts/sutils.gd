# The objective of this script file is to hold some utilities meant to be used by the various
# demos in the project.

extends Reference
class_name SharedUtils


# This is just a "shortcut" function meant to perform signal connection. The
# main objective here is to avoid having to write multiple times the tag to
# ignore the warning telling about non used return value
static func connector(emitter: Object, signal_name: String, handler_obj: Object, handler_func: String, payload: Array = []) -> void:
	# warning-ignore:return_value_discarded
	emitter.connect(signal_name, handler_obj, handler_func, payload)

