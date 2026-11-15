class_name BuildingStatus
extends RefCounted

var building_id: StringName
var type: StringName
var cells: Array[Vector2i] = []
var production: Dictionary = {}
var demand: float = 0.0
var powered: bool = false
var enabled: bool = true
var health: float = 100.0
var condition: StringName = &"normal"
var modifiers: Dictionary = {}
var warnings: Array[StringName] = []
var next_consequence_keys: Array[StringName] = []

func as_dict() -> Dictionary:
	var cell_arrays: Array = []
	for cell in cells:
		cell_arrays.append([cell.x, cell.y])
	return {"building_id": String(building_id), "type": String(type), "cells": cell_arrays,
		"production": production.duplicate(true), "demand": demand, "powered": powered,
		"enabled": enabled, "health": health, "condition": String(condition),
		"modifiers": modifiers.duplicate(true), "warnings": warnings.duplicate(),
		"next_consequence_keys": next_consequence_keys.duplicate()}
