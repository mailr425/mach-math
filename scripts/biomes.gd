class_name Biomes
extends RefCounted
## All the environments. Each run picks 3 of these at random.
## To make a new one, copy an entry in ALL and change its name, colors and numbers.
## Anything an entry leaves out comes from DEFAULTS.
##
## hazard:   "" (none), "liquid" (lava, swamp, water...), "pit", or "spikes"
## tree:     "", "oak", "pine", "palm", "cactus", "jungle", "dead", "flower", "mushroom"
## pad:      bounce pads: "", "mushroom", "hay", "ball", "flower"
## backdrop: "", "hills", "dunes", "spikes", "stars", "mountains", "houses", "city",
##           "grass", "cave", "bricks", "jungle", "sea", "trunk"
## enemies:  kind is "walker", "crab", "flyer", "hopper", or "dragon"
## features: how often each thing appears in the running sections (bigger = more)

const DEFAULTS := {
	"name": "???", "quirk": "",
	"sky": Color(0.5, 0.75, 1.0), "ground": Color(0.4, 0.28, 0.16), "top": Color(0.35, 0.8, 0.3),
	"backdrop": "", "backdrop_color": Color(0.4, 0.65, 0.4),
	"block": Color(0.6, 0.45, 0.3), "block_style": "crate",
	"tree": "", "tree_snow": false, "pad": "", "platform": Color(0.45, 0.6, 0.3),
	"hazard": "", "hazard_color": Color.BLACK, "hazard_name": "", "hazard_gap": [120.0, 190.0],
	"ores": ["stone"],
	"features": {"hazard": 0, "hurdle": 3, "ore": 2, "tree": 2, "pad": 0, "platform": 1, "daggers": 1},
	"enemies": [{"kind": "walker", "name": "Slime", "color": Color(0.3, 0.75, 0.35), "size": Vector2(40, 32), "speed": 70.0, "points": 50}],
	"particles": "", "dark": 0.0, "gravity": 1.0, "friction": 1.0, "accel": 1.0,
}

