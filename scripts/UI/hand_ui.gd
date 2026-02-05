extends Control

const MAX_HAND_SIZE: int = 5
const FAN_RADIUS: float = 220.0
const FAN_SPREAD_DEG: float = 20.0
const HOVER_RAISE_Y: float = 36.0
const HAND_SCALE: float = 0.2548
const HOVER_SCALE: float = 1.2
const LAYOUT_TWEEN_TIME: float = 0.2
const ITEM_CATALOG_DEFAULT_PATH: String = "res://data/item_catalog_default.tres"
const STATE_IN_HAND: int = 0
const STATE_DRAGGING: int = 1

@export var item_card_scene: PackedScene
@export var item_catalog: ItemCatalog
@export var equip_zone_path: NodePath

var _cards: Array[Control] = []
var _base_pose: Dictionary = {}
var _dragging_card: Control = null
var _equip_zone: HeroEquipZone = null
var _current_items: Array[String] = []

func _ready() -> void:
	if equip_zone_path != NodePath():
		_equip_zone = get_node_or_null(equip_zone_path) as HeroEquipZone

	if RunState:
		RunState.hand_changed.connect(_on_hand_changed)
		_on_hand_changed(RunState.get_hand_items())

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cards()

func _on_hand_changed(items: Array[String]) -> void:
	_sync_hand(items)

func _sync_hand(items: Array[String]) -> void:
	if _cards.is_empty():
		_rebuild_cards(items)
		return

	if _is_append_only(items):
		_add_card(items[items.size() - 1], items.size())
		_current_items = items.duplicate()
		return

	if _is_fifo_replace(items):
		_remove_first_card()
		_reflow_existing_cards()
		_add_card(items[items.size() - 1], items.size())
		_current_items = items.duplicate()
		return

	_rebuild_cards(items)

func _rebuild_cards(items: Array[String]) -> void:
	for card in _cards:
		if card != null:
			card.queue_free()
	_cards.clear()
	_base_pose.clear()
	_dragging_card = null
	_current_items = items.duplicate()

	if item_card_scene == null:
		return

	var catalog := _get_item_catalog()

	for item_id in items:
		var card := _create_card_for_item(item_id, catalog)
		if card != null:
			_cards.append(card)

	_layout_cards()

func _layout_cards() -> void:
	var n := _cards.size()
	if n == 0:
		return

	var center := Vector2(size.x * 0.5, size.y * 0.5)

	for i in range(n):
		var card := _cards[i]
		if card == null:
			continue
		if card == _dragging_card:
			continue

		var pose := _get_pose_for_index(i, n, center, card.size)
		_base_pose[card] = pose
		_apply_card_pose(card, pose["pos"], pose["rot"], Vector2.ONE * HAND_SCALE)

func _get_pose_for_index(index: int, count: int, center: Vector2, card_size: Vector2) -> Dictionary:
	var t := 0.5
	if count > 1:
		t = float(index) / float(count - 1)
	var angle_deg := -FAN_SPREAD_DEG * 0.5 + FAN_SPREAD_DEG * t
	var spacing: float = max(110.0, card_size.x * HAND_SCALE * 0.9)
	var total_width: float = spacing * float(max(0, count - 1))
	var x: float = center.x - (total_width * 0.5) + (float(index) * spacing)
	var y: float = center.y
	var scaled_size := card_size * HAND_SCALE
	var pos: Vector2 = Vector2(x, y) - (scaled_size * 0.5)
	var rot: float = 0.0
	return {"pos": pos, "rot": rot}

func _create_card_for_item(item_id: String, catalog: ItemCatalog) -> Control:
	if item_card_scene == null:
		return null
	var card := item_card_scene.instantiate() as Control
	if card == null:
		return null
	add_child(card)
	card.size = card.custom_minimum_size
	card.scale = Vector2.ONE * HAND_SCALE

	if card.has_method("set_state"):
		card.call("set_state", STATE_IN_HAND)
	card.set("item_id", item_id)

	var def: ItemCardDefinition = null
	if catalog != null:
		def = catalog.get_item_by_id(item_id)
	if def != null and card.has_method("setup"):
		card.call("setup", def)

	if card.has_signal("hover_entered"):
		card.connect("hover_entered", Callable(self, "_on_card_hover_entered"))
	if card.has_signal("hover_exited"):
		card.connect("hover_exited", Callable(self, "_on_card_hover_exited"))
	if card.has_signal("drag_started"):
		card.connect("drag_started", Callable(self, "_on_card_drag_started"))
	if card.has_signal("drag_released"):
		card.connect("drag_released", Callable(self, "_on_card_drag_released"))

	return card

func _add_card(item_id: String, total_count: int) -> void:
	var catalog := _get_item_catalog()
	var card := _create_card_for_item(item_id, catalog)
	if card == null:
		return
	_cards.append(card)
	_reflow_existing_cards()

