class_name PartsDB
extends RefCounted

## Static database of every equippable part in the prototype.

const ARMS: Dictionary = {
	"none": {"name": "Bare Wires", "dmg": 3.0, "rate": 0.45, "range": 80.0, "kind": "spark"},
	"rusty_fist": {"name": "Rusty Fist", "dmg": 10.0, "rate": 0.38, "range": 95.0, "kind": "melee"},
	"crusher_fist": {"name": "Crusher Fist", "dmg": 34.0, "rate": 0.85, "range": 115.0, "kind": "heavy"},
	"buzzsaw": {"name": "Buzzsaw", "dmg": 7.0, "rate": 0.22, "range": 88.0, "kind": "multi", "hits": 4},
	"cannon_arm": {"name": "Scrap Cannon", "dmg": 15.0, "rate": 0.70, "range": 560.0, "kind": "ranged"},
}

const LEGS: Dictionary = {
	"basic_legs": {"name": "Basic Legs", "speed": 270.0, "jumps": 1},
	"turbo_legs": {"name": "Turbo Legs", "speed": 410.0, "jumps": 1},
	"spring_legs": {"name": "Spring Legs", "speed": 290.0, "jumps": 2},
}

const CORES: Dictionary = {
	"none": {"name": "Empty Socket"},
	"armor_core": {"name": "Armor Core", "armor": 0.35},
	"regen_core": {"name": "Regen Core", "regen": 3.0},
	"magnet_core": {"name": "Magnet Core", "magnet": 280.0},
}

const PART_COLORS: Dictionary = {
	"arm": {
		"none": Color("8a8f98"),
		"rusty_fist": Color("c47b3a"),
		"crusher_fist": Color("e05252"),
		"buzzsaw": Color("9fd8ff"),
		"cannon_arm": Color("ffb347"),
	},
	"leg": {
		"basic_legs": Color("8a8f98"),
		"turbo_legs": Color("7CFC00"),
		"spring_legs": Color("40e0d0"),
	},
	"core": {
		"none": Color("8a8f98"),
		"armor_core": Color("b48cff"),
		"regen_core": Color("7dff9a"),
		"magnet_core": Color("ff7de9"),
	},
}

const SLOT_TITLES: Dictionary = {"arm": "ARM", "leg": "LEG", "core": "CORE"}


static func part_name(ptype: String, pid: String) -> String:
	match ptype:
		"arm":
			return str(ARMS.get(pid, {}).get("name", pid))
		"leg":
			return str(LEGS.get(pid, {}).get("name", pid))
		"core":
			return str(CORES.get(pid, {}).get("name", pid))
	return pid


static func part_color(ptype: String, pid: String) -> Color:
	var slot: Dictionary = PART_COLORS.get(ptype, {})
	return slot.get(pid, Color.WHITE)
