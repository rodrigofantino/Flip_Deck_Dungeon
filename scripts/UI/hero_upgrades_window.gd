extends Control
class_name HeroUpgradesWindow

signal closed
signal upgrades_changed(hero_id: StringName)
const RESPEC_COST_GOLD: int = 100

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
@onready var dimmer: ColorRect = $Dimmer

var _hero_ids: Array[StringName] = []
var _selected_hero_id: StringName = &""
var _stat_rows: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if close_button:
		close_button.process_mode = Node.PROCESS_MODE_ALWAYS
	if dimmer:
		dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
		dimmer.gui_input.connect(_on_dimmer_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP
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
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	_apply_upgrades_to_run_if_active()
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

	var display_stats := _get_display_stats(_selected_hero_id, progression)
	var can_spend: bool = progression.can_spend_point()
	var in_run: bool = _is_run_context()
	var can_pay_respec: bool = SaveSystem.get_persistent_gold() >= RESPEC_COST_GOLD
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
		var display_value := _get_display_stat_value(stat, display_stats)
		if HeroUpgradeStats.is_percent_stat(stat):
			value_label.text = "%d%%" % int(round(display_value * 100.0))
		else:
			value_label.text = "%d" % int(round(display_value))
		plus_button.disabled = not can_spend
		minus_button.disabled = in_run or not can_pay_respec or not progression.can_refund_point(stat)
		if in_run:
			minus_button.tooltip_text = "Respec disabled during run."
		else:
			minus_button.tooltip_text = "Respec cost: %dg" % RESPEC_COST_GOLD

func _on_stat_plus_pressed(stat: int) -> void:
	if _selected_hero_id == &"":
		return
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return
	var progression: HeroProgression = profile.get_or_create_progression(_selected_hero_id)
	if progression.spend_point(stat):
		ProfileService.save_profile(profile)
		_apply_upgrades_to_run_if_active()
		_refresh_selected_hero()
		_refresh_hero_list()
		upgrades_changed.emit(_selected_hero_id)

func _on_stat_minus_pressed(stat: int) -> void:
	if _selected_hero_id == &"":
		return
	if _is_run_context():
		return
	if SaveSystem.get_persistent_gold() < RESPEC_COST_GOLD:
		return
	var profile: PlayerProfile = ProfileService.get_profile()
	if profile == null:
		return
	var progression: HeroProgression = profile.get_or_create_progression(_selected_hero_id)
	if progression.refund_point(stat):
		SaveSystem.add_persistent_gold(-RESPEC_COST_GOLD)
		ProfileService.save_profile(profile)
		_apply_upgrades_to_run_if_active()
		_refresh_selected_hero()
		_refresh_hero_list()
		upgrades_changed.emit(_selected_hero_id)

func _on_close_pressed() -> void:
	visible = false
	closed.emit()

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		var vp := get_viewport()
		if vp:
			vp.set_input_as_handled()

func _apply_upgrades_to_run_if_active() -> void:
	if _selected_hero_id == &"":
		return
	if RunState == null:
		return
	var hero := RunState.get_card("th")
	if hero.is_empty():
		return
	var def_id := String(hero.get("definition", ""))
	if def_id != String(_selected_hero_id):
		return
	if RunState.has_method("refresh_hero_upgrades"):
		RunState.call("refresh_hero_upgrades")

func _get_display_stats(hero_id: StringName, progression: HeroProgression) -> Dictionary:
	var run_stats := _get_run_display_stats(hero_id)
	if not run_stats.is_empty():
		return run_stats
	return _get_definition_display_stats(hero_id, progression)

func _get_run_display_stats(hero_id: StringName) -> Dictionary:
	if RunState == null:
		return {}
	var hero := RunState.get_card("th")
	if hero.is_empty():
		return {}
	var def_id := String(hero.get("definition", ""))
	if def_id != String(hero_id):
		return {}
	return {
		"max_hp": int(hero.get("max_hp", 0)),
		"damage": int(hero.get("damage", 0)),
		"armour": int(hero.get("armour", 0)),
		"initiative": int(hero.get("initiative", 0)),
		"regen": int(hero.get("regen", 0)),
		"block_chance": float(hero.get("block_chance", 0.0)),
		"lifesteal_pct": float(hero.get("lifesteal_pct", 0.0)),
		"evasion": float(hero.get("evasion", 0.0)),
		"healing_power": float(hero.get("healing_power", 0.0)),
		"status_resist": float(hero.get("status_resist", 0.0)),
		"gold_gain": float(hero.get("gold_gain", 0.0)),
		"loot_chance": float(hero.get("loot_chance", 0.0)),
		"rarity_chance": float(hero.get("rarity_chance", 0.0))
	}

func _get_definition_display_stats(hero_id: StringName, progression: HeroProgression) -> Dictionary:
	var def: CardDefinition = CardDatabase.get_definition(String(hero_id)) as CardDefinition
	if def == null:
		return {}
	var level := 1
	if progression != null:
		level = max(1, progression.level)
	var upgrade_level := _get_collection_upgrade_level(hero_id)
	var mult := _get_level_multiplier(level, upgrade_level)
	var base_hp := int(round(float(def.max_hp) * mult))
	var base_damage := int(round(float(def.damage) * mult))
	var base_initiative := int(round(float(def.initiative) * mult))
	var mods := _get_upgrade_mods(hero_id)
	var flat: Dictionary = mods.get("flat", {})
	var percent: Dictionary = mods.get("percent", {})
	return {
		"max_hp": base_hp + int(flat.get(HeroUpgradeStats.UpgradeStat.MAX_HP, 0)),
		"damage": base_damage + int(flat.get(HeroUpgradeStats.UpgradeStat.DAMAGE, 0)),
		"armour": int(flat.get(HeroUpgradeStats.UpgradeStat.ARMOUR, 0)),
		"initiative": base_initiative + int(flat.get(HeroUpgradeStats.UpgradeStat.INITIATIVE, 0)),
		"regen": int(flat.get(HeroUpgradeStats.UpgradeStat.HP_REGEN, 0)),
		"block_chance": float(percent.get(HeroUpgradeStats.UpgradeStat.BLOCK_CHANCE, 0.0)),
		"lifesteal_pct": float(percent.get(HeroUpgradeStats.UpgradeStat.LIFE_STEAL, 0.0)),
		"evasion": float(percent.get(HeroUpgradeStats.UpgradeStat.EVASION, 0.0)),
		"healing_power": float(percent.get(HeroUpgradeStats.UpgradeStat.HEALING_POWER, 0.0)),
		"status_resist": float(percent.get(HeroUpgradeStats.UpgradeStat.RESIST_STATUS, 0.0)),
		"gold_gain": float(percent.get(HeroUpgradeStats.UpgradeStat.GOLD_GAIN, 0.0)),
		"loot_chance": float(percent.get(HeroUpgradeStats.UpgradeStat.LOOT_CHANCE, 0.0)),
		"rarity_chance": float(percent.get(HeroUpgradeStats.UpgradeStat.RARITY_CHANCE, 0.0))
	}

func _get_upgrade_mods(hero_id: StringName) -> Dictionary:
	var mods := ProfileService.get_hero_upgrade_modifiers(hero_id)
	return {
		"flat": mods.get("flat_int_mods", {}),
		"percent": mods.get("percent_float_mods", {})
	}

func _get_collection_upgrade_level(hero_id: StringName) -> int:
	var collection := SaveSystem.load_collection()
	if collection == null:
		collection = SaveSystem.ensure_collection()
	if collection == null:
		return 0
	return int(collection.upgrade_level.get(String(hero_id), 0))

func _get_level_multiplier(level: int, upgrade_level: int) -> float:
	var base_mult: float = 1.2
	if RunState != null:
		base_mult = float(RunState.HERO_LEVEL_UP_STAT_MULT)
	var total_levels: int = max(0, level - 1 + upgrade_level)
	return pow(base_mult, float(total_levels))

func _get_display_stat_value(stat: int, stats: Dictionary) -> float:
	match stat:
		HeroUpgradeStats.UpgradeStat.MAX_HP:
			return float(stats.get("max_hp", 0))
		HeroUpgradeStats.UpgradeStat.DAMAGE:
			return float(stats.get("damage", 0))
		HeroUpgradeStats.UpgradeStat.ARMOUR:
			return float(stats.get("armour", 0))
		HeroUpgradeStats.UpgradeStat.BLOCK_CHANCE:
			return float(stats.get("block_chance", 0.0))
		HeroUpgradeStats.UpgradeStat.HP_REGEN:
			return float(stats.get("regen", 0))
		HeroUpgradeStats.UpgradeStat.LIFE_STEAL:
			return float(stats.get("lifesteal_pct", 0.0))
		HeroUpgradeStats.UpgradeStat.EVASION:
			return float(stats.get("evasion", 0.0))
		HeroUpgradeStats.UpgradeStat.INITIATIVE:
			return float(stats.get("initiative", 0))
		HeroUpgradeStats.UpgradeStat.HEALING_POWER:
			return float(stats.get("healing_power", 0.0))
		HeroUpgradeStats.UpgradeStat.RESIST_STATUS:
			return float(stats.get("status_resist", 0.0))
		HeroUpgradeStats.UpgradeStat.GOLD_GAIN:
			return float(stats.get("gold_gain", 0.0))
		HeroUpgradeStats.UpgradeStat.LOOT_CHANCE:
			return float(stats.get("loot_chance", 0.0))
		HeroUpgradeStats.UpgradeStat.RARITY_CHANCE:
			return float(stats.get("rarity_chance", 0.0))
		_:
			return 0.0

func _get_hero_display_name(hero_id: StringName) -> String:
	var id_str: String = String(hero_id)
	var def: CardDefinition = CardDatabase.get_definition(id_str)
	if def == null and id_str.begins_with("hero_"):
		def = CardDatabase.get_definition(id_str.substr(5))
	if def == null and id_str == "hero":
		def = CardDatabase.get_definition("knight_aprentice")
	if def != null and not def.display_name.is_empty():
		return tr(def.display_name)
	if id_str.begins_with("hero_"):
		return id_str.substr(5)
	return id_str

func _get_hero_index(hero_id: StringName) -> int:
	for i in range(_hero_ids.size()):
		if _hero_ids[i] == hero_id:
			return i
	return -1

func _is_run_context() -> bool:
	if RunState == null:
		return false
	var hero := RunState.get_card("th")
	return not hero.is_empty()
