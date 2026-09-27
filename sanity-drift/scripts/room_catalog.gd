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
			"name": "BEDROOM II · HARD",
			"theme": "bedroom",
			"subtitle": "The same weight test, with more choices",
			"objective": "Fill all three 8 kg floor plates. Pull away any Memory that flashes red.",
			"accent": GameColors.FLOAT,
			"drift": 18.0,
			"anchors": 0,
			"sequence": [Vector3.DOWN],
			"guide_lines": [
				"This follows the first bedroom rule: real Memories belong on 8 kg floor plates.",
				"Now there are three plates and hidden fakes. Test carefully and remove anything that flashes red."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-2.8, 1.4, -0.8)},
				{"kind": "memory", "position": Vector3(0.0, 2.0, 0.6)},
				{"kind": "memory", "position": Vector3(2.8, 1.0, -1.1)},
				{"kind": "false_memory", "position": Vector3(-1.4, 0.3, 1.8)},
				{"kind": "false_memory", "position": Vector3(1.5, 2.4, -2.3)},
				{"kind": "anxiety", "position": Vector3(0.0, 0.6, -2.3)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": -2.8, "v": -1.0, "threshold": 6.0, "label": "8 kg · I"},
				{"direction": Vector3.DOWN, "u": 0.0, "v": -1.0, "threshold": 6.0, "label": "8 kg · II"},
				{"direction": Vector3.DOWN, "u": 2.8, "v": -1.0, "threshold": 6.0, "label": "8 kg · III"}
			]
		},
		{
			"name": "KITCHEN II · HARD",
			"theme": "kitchen",
			"subtitle": "Two heavy places below, two light places above",
			"objective": "Fill both HEAVY floor plates and both LIGHT ceiling plates.",
			"accent": GameColors.PAD,
			"drift": 20.0,
			"anchors": 0,
			"sequence": [Vector3.DOWN, Vector3.UP],
			"guide_lines": [
				"Use the same kitchen rule: Memories fall down and Joy rises up.",
				"There are two targets for each weight now, plus identical False Memories among the heavy choices."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-2.6, 1.5, -0.6)},
				{"kind": "memory", "position": Vector3(2.4, 0.5, -1.4)},
				{"kind": "false_memory", "position": Vector3(-1.2, 2.0, 1.6)},
				{"kind": "false_memory", "position": Vector3(2.8, 1.4, 1.8)},
				{"kind": "joy", "position": Vector3(1.4, -0.8, -2.0)},
				{"kind": "joy", "position": Vector3(-2.0, -1.2, -2.5)},
				{"kind": "anxiety", "position": Vector3(-0.8, 0.2, -2.5)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": -2.5, "v": -0.8, "threshold": 6.0, "label": "HEAVY · I"},
				{"direction": Vector3.DOWN, "u": 2.5, "v": -0.8, "threshold": 6.0, "label": "HEAVY · II"},
				{"direction": Vector3.UP, "u": -2.5, "v": -0.8, "threshold": 0.5, "maximum_mass": 1.0, "label": "LIGHT · I"},
				{"direction": Vector3.UP, "u": 2.5, "v": -0.8, "threshold": 0.5, "maximum_mass": 1.0, "label": "LIGHT · II"}
			]
		},
		{
			"name": "LIBRARY II · HARD",
			"theme": "library",
			"subtitle": "Hold three live sensors at the same time",
			"objective": "Anchor Memories on I and II, then hold III so all three plates glow together.",
			"accent": GameColors.DANGER,
			"drift": 22.0,
			"anchors": 2,
			"reusable_anchor": true,
			"simultaneous_plates": true,
			"sequence": [Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD],
			"guide_lines": [
				"This keeps the Library rule: every live plate must stay occupied at the same time.",
				"Anchor a real Memory on I, anchor another on II, then land the third on III.",
				"A flashing Memory is false. Pull it away before the room collapses."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-2.4, 1.7, -0.8)},
				{"kind": "memory", "position": Vector3(2.3, 1.1, 0.8)},
				{"kind": "memory", "position": Vector3(0.0, -1.4, -1.8)},
				{"kind": "false_memory", "position": Vector3(-2.8, 0.4, 1.9)},
				{"kind": "false_memory", "position": Vector3(2.7, -0.2, -2.6)},
				{"kind": "anxiety", "position": Vector3(-1.0, 0.2, -2.8)}
			],
			"pads": [
				{"direction": Vector3.RIGHT, "u": -1.8, "v": -1.0, "threshold": 6.0, "continuous_contact": true, "label": "I"},
				{"direction": Vector3.DOWN, "u": -2.3, "v": 1.0, "threshold": 6.0, "continuous_contact": true, "label": "II"},
				{"direction": Vector3.FORWARD, "u": 2.1, "v": 0.8, "threshold": 6.0, "continuous_contact": true, "label": "III"}
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
			"subtitle": "Keep two memories in place at once",
			"objective": "During RIGHT, hold Memory on I and anchor it. During DOWN, land the other Memory on II while I stays held.",
			"accent": GameColors.DANGER,
			"drift": 26.0,
			"anchors": 1,
			"reusable_anchor": true,
			"simultaneous_plates": true,
			"sequence": [Vector3.RIGHT, Vector3.DOWN],
			"guide_lines": [
				"These two plates are live sensors. A plate goes dark as soon as its Memory is no longer held there.",
				"During the RIGHT fall, settle a Memory on plate I, then anchor it before the shift ends.",
				"During the DOWN fall, land the other Memory on plate II. Both plates must glow together. Grab the anchored Memory to recover the anchor."
			],
			"props": [
				{"kind": "memory", "position": Vector3(-1.8, 1.6, -1.0)},
				{"kind": "memory", "position": Vector3(1.2, 1.9, 1.5)},
				{"kind": "false_memory", "position": Vector3(2.7, 0.4, -2.5)},
				{"kind": "anxiety", "position": Vector3(0.0, -0.5, -1.5)}
			],
			"pads": [
				{"direction": Vector3.RIGHT, "u": -1.4, "v": -1.0, "threshold": 6.0, "continuous_contact": true, "label": "I"},
				{"direction": Vector3.DOWN, "u": -1.5, "v": 1.5, "threshold": 6.0, "continuous_contact": true, "label": "II"}
			]
		}
	]
