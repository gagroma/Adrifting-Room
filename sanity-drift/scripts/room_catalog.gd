class_name RoomCatalog
extends RefCounted


static func tutorial_room() -> Dictionary:
	return {
		"name": "TRAINING DREAM",
		"theme": "bedroom",
		"subtitle": "Learn to guide a drifting thought",
		"objective": "Listen to the robot guide.",
		"accent": GameColors.FLOAT,
		"drift": 120.0,
		"anchors": 1,
		"sequence": [Vector3.DOWN],
		"props": [
			{"kind": "memory", "position": Vector3(-1.2, 1.4, -0.7)},
			{"kind": "false_memory", "position": Vector3(2.2, 1.0, -1.8)}
		],
		"pads": [
			{"direction": Vector3.DOWN, "u": 0.0, "v": -1.0, "threshold": 6.0, "label": "TRAINING"}
		]
	}


static func hard_rooms() -> Array[Dictionary]:
	return [
		{
			"name": "FRACTURED BEDROOM",
			"theme": "bedroom",
			"subtitle": "One memory must cross three planes",
			"objective": "Light FLOOR, RIGHT, then CEILING across three gravity shifts.",
			"accent": GameColors.FLOAT,
			"drift": 18.0,
			"anchors": 1,
			"sequence": [Vector3.DOWN, Vector3.RIGHT, Vector3.UP],
			"guide_lines": [
				"Hard dreams use a different puzzle. Three plates must stay lit.",
				"Follow the sequence: floor, right wall, then ceiling. Reuse a Memory after each plate locks.",
				"False Memories look identical. If one flashes red on a plate, pull it away before five seconds expire."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-1.8, 1.4, -0.8)},
				{"kind": "memory", "position": Vector3(1.8, -0.8, -1.2)},
				{"kind": "false_memory", "position": Vector3(0.5, 2.1, -2.4)},
				{"kind": "anxiety", "position": Vector3(0.0, 0.6, -2.3)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": 0.0, "v": -1.0, "threshold": 6.0, "label": "FLOOR"},
				{"direction": Vector3.RIGHT, "u": 0.2, "v": -1.2, "threshold": 6.0, "label": "RIGHT"},
				{"direction": Vector3.UP, "u": 2.2, "v": -1.0, "threshold": 6.0, "label": "CEILING"}
			]
		},
		{
			"name": "CROSSED KITCHEN",
			"theme": "kitchen",
			"subtitle": "Four plates pull in four directions",
			"objective": "Light HEAVY, LEFT, FRONT, and LIGHT plates through the full cycle.",
			"accent": GameColors.PAD,
			"drift": 20.0,
			"anchors": 1,
			"sequence": [Vector3.DOWN, Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
			"guide_lines": [
				"Four plates, four directions. The lit outline reveals the next target wall.",
				"Memories satisfy heavy plates. Save Joy for the LIGHT plate and use your anchor to control the cycle.",
				"Two hidden fakes drift here. Red flashing is the only warning before the five-second detonation."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-2.4, 1.5, -0.6)},
				{"kind": "memory", "position": Vector3(2.2, 0.5, -1.4)},
				{"kind": "memory", "position": Vector3(0.2, -1.2, 0.8)},
				{"kind": "false_memory", "position": Vector3(-1.5, 2.0, 1.6)},
				{"kind": "false_memory", "position": Vector3(2.8, 1.4, -2.8)},
				{"kind": "joy", "position": Vector3(1.4, -0.8, -2.0)},
				{"kind": "anxiety", "position": Vector3(-0.8, 0.2, -2.5)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": -2.5, "v": -0.8, "threshold": 6.0, "label": "HEAVY"},
				{"direction": Vector3.LEFT, "u": -0.4, "v": -1.4, "threshold": 6.0, "label": "LEFT"},
				{"direction": Vector3.FORWARD, "u": 2.7, "v": 0.8, "threshold": 6.0, "label": "FRONT"},
				{"direction": Vector3.UP, "u": 2.5, "v": -0.8, "threshold": 0.5, "maximum_mass": 1.0, "label": "LIGHT"}
			]
		},
		{
			"name": "INFINITE LIBRARY",
			"theme": "library",
			"subtitle": "Five plates remember every direction",
			"objective": "Complete plates I–V across right, floor, front, left, and ceiling.",
			"accent": GameColors.DANGER,
			"drift": 22.0,
			"anchors": 2,
			"sequence": [Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
			"guide_lines": [
				"This library has five permanent locks. Read the entire gravity sequence before moving.",
				"You have two anchors. Preserve one Memory while the other travels to the next numbered wall.",
				"False Memories are visually identical. Remove any Memory that starts flashing red on a plate."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-2.4, 1.7, -0.8)},
				{"kind": "memory", "position": Vector3(2.3, 1.1, 0.8)},
				{"kind": "memory", "position": Vector3(0.0, -1.4, -1.8)},
				{"kind": "false_memory", "position": Vector3(-2.8, 0.4, 1.9)},
				{"kind": "false_memory", "position": Vector3(2.7, -0.2, -2.6)},
				{"kind": "joy", "position": Vector3(1.2, -0.6, -2.5)},
				{"kind": "anxiety", "position": Vector3(-1.0, 0.2, -2.8)}
			],
			"pads": [
				{"direction": Vector3.RIGHT, "u": -1.8, "v": -1.0, "threshold": 6.0, "label": "I"},
				{"direction": Vector3.DOWN, "u": -2.3, "v": 1.0, "threshold": 6.0, "label": "II"},
				{"direction": Vector3.FORWARD, "u": -2.7, "v": 1.5, "threshold": 6.0, "label": "III"},
				{"direction": Vector3.LEFT, "u": 1.4, "v": -1.0, "threshold": 6.0, "label": "IV"},
				{"direction": Vector3.UP, "u": 2.3, "v": 1.0, "threshold": 6.0, "label": "V"}
			]
		}
	]