func _reflow_existing_cards() -> void:
	var n := _cards.size()
	if n == 0:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	for i in range(n):
		var card := _cards[i]
		if card == null or card == _dragging_card:
			continue
		var pose := _get_pose_for_index(i, n, center, card.size)
		_base_pose[card] = pose
		_apply_card_pose(card, pose["pos"], pose["rot"], Vector2.ONE * HAND_SCALE)

func _remove_first_card() -> void:
	if _cards.is_empty():
		return
	var first := _cards[0]
	_cards.remove_at(0)
	if first != null:
		_base_pose.erase(first)
		first.queue_free()
	_reflow_existing_cards()

func _is_append_only(items: Array[String]) -> bool:
	if items.size() != _current_items.size() + 1:
		return false
	for i in range(_current_items.size()):
		if items[i] != _current_items[i]:
			return false
	return true

func _is_fifo_replace(items: Array[String]) -> bool:
	if items.size() != _current_items.size():
		return false
	if _current_items.size() == 0:
		return false
	for i in range(items.size() - 1):
		if items[i] != _current_items[i + 1]:
			return false
	return true

func _tween_card_to(card: Control, pos: Vector2, rot: float, scale: Vector2) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", pos, LAYOUT_TWEEN_TIME)
	tween.tween_property(card, "rotation", rot, LAYOUT_TWEEN_TIME)
	tween.tween_property(card, "scale", scale, LAYOUT_TWEEN_TIME)

func _apply_card_pose(card: Control, pos: Vector2, rot: float, scale: Vector2) -> void:
	card.position = pos
	card.rotation = rot
	card.scale = scale

func _on_card_hover_entered(card: Control) -> void:
	if card == null or card == _dragging_card:
		return
	_reflow_existing_cards()
	if not _base_pose.has(card):
		return
	var pose: Dictionary = _base_pose[card] as Dictionary
	var base_pos: Vector2 = pose.get("pos", Vector2.ZERO) as Vector2
	var base_rot: float = float(pose.get("rot", 0.0))
	card.z_index = 1000
	var base_scaled := card.size * HAND_SCALE
	var hover_scaled := card.size * HAND_SCALE * HOVER_SCALE
	var base_center := base_pos + (base_scaled * 0.5)
	var hover_pos := base_center - (hover_scaled * 0.5) + Vector2(0.0, -HOVER_RAISE_Y)
	_tween_card_to(card, hover_pos, base_rot, Vector2.ONE * HAND_SCALE * HOVER_SCALE)

func _on_card_hover_exited(card: Control) -> void:
	if card == null or card == _dragging_card:
		return
	_return_card_to_hand(card)
	_reflow_existing_cards()

func _on_card_drag_started(card: Control) -> void:
	if card == null:
		return
	_dragging_card = card
	card.z_index = 2000
	if card.has_method("set_state"):
		card.call("set_state", STATE_DRAGGING)

func _on_card_drag_released(card: Control, global_pos: Vector2) -> void:
	if card == null:
		return

	var item_id := String(card.get("item_id"))

	var accepted := false
	if _equip_zone != null and _equip_zone.is_point_in_zone(global_pos):
		if _equip_zone.can_accept(item_id):
			var slot_index := _equip_zone.accept(item_id)
			RunState.equip_item_from_hand(item_id, slot_index)
			accepted = true
	if not accepted and _equip_zone != null and _is_point_over_hero(global_pos):
		if _equip_zone.can_accept(item_id):
			var slot_index := _equip_zone.accept(item_id)
			RunState.equip_item_from_hand(item_id, slot_index)
			accepted = true

	if not accepted:
		_return_card_to_hand(card)

	_dragging_card = null
	if card.has_method("set_state"):
		card.call("set_state", STATE_IN_HAND)

func _return_card_to_hand(card: Control) -> void:
	if card == null:
		return
	if not _base_pose.has(card):
		return
	var pose: Dictionary = _base_pose[card] as Dictionary
	var base_pos: Vector2 = pose.get("pos", Vector2.ZERO) as Vector2
	var base_rot: float = float(pose.get("rot", 0.0))
	card.z_index = 0
	_tween_card_to(card, base_pos, base_rot, Vector2.ONE * HAND_SCALE)

func _is_point_over_hero(global_pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("card_view"):
		if not (node is CardView):
			continue
		var card := node as CardView
		if card.card_id != "th":
			continue
		if card.get_global_rect().has_point(global_pos):
			return true
	return false

func _get_item_catalog() -> ItemCatalog:
	if item_catalog != null:
		return item_catalog
	item_catalog = load(ITEM_CATALOG_DEFAULT_PATH) as ItemCatalog
	return item_catalog
