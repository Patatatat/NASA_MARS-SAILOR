class_name NasaCatalog
extends Node

var _data: Dictionary = {}

func _ready() -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/nasa/sources.json"))
	_data = value if value is Dictionary else {}

func get_source(source_id: StringName) -> Dictionary:
	for item in _data.get("sources", []):
		if item is Dictionary and item.get("id") == String(source_id):
			return item.duplicate(true)
	return {}

func get_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _data.get("sources", []):
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result

func get_curated_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in _data.get("curated_donki_events", []):
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result

func get_science_cards() -> Array[ScienceCard]:
	var cards: Array[ScienceCard] = []
	for source in get_sources():
		var card := ScienceCard.new()
		card.id = StringName("card_%s" % source["id"])
		card.source_id = StringName(source["id"])
		card.title_key = StringName("science.card.%s.title" % source["id"])
		card.body_key = StringName(source["explanation_key"])
		card.model_limit_key = StringName(source["model_limit_key"])
		cards.append(card)
	return cards
