class_name TestCase
extends RefCounted
## Minimal headless test base. Methods named test_* are run by run_tests.gd.
## Override before_each()/after_each() for setup/teardown (may be coroutines).

var failures: Array[String] = []
var checks: int = 0
var tree: SceneTree


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func ok(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func eq(actual: Variant, expected: Variant, message: String) -> void:
	checks += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