static func all_rooms() -> Array[Dictionary]:
	return [
		{
			"name": "BEDROOM",
			"theme": "bedroom",
			"subtitle": "A memory must find its weight",
			"objective": "Guide a Memory onto the 8 kg plate. Pull it away if it starts flashing red.",
			"accent": GameColors.FLOAT,
			"drift": 22.0,
			"anchors": 0,
			"sequence": [Vector3.DOWN],
			"props": [
				{"kind": "memory", "position": Vector3(-1.2, 1.6, -0.4)},
				{"kind": "false_memory", "position": Vector3(2.0, 1.1, -1.8)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": 0.0, "v": -0.8, "threshold": 6.0, "label": "8 kg"}
			]
		},
		{
			"name": "KITCHEN",
			"theme": "kitchen",
			"subtitle": "Not every thought falls the same way",
			"objective": "Set a heavy thought below and a light thought above. Reject the fake.",
			"accent": GameColors.PAD,
			"drift": 24.0,
			"anchors": 0,
			"sequence": [Vector3.DOWN, Vector3.UP],
			"props": [
				{"kind": "memory", "position": Vector3(-2.1, 1.3, -0.2)},
				{"kind": "false_memory", "position": Vector3(0.8, 1.8, 1.5)},
				{"kind": "joy", "position": Vector3(2.0, -1.2, -0.3)},
				{"kind": "anxiety", "position": Vector3(0.0, 0.4, -1.8)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": -2.2, "v": -0.4, "threshold": 6.0, "label": "HEAVY"},
				{"direction": Vector3.UP, "u": 2.2, "v": -0.4, "threshold": 0.5, "maximum_mass": 1.0, "label": "LIGHT"}
			]
		},
		{
			"name": "LIBRARY",
			"theme": "library",
			"subtitle": "Save one thought for the next fall",
			"objective": "Light plates I then II. Anchor one thought between falls and reject false memories.",
			"accent": GameColors.DANGER,
			"drift": 26.0,
			"anchors": 1,
			"sequence": [Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD],
			"props": [
				{"kind": "memory", "position": Vector3(-1.8, 1.6, -1.0)},
				{"kind": "memory", "position": Vector3(1.2, 1.9, 1.5)},
				{"kind": "false_memory", "position": Vector3(2.7, 0.4, -2.5)},
				{"kind": "anxiety", "position": Vector3(0.0, -0.5, -1.5)}
			],
			"pads": [
				{"direction": Vector3.RIGHT, "u": -1.4, "v": -1.0, "threshold": 6.0, "label": "I"},
				{"direction": Vector3.DOWN, "u": -1.5, "v": 1.5, "threshold": 6.0, "label": "II"}
			]
		}
	]
