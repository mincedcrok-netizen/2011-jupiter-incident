extends Node
## Global publish/subscribe bus. Systems communicate through events instead of
## calling each other directly, so networking (Phase 7) can later hook the same
## events for replication. See docs/ARCHITECTURE.md.
##
## Ownership: shared (local to every peer; authoritative events are published
## by whoever owns the originating system).

## Fires for every published event; useful for debugging and test capture.
signal event_published(event_type: StringName, payload: Dictionary)

var _subscribers: Dictionary = {}  # StringName -> Array[Callable]  (transient)
var _permanent: Dictionary = {}    # StringName -> Array[Callable]  (engine systems)


## `permanent` is for game systems that live as long as the game; clear() leaves them
## alone so tests (and scene teardown) can drop ad-hoc listeners safely.
func subscribe(event_type: StringName, handler: Callable, permanent: bool = false) -> void:
	if not handler.is_valid():
		push_warning("EventBus.subscribe: invalid handler for '%s'" % event_type)
		return
	var store: Dictionary = _permanent if permanent else _subscribers
	var list: Array = store.get(event_type, [])
	if handler in list:
		return
	list.append(handler)
	store[event_type] = list


func unsubscribe(event_type: StringName, handler: Callable) -> void:
	for store: Dictionary in [_subscribers, _permanent]:
		(store.get(event_type, []) as Array).erase(handler)


func publish(event_type: StringName, payload: Dictionary = {}) -> void:
	event_published.emit(event_type, payload)
	# Iterate copies so handlers may (un)subscribe while handling.
	for store: Dictionary in [_permanent, _subscribers]:
		var list: Array = store.get(event_type, [])
		for handler: Callable in list.duplicate():
			if handler.is_valid():
				handler.call(payload)
			else:
				list.erase(handler)


func subscriber_count(event_type: StringName) -> int:
	return (_subscribers.get(event_type, []) as Array).size() + (_permanent.get(event_type, []) as Array).size()


## Drops transient subscriptions only.
func clear() -> void:
	_subscribers.clear()