const ALL := {
	"plains": {
		"name": "The Plains", "quirk": "Wide open fields. A nice warm-up!",
		"backdrop": "hills", "tree": "oak", "ores": ["stone", "stone", "iron"],
		"features": {"hazard": 0, "hurdle": 3, "ore": 2, "tree": 4, "pad": 0, "platform": 1, "daggers": 1},
	},
	"forest": {
		"name": "The Forest", "quirk": "Trees everywhere. Bring an axe! Bounce on mushrooms.",
		"sky": Color(0.55, 0.78, 0.9), "top": Color(0.2, 0.55, 0.2), "backdrop": "hills",
		"backdrop_color": Color(0.15, 0.4, 0.2), "tree": "oak", "pad": "mushroom",
		"ores": ["stone", "iron"],
		"features": {"hazard": 0, "hurdle": 2, "ore": 1, "tree": 7, "pad": 2, "platform": 2, "daggers": 1},
		"enemies": [
			{"kind": "walker", "name": "Mossling", "color": Color(0.2, 0.45, 0.2), "size": Vector2(40, 30), "speed": 70.0, "points": 50},
			{"kind": "hopper", "name": "Sproutling", "color": Color(0.5, 0.8, 0.3), "size": Vector2(30, 28), "speed": 50.0, "points": 60}],
	},
	"desert": {
		"name": "The Desert", "quirk": "Watch out for quicksand!",
		"sky": Color(1.0, 0.85, 0.55), "ground": Color(0.85, 0.68, 0.4), "top": Color(0.95, 0.8, 0.5),
		"backdrop": "dunes", "backdrop_color": Color(0.92, 0.72, 0.45), "tree": "cactus",
		"block": Color(0.75, 0.6, 0.4), "block_style": "rock",
		"hazard": "liquid", "hazard_color": Color(0.7, 0.55, 0.3), "hazard_name": "Quicksand",
		"ores": ["stone", "stone", "iron"],
		"features": {"hazard": 3, "hurdle": 2, "ore": 2, "tree": 2, "pad": 0, "platform": 1, "daggers": 1},
		"enemies": [{"kind": "walker", "name": "Scorpling", "color": Color(0.8, 0.5, 0.2), "size": Vector2(44, 24), "speed": 120.0, "points": 60}],
	},
	"hell": {
		"name": "Hell", "quirk": "Lava pits! Don't fall in.",
		"sky": Color(0.35, 0.05, 0.05), "ground": Color(0.22, 0.07, 0.07), "top": Color(0.45, 0.12, 0.1),
		"backdrop": "spikes", "backdrop_color": Color(0.28, 0.05, 0.05), "tree": "dead",
		"block": Color(0.2, 0.15, 0.18), "block_style": "rock",
		"hazard": "liquid", "hazard_color": Color(1.0, 0.4, 0.0), "hazard_name": "Lava",
		"ores": ["iron", "iron", "diamond", "stone"], "particles": "embers",
		"features": {"hazard": 4, "hurdle": 2, "ore": 3, "tree": 1, "pad": 0, "platform": 1, "daggers": 1},
		"enemies": [
			{"kind": "flyer", "name": "Imp", "color": Color(0.9, 0.2, 0.15), "size": Vector2(32, 28), "speed": 90.0, "points": 75},
			{"kind": "walker", "name": "Magma blob", "color": Color(1.0, 0.5, 0.1), "size": Vector2(40, 30), "speed": 80.0, "points": 50}],
	},
	"moon": {
		"name": "The Moon", "quirk": "Low gravity! Jump super high. Mind the craters.",
		"sky": Color(0.02, 0.02, 0.08), "ground": Color(0.42, 0.42, 0.47), "top": Color(0.7, 0.7, 0.75),
		"backdrop": "stars", "backdrop_color": Color(0.25, 0.45, 0.85),
		"block": Color(0.55, 0.55, 0.6), "block_style": "rock",
		"hazard": "pit", "hazard_color": Color(0.05, 0.05, 0.1), "hazard_name": "Crater",
		"hazard_gap": [160.0, 260.0], "gravity": 0.45, "ores": ["stone", "iron", "diamond"],
		"features": {"hazard": 3, "hurdle": 2, "ore": 3, "tree": 0, "pad": 0, "platform": 2, "daggers": 1},
		"platform": Color(0.6, 0.6, 0.65),
		"enemies": [{"kind": "hopper", "name": "Moon hopper", "color": Color(0.7, 0.4, 0.9), "size": Vector2(34, 30), "speed": 60.0, "points": 60}],
	},
	"snow": {
		"name": "Snowy Wonderland", "quirk": "Slippery ice and freezing water!",
		"sky": Color(0.75, 0.85, 0.95), "ground": Color(0.8, 0.86, 0.92), "top": Color(1, 1, 1),
		"backdrop": "mountains", "backdrop_color": Color(0.7, 0.75, 0.88), "tree": "pine", "tree_snow": true,
		"block": Color(0.9, 0.95, 1.0), "block_style": "snow",
		"hazard": "liquid", "hazard_color": Color(0.5, 0.78, 1.0), "hazard_name": "Freezing water",
		"friction": 0.2, "accel": 0.6, "particles": "snow", "ores": ["stone", "iron"],
		"features": {"hazard": 2, "hurdle": 2, "ore": 1, "tree": 4, "pad": 0, "platform": 1, "daggers": 1},
		"enemies": [{"kind": "walker", "name": "Snowball", "color": Color(0.95, 0.97, 1.0), "size": Vector2(36, 36), "speed": 60.0, "points": 50}],
	},
	"village": {
		"name": "The Village", "quirk": "Bounce on the haystacks!",
		"backdrop": "houses", "backdrop_color": Color(0.75, 0.55, 0.4), "tree": "oak", "pad": "hay",
		"ores": ["stone", "iron"],
		"features": {"hazard": 0, "hurdle": 2, "ore": 1, "tree": 3, "pad": 3, "platform": 1, "daggers": 2},
		"enemies": [{"kind": "walker", "name": "Blue slime", "color": Color(0.3, 0.5, 0.95), "size": Vector2(40, 32), "speed": 70.0, "points": 50}],
	},
	"london": {
		"name": "London", "quirk": "Rainy streets. Hop over the buses!",
		"sky": Color(0.55, 0.6, 0.65), "ground": Color(0.28, 0.28, 0.3), "top": Color(0.45, 0.45, 0.48),
		"backdrop": "city", "backdrop_color": Color(0.38, 0.4, 0.46), "tree": "oak",
		"block": Color(0.8, 0.1, 0.1), "block_style": "bus", "particles": "rain",
		"ores": ["stone", "iron"],
		"features": {"hazard": 0, "hurdle": 4, "ore": 1, "tree": 1, "pad": 0, "platform": 1, "daggers": 1},
		"enemies": [
			{"kind": "walker", "name": "Puddle blob", "color": Color(0.4, 0.5, 0.7), "size": Vector2(42, 26), "speed": 70.0, "points": 50},
			{"kind": "flyer", "name": "Fog sprite", "color": Color(0.85, 0.85, 0.9), "size": Vector2(30, 26), "speed": 80.0, "points": 75}],
	},
	"garden": {
		"name": "The Giant Garden", "quirk": "You're tiny! Bounce on giant flowers.",
		"sky": Color(0.6, 0.85, 1.0), "top": Color(0.3, 0.75, 0.25),
		"backdrop": "grass", "backdrop_color": Color(0.25, 0.6, 0.2), "tree": "flower", "pad": "flower",
		"block": Color(0.55, 0.4, 0.3), "block_style": "rock", "ores": ["stone"],
		"features": {"hazard": 0, "hurdle": 1, "ore": 1, "tree": 4, "pad": 3, "platform": 2, "daggers": 1},
		"enemies": [
			{"kind": "walker", "name": "Beetle", "color": Color(0.2, 0.25, 0.6), "size": Vector2(30, 20), "speed": 130.0, "points": 60},
			{"kind": "flyer", "name": "Buzzbug", "color": Color(1.0, 0.85, 0.2), "size": Vector2(26, 22), "speed": 100.0, "points": 75}],
	},
	"caves": {
		"name": "The Caves", "quirk": "It's dark down here, but full of ore!",
		"sky": Color(0.08, 0.07, 0.07), "ground": Color(0.3, 0.27, 0.25), "top": Color(0.4, 0.36, 0.32),
		"backdrop": "cave", "backdrop_color": Color(0.18, 0.16, 0.15), "tree": "mushroom",
		"block": Color(0.35, 0.32, 0.3), "block_style": "rock",
		"hazard": "pit", "hazard_color": Color(0.02, 0.02, 0.02), "hazard_name": "Pit",
		"dark": 0.3, "ores": ["stone", "stone", "iron", "iron", "diamond"], "platform": Color(0.4, 0.36, 0.32),
		"features": {"hazard": 2, "hurdle": 1, "ore": 6, "tree": 1, "pad": 0, "platform": 2, "daggers": 1},
		"enemies": [
			{"kind": "flyer", "name": "Cave bat", "color": Color(0.45, 0.3, 0.55), "size": Vector2(30, 20), "speed": 100.0, "points": 75},
			{"kind": "walker", "name": "Rock blob", "color": Color(0.5, 0.48, 0.45), "size": Vector2(40, 32), "speed": 60.0, "points": 50}],
	},
	"dungeon": {
		"name": "The Dungeon", "quirk": "Spike pits and baby dragons!",
		"sky": Color(0.12, 0.1, 0.12), "ground": Color(0.35, 0.33, 0.36), "top": Color(0.5, 0.48, 0.5),
		"backdrop": "bricks", "backdrop_color": Color(0.22, 0.2, 0.24),
		"hazard": "spikes", "hazard_color": Color(0.08, 0.08, 0.1), "hazard_name": "Spike pit",
		"dark": 0.6, "ores": ["iron", "iron", "diamond"], "platform": Color(0.45, 0.43, 0.47),
		"features": {"hazard": 3, "hurdle": 2, "ore": 2, "tree": 0, "pad": 0, "platform": 2, "daggers": 2},
		"enemies": [
			{"kind": "dragon", "name": "Baby dragon", "color": Color(0.85, 0.2, 0.2), "size": Vector2(44, 30), "speed": 80.0, "points": 100},
			{"kind": "dragon", "name": "Baby dragon", "color": Color(0.25, 0.7, 0.35), "size": Vector2(44, 30), "speed": 90.0, "points": 100},
			{"kind": "walker", "name": "Dungeon slime", "color": Color(0.5, 0.8, 0.3), "size": Vector2(40, 32), "speed": 70.0, "points": 50}],
	},
	"rainforest": {
		"name": "Tropical Rainforest", "quirk": "Poison swamps! Watch your step.",
		"sky": Color(0.45, 0.65, 0.5), "ground": Color(0.3, 0.22, 0.12), "top": Color(0.2, 0.55, 0.2),
		"backdrop": "jungle", "backdrop_color": Color(0.12, 0.38, 0.18), "tree": "jungle",
		"hazard": "liquid", "hazard_color": Color(0.55, 0.75, 0.2), "hazard_name": "Poison swamp",
		"particles": "rain", "ores": ["stone", "iron"],
		"features": {"hazard": 3, "hurdle": 1, "ore": 1, "tree": 5, "pad": 0, "platform": 2, "daggers": 1},
		"enemies": [{"kind": "hopper", "name": "Dart frog", "color": Color(0.1, 0.6, 1.0), "size": Vector2(28, 22), "speed": 70.0, "points": 60}],
	},
	"beach": {
		"name": "The Beach", "quirk": "Bounce on beach balls! Crabs are fast.",
		"sky": Color(0.55, 0.85, 1.0), "ground": Color(0.88, 0.78, 0.52), "top": Color(0.96, 0.88, 0.6),
		"backdrop": "sea", "backdrop_color": Color(0.2, 0.55, 0.85), "tree": "palm", "pad": "ball",
		"block": Color(0.7, 0.55, 0.35), "ores": ["stone"],
		"features": {"hazard": 0, "hurdle": 2, "ore": 1, "tree": 3, "pad": 2, "platform": 1, "daggers": 1},
		"enemies": [{"kind": "crab", "name": "Crab", "color": Color(0.95, 0.35, 0.2), "size": Vector2(44, 24), "speed": 140.0, "points": 60}],
	},
	"sea": {
		"name": "The Sea", "quirk": "Hop across islands. Don't fall in the water!",
		"sky": Color(0.5, 0.8, 1.0), "ground": Color(0.85, 0.75, 0.5), "top": Color(0.92, 0.84, 0.56),
		"backdrop": "sea", "backdrop_color": Color(0.15, 0.45, 0.8), "tree": "palm",
		"hazard": "liquid", "hazard_color": Color(0.1, 0.4, 0.8), "hazard_name": "The sea",
		"hazard_gap": [170.0, 240.0], "ores": ["stone"], "platform": Color(0.55, 0.38, 0.2),
		"features": {"hazard": 5, "hurdle": 1, "ore": 0, "tree": 1, "pad": 0, "platform": 2, "daggers": 1},
		"enemies": [{"kind": "hopper", "name": "Leaping fish", "color": Color(0.3, 0.85, 0.85), "size": Vector2(34, 22), "speed": 60.0, "points": 60}],
	},
	"giant_tree": {
		"name": "The Giant Tree", "quirk": "Run along a giant branch. Lots of wood up here!",
		"sky": Color(0.55, 0.8, 0.95), "ground": Color(0.4, 0.26, 0.14), "top": Color(0.5, 0.33, 0.18),
		"backdrop": "trunk", "backdrop_color": Color(0.35, 0.22, 0.12), "tree": "oak",
		"hazard": "pit", "hazard_color": Color(0.55, 0.8, 0.95), "hazard_name": "Falling off the branch",
		"platform": Color(0.3, 0.65, 0.25), "particles": "leaves", "ores": ["stone"],
		"features": {"hazard": 2, "hurdle": 1, "ore": 0, "tree": 3, "pad": 0, "platform": 4, "daggers": 1},
		"enemies": [
			{"kind": "walker", "name": "Acorn critter", "color": Color(0.55, 0.35, 0.15), "size": Vector2(34, 30), "speed": 80.0, "points": 50},
			{"kind": "flyer", "name": "Leaf sprite", "color": Color(0.4, 0.8, 0.3), "size": Vector2(28, 24), "speed": 90.0, "points": 75}],
	},
}


static func ids() -> Array:
	return ALL.keys()


static func get_biome(id: String) -> Dictionary:
	var d: Dictionary = DEFAULTS.duplicate(true)
	d.merge(ALL[id], true)
	d["id"] = id
	return d
