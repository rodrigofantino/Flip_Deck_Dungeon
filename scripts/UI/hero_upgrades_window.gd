extends Control
class_name HeroUpgradesWindow

signal closed

@onready var hero_list_label: Label = $Panel/HBox/Left/HeroListLabel
@onready var hero_list: ItemList = $Panel/HBox/Left/HeroList
@onready var title_label: Label = $Panel/HBox/Right/Header/TitleLabel
@onready var hero_name_label: Label = $Panel/HBox/Right/Header/HeroNameLabel
@onready var close_button: Button = $Panel/HBox/Right/Header/CloseButton
@onready var level_label: Label = $Panel/HBox/Right/Details/LevelLabel
@onready var xp_label: Label = $Panel/HBox/Right/Details/XpLabel
@onready var points_label: Label = $Panel/HBox/Right/Details/PointsLabel
@onready var stats_label: Label = $Panel/HBox/Right/Stats/StatsLabel
@onready var stats_list: VBoxContainer = $Panel/HBox/Right/Stats/StatsScroll/StatsList

var _hero_ids: Array[StringName] = []
var _selected_hero_id: StringName = &""
var _stat_rows: Dictionary = {}

func _ready() -> void:
	if hero_list == null:
		return
	_refresh_static_texts()
	hero_list.item_selected.connect(_on_hero_selected)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	_build_stats_rows()
	_refresh_hero_list()
	if _hero_ids.size() > 0:
		hero_list.select(0)
		_on_hero_selected(0)

func refresh_window() -> void:
	_refresh_static_texts()
	_build_stats_rows()
	_refresh_hero_list()
	if _hero_ids.size() > 0:
		if hero_list.get_selected_items().is_empty():
			hero_list.select(0)
			_on_hero_selected(0)
		else:
			var idx: int = hero_list.get_selected_items()[0]
			_on_hero_selected(idx)

func _refresh_static_texts() -> void:
	if hero_list_label:
		hero_list_label.text = tr("HERO_UPGRADES_OWNED_HEROES")
	if title_label:
		title_label.text = tr("HERO_UPGRADES_TITLE")
	if close_button:
		close_button.text = tr("HERO_UPGRADES_CLOSE")
	if stats_label:
		stats_label.text = tr("HERO_UPGRADES_STATS")

func show_for_hero(hero_id: StringName) -> void:
	refresh_window()
	if hero_id == &"":
		return
	var idx := _get_hero_index(hero_id)
	if idx >= 0:
		hero_list.select(idx)
		_on_hero_selected(idx)

func _refresh_hero_list() -> void:
	_hero_ids.clear()
	hero_list.clear()
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return
	var seen: Dictionary = {}
	for hero_id: StringName in profile.owned_heroes:
		var id_str: String = String(hero_id)
		if id_str == "hero":
			id_str = "knight_aprentice"
		var key: StringName = StringName(id_str)
		if seen.has(key):
			continue
		seen[key] = true
		_hero_ids.append(key)
		var display_name: String = _get_hero_display_name(key)
		var progression: HeroProgression = profile.get_or_create_progression(key)
		var unspent: int = progression.unspent_points
		if unspent > 0:
			display_name += " (+" + str(unspent) + ")"
		hero_list.add_item(display_name)

func _build_stats_rows() -> void:
	if stats_list == null:
		return
	for child: Node in stats_list.get_children():
		child.queue_free()
	_stat_rows.clear()
	for stat: int in HeroUpgradeStats.get_all_stats():
		var row: HBoxContainer = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_list.add_child(row)

		var name_label: Label = Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text = tr(HeroUpgradeStats.get_stat_name(stat))
		name_label.tooltip_text = tr(HeroUpgradeStats.get_stat_desc(stat))
		row.add_child(name_label)

		var value_label: Label = Label.new()
		value_label.custom_minimum_size = Vector2(90.0, 0.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)

		var points_label: Label = Label.new()
		points_label.custom_minimum_size = Vector2(70.0, 0.0)
		points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(points_label)

		var minus_button: Button = Button.new()
		minus_button.text = "-"
		minus_button.custom_minimum_size = Vector2(28.0, 0.0)
		minus_button.pressed.connect(_on_stat_minus_pressed.bind(stat))
		row.add_child(minus_button)

		var plus_button: Button = Button.new()
		plus_button.text = "+"
		plus_button.custom_minimum_size = Vector2(28.0, 0.0)
		plus_button.pressed.connect(_on_stat_plus_pressed.bind(stat))
		row.add_child(plus_button)

		_stat_rows[stat] = {
			"value_label": value_label,
			"points_label": points_label,
			"minus_button": minus_button,
			"plus_button": plus_button
		}

