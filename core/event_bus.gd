extends Node
## Global publish/subscribe bus. Systems communicate through events instead of
## calling each other directly, so networking (Phase 7) can later hook the same
## events for replication. See docs/ARCHITECTURE.md.
##
## Ownership: shared (local to every peer; authoritative events are published
## by whoever owns the originating system).

## Fires for every published event; useful for debugging and test capture.
signal event_published(event_type: StringName, payload: Dictionary)

var _subscribers: Dictionary = {}  # StringName -> Array[Callable]


func subscribe(event_type: StringName, handler: Callable) -> void:
	if not handler.is_valid():
		push_warning("EventBus.subscribe: invalid handler for '%s'" % event_type)
		return
	var list: Array = _subscribers.get(event_type, [])
	if handler in list:
		return
	list.append(handler)
	_subscribers[event_type] = list


func unsubscribe(event_type: StringName, handler: Callable) -> void:
	var list: Array = _subscribers.get(event_type, [])
	list.erase(handler)


func publish(event_type: StringName, payload: Dictionary = {}) -> void:
	event_published.emit(event_type, payload)
	var list: Array = _subscribers.get(event_type, [])
	# Iterate a copy so handlers may (un)subscribe while handling.
	for handler: Callable in list.duplicate():
		if handler.is_valid():
			handler.call(payload)
		else:
			list.erase(handler)


func subscriber_count(event_type: StringName) -> int:
	return (_subscribers.get(event_type, []) as Array).size()


func clear() -> void:
	_subscribers.clear()
