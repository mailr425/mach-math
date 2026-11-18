class_name Inventory
extends RefCounted
## Materials, tools, armor and daggers, plus the crafting recipes.
## Saved to user://save.json so gear carries over between runs.

const SAVE_PATH := "user://save.json"
const MATERIALS := ["wood", "stone", "iron", "diamond"]
const PICKAXE_NAMES := ["None", "Wood", "Stone", "Iron"]
## Pickaxe level needed to mine each ore (1 = wooden, 2 = stone, 3 = iron)
const MINE_TIER := {"stone": 1, "iron": 2, "diamond": 3}
## Shield (in half-hearts) that each armor piece gives
const ARMOR_SHIELD := {"none": 0, "bark": 1, "iron": 2, "diamond": 3}
const ARMOR_RANK := {"none": 0, "bark": 1, "iron": 2, "diamond": 3}
const MAX_DAGGERS := 9

const RECIPES := [
	{"id": "axe", "name": "Wooden Axe", "cost": {"wood": 3}, "desc": "Chop trees in one hit and get more wood."},
	{"id": "pick1", "name": "Wooden Pickaxe", "cost": {"wood": 3}, "desc": "Mine stone blocks."},
	{"id": "pick2", "name": "Stone Pickaxe", "cost": {"wood": 2, "stone": 3}, "desc": "Mine iron ore (tan specks)."},
	{"id": "pick3", "name": "Iron Pickaxe", "cost": {"wood": 2, "iron": 3}, "desc": "Mine diamond ore (blue specks)."},
	{"id": "daggers", "name": "2 Daggers", "cost": {"wood": 1, "iron": 1}, "desc": "Hold the attack button to throw a dagger."},
	{"id": "bark_helmet", "slot": "helmet", "tier": "bark", "name": "Bark Helmet", "cost": {"wood": 3}, "desc": "+ half a shield heart."},
	{"id": "bark_chest", "slot": "chest", "tier": "bark", "name": "Bark Chestplate", "cost": {"wood": 5}, "desc": "+ half a shield heart."},
	{"id": "bark_boots", "slot": "boots", "tier": "bark", "name": "Bark Boots", "cost": {"wood": 2}, "desc": "+ half a shield heart."},
	{"id": "iron_helmet", "slot": "helmet", "tier": "iron", "name": "Iron Helmet", "cost": {"iron": 3}, "desc": "+ 1 shield heart."},
	{"id": "iron_chest", "slot": "chest", "tier": "iron", "name": "Iron Chestplate", "cost": {"iron": 5}, "desc": "+ 1 shield heart."},
	{"id": "iron_boots", "slot": "boots", "tier": "iron", "name": "Iron Boots", "cost": {"iron": 2}, "desc": "+ 1 shield heart."},
	{"id": "diamond_helmet", "slot": "helmet", "tier": "diamond", "name": "Diamond Helmet", "cost": {"diamond": 3}, "desc": "+ 1 and a half shield hearts."},
	{"id": "diamond_chest", "slot": "chest", "tier": "diamond", "name": "Diamond Chestplate", "cost": {"diamond": 5}, "desc": "+ 1 and a half shield hearts."},
	{"id": "diamond_boots", "slot": "boots", "tier": "diamond", "name": "Diamond Boots", "cost": {"diamond": 2}, "desc": "+ 1 and a half shield hearts."},
]

var mats := {"wood": 0, "stone": 0, "iron": 0, "diamond": 0}
var pickaxe := 0          # 0 none, 1 wood, 2 stone, 3 iron
var has_axe := false
var armor := {"helmet": "none", "chest": "none", "boots": "none"}
var daggers := 3


func shield_max() -> int:
	var total := 0
	for slot in armor:
		total += int(ARMOR_SHIELD[armor[slot]])
	return total


func add_daggers(n: int) -> void:
	daggers = clampi(daggers + n, 0, MAX_DAGGERS)


## "" if it can be crafted, otherwise the reason it can't.
func craft_status(r: Dictionary) -> String:
	var id: String = r["id"]
	if id == "axe" and has_axe:
		return "OWNED"
	if id.begins_with("pick"):
		var tier := int(id.substr(4))
		if pickaxe >= tier:
			return "OWNED"
		if pickaxe < tier - 1:
			return "needs %s Pickaxe" % PICKAXE_NAMES[tier - 1]
	if r.has("slot"):
		if ARMOR_RANK[armor[r["slot"]]] >= ARMOR_RANK[r["tier"]]:
			return "OWNED"
	if id == "daggers" and daggers >= MAX_DAGGERS:
		return "FULL"
	var cost: Dictionary = r["cost"]
	for m in cost:
		if int(mats[m]) < int(cost[m]):
			return "need %d more %s" % [int(cost[m]) - int(mats[m]), m]
	return ""


func cost_text(r: Dictionary) -> String:
	var parts: Array = []
	var cost: Dictionary = r["cost"]
	for m in cost:
		parts.append("%d %s" % [cost[m], m])
	return ", ".join(parts)


func craft(r: Dictionary) -> bool:
	if craft_status(r) != "":
		return false
	var cost: Dictionary = r["cost"]
	for m in cost:
		mats[m] = int(mats[m]) - int(cost[m])
	var id: String = r["id"]
	if id == "axe":
		has_axe = true
	elif id.begins_with("pick"):
		pickaxe = int(id.substr(4))
	elif id == "daggers":
		add_daggers(2)
	elif r.has("slot"):
		armor[r["slot"]] = r["tier"]
	save()
	return true


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"mats": mats, "pickaxe": pickaxe, "has_axe": has_axe,
		"armor": armor, "daggers": daggers}))
	f.close()


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	if data.has("mats"):
		for m in MATERIALS:
			mats[m] = int(data["mats"].get(m, 0))
	pickaxe = int(data.get("pickaxe", 0))
	has_axe = bool(data.get("has_axe", false))
	if data.has("armor"):
		for slot in armor:
			var tier: String = str(data["armor"].get(slot, "none"))
			armor[slot] = tier if ARMOR_SHIELD.has(tier) else "none"
	daggers = clampi(int(data.get("daggers", 3)), 0, MAX_DAGGERS)