func _on_hero_selected(index: int) -> void:
	if index < 0 or index >= _hero_ids.size():
		return
	_selected_hero_id = _hero_ids[index]
	_refresh_selected_hero()

func _refresh_selected_hero() -> void:
	if _selected_hero_id == &"":
		return
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return
	var progression: HeroProgression = profile.get_or_create_progression(_selected_hero_id)

	hero_name_label.text = _get_hero_display_name(_selected_hero_id)
	level_label.text = tr("HERO_UPGRADES_LEVEL").format({
		"value": progression.level
	})
	var xp_required: int = ProfileService.xp_required_for_level(progression.level)
	xp_label.text = tr("HERO_UPGRADES_XP").format({
		"current": progression.xp,
		"total": xp_required
	})
	points_label.text = tr("HERO_UPGRADES_UNSPENT").format({
		"value": progression.unspent_points
	})

	var can_spend: bool = progression.can_spend_point()
	for stat: int in HeroUpgradeStats.get_all_stats():
		var row_data: Dictionary = _stat_rows.get(stat, {})
		if row_data.is_empty():
			continue
		var value_label: Label = row_data.get("value_label", null)
		var points_label_row: Label = row_data.get("points_label", null)
		var minus_button: Button = row_data.get("minus_button", null)
		var plus_button: Button = row_data.get("plus_button", null)
		if value_label == null or points_label_row == null or plus_button == null or minus_button == null:
			continue
		var points: int = progression.get_points_in_stat(stat)
		points_label_row.text = tr("HERO_UPGRADES_POINTS").format({
			"value": points
		})
		if HeroUpgradeStats.is_percent_stat(stat):
			var bonus: float = float(points) * HeroUpgradeStats.get_per_point_percent(stat)
			var cap: float = HeroUpgradeStats.get_percent_cap(stat)
			if cap >= 0.0:
				bonus = min(bonus, cap)
			var display_percent: int = int(round(bonus * 100.0))
			value_label.text = "%d%%" % display_percent
		else:
			var flat: int = points * HeroUpgradeStats.get_per_point_flat(stat)
			value_label.text = "%d" % flat
		plus_button.disabled = not can_spend
		minus_button.disabled = not progression.can_refund_point(stat)

func _on_stat_plus_pressed(stat: int) -> void:
	if _selected_hero_id == &"":
		return
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return
	var progression: HeroProgression = profile.get_or_create_progression(_selected_hero_id)
	if progression.spend_point(stat):
		ProfileService.save_profile(profile)
		_refresh_selected_hero()
		_refresh_hero_list()

func _on_stat_minus_pressed(stat: int) -> void:
	if _selected_hero_id == &"":
		return
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return
	var progression: HeroProgression = profile.get_or_create_progression(_selected_hero_id)
	if progression.refund_point(stat):
		ProfileService.save_profile(profile)
		_refresh_selected_hero()
		_refresh_hero_list()

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _get_hero_display_name(hero_id: StringName) -> String:
	var id_str: String = String(hero_id)
	var def: CardDefinition = CardDatabase.get_definition(id_str)
	if def != null and not def.display_name.is_empty():
		return def.display_name
	return id_str

func _get_hero_index(hero_id: StringName) -> int:
	for i in range(_hero_ids.size()):
		if _hero_ids[i] == hero_id:
			return i
	return -1
