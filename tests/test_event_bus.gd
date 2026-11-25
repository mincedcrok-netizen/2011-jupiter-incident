extends TestCase

var _hits: Array = []


func _on_a(payload: Dictionary) -> void:
	_hits.append(payload)


func before_each() -> void:
	EventBus.clear()
	_hits.clear()


func test_subscribe_publish_delivers_payload() -> void:
	EventBus.subscribe(&"x", _on_a)
	EventBus.publish(&"x", {"n": 1})
	eq(_hits.size(), 1, "handler called once")
	eq(_hits[0]["n"], 1, "payload delivered")


func test_duplicate_subscribe_ignored() -> void:
	EventBus.subscribe(&"x", _on_a)
	EventBus.subscribe(&"x", _on_a)
	eq(EventBus.subscriber_count(&"x"), 1, "one subscription")


func test_unsubscribe_stops_delivery() -> void:
	EventBus.subscribe(&"x", _on_a)
	EventBus.unsubscribe(&"x", _on_a)
	EventBus.publish(&"x")
	eq(_hits.size(), 0, "no delivery after unsubscribe")


func test_publish_without_subscribers_is_safe() -> void:
	EventBus.publish(&"nobody_listens", {"a": 1})
	ok(true, "no crash")


func test_invalid_handler_rejected() -> void:
	EventBus.subscribe(&"x", Callable())
	eq(EventBus.subscriber_count(&"x"), 0, "invalid callable not stored")


class Listener extends Object:
	var hits := 0

	func on_event(_p: Dictionary) -> void:
		hits += 1


func test_freed_subscriber_is_pruned_not_called() -> void:
	var l := Listener.new()
	EventBus.subscribe(&"x", l.on_event)
	eq(EventBus.subscriber_count(&"x"), 1, "subscribed")
	l.free()
	EventBus.publish(&"x")  # must not crash on the dead handler
	eq(EventBus.subscriber_count(&"x"), 0, "dead handler pruned on publish")


func test_clear_keeps_permanent_subscriptions() -> void:
	var counter := {"p": 0, "t": 0}
	EventBus.subscribe(&"perm_test", func(_p: Dictionary) -> void: counter["p"] += 1, true)
	EventBus.subscribe(&"perm_test", func(_p: Dictionary) -> void: counter["t"] += 1)
	EventBus.clear()
	EventBus.publish(&"perm_test")
	eq(counter["p"], 1, "permanent handler survived clear()")
	eq(counter["t"], 0, "transient handler dropped by clear()")
