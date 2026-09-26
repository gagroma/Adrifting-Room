class_name RoomCatalog
extends RefCounted


static func all_rooms() -> Array[Dictionary]:
	return [
		{
			"name": "BEDROOM",
			"theme": "bedroom",
			"subtitle": "A memory must find its weight",
			"objective": "Guide the Memory onto the 8 kg plate.",
			"accent": GameColors.FLOAT,
			"drift": 22.0,
			"anchors": 0,
			"sequence": [Vector3.DOWN],
			"props": [
				{"kind": "memory", "position": Vector3(0.0, 1.6, -0.4)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": 0.0, "v": -0.8, "threshold": 6.0, "label": "8 kg"}
			]
		},
		{
			"name": "KITCHEN",
			"theme": "kitchen",
			"subtitle": "Not every thought falls the same way",
			"objective": "Set a heavy thought below and a light thought above.",
			"accent": GameColors.PAD,
			"drift": 24.0,
			"anchors": 0,
			"sequence": [Vector3.DOWN, Vector3.UP],
			"props": [
				{"kind": "memory", "position": Vector3(-2.1, 1.3, -0.2)},
				{"kind": "joy", "position": Vector3(2.0, -1.2, -0.3)},
				{"kind": "anxiety", "position": Vector3(0.0, 0.4, -1.8)}
			],
			"pads": [
				{"direction": Vector3.DOWN, "u": -2.2, "v": -0.4, "threshold": 6.0, "label": "HEAVY"},
				{"direction": Vector3.UP, "u": 2.2, "v": -0.4, "threshold": 0.5, "label": "LIGHT"}
			]
		},
		{
			"name": "LIBRARY",
			"theme": "library",
			"subtitle": "Save one thought for the next fall",
			"objective": "Light plates I then II. Anchor one thought between falls.",
			"accent": GameColors.DANGER,
			"drift": 26.0,
			"anchors": 1,
			"sequence": [Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD],
			"props": [
				{"kind": "memory", "position": Vector3(-1.8, 1.6, -1.0)},
				{"kind": "memory", "position": Vector3(1.2, 1.9, 1.5)},
				{"kind": "anxiety", "position": Vector3(0.0, -0.5, -1.5)}
			],
			"pads": [
				{"direction": Vector3.RIGHT, "u": -1.4, "v": -1.0, "threshold": 6.0, "label": "I"},
				{"direction": Vector3.DOWN, "u": -1.5, "v": 1.5, "threshold": 6.0, "label": "II"}
			]
		}
	]
