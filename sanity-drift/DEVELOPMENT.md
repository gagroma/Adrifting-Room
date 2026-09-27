# Sanity Drift project structure

The project is split into small components. Each file owns one part of the game.

## Main files

- `scripts/main.gd` — coordinates phases, rooms, transitions, and the ending.
- `scripts/player_controller.gd` — mouse, keyboard, OpenXR, controllers, remote grab, and throwing.
- `scripts/thought_prop.gd` — physics objects, mass, shape, bounce, reverse gravity, and anchors.
- `scripts/pressure_pad.gd` — plate weight checks, highlighting, and activation.
- `scripts/room_builder.gd` — walls, door, lighting, props, plates, room themes, and disintegration.
- `scripts/consciousness_journey.gd` — the between-room flight with luminous streaks, rings, and its message.
- `scripts/room_catalog.gd` — data for every room. Most new rooms are added here.
- `scripts/game_hud.gd` — menus, VR controls guide, timer, hints, vignette, and blur transitions.
- `scripts/game_audio.gd` — procedural sounds and the completion chord.
- `scripts/game_colors.gd` — shared palette and materials.
- `scripts/guide_robot.gd` — room dialogue, hints, and guide movement.
- `scripts/guide_animation_controller.gd` — maps guide states and emotions to clips in `Robot.fbx`.

## Adding a room

Open `scripts/room_catalog.gd` and add another dictionary to the array returned by `all_rooms()`.
`hard_rooms()` contains the parallel hard campaign with separate props, plates,
gravity sequences, objectives, and robot dialogue. Keep both arrays in the same
theme order so transitions preserve the bedroom → kitchen → library structure.

Each room defines:

- `name` and `subtitle` — its title and hint;
- `accent` — the room color;
- `theme` — the visual type (`bedroom`, `kitchen`, or `library`);
- `drift` — zero-gravity phase duration;
- `anchors` — number of available anchors;
- `sequence` — ordered gravity directions;
- `props` — thought types and starting positions;
- `pads` — wall direction, coordinates, and required weight.

The remaining code constructs the room, interface, and gameplay loop automatically. Existing theme geometry lives in `_build_bedroom()`, `_build_kitchen()`, and `_build_library()` inside `room_builder.gd`. Add a function and a branch in `_build_theme_geometry()` for a new visual theme.

## Adding a thought type

Add a branch to `match thought_kind` in `scripts/thought_prop.gd`. That branch defines its shape, mass, material, collider, and special behavior. The new `kind` can then be used by any room.

## Changing controls

Desktop and VR interaction live in `scripts/player_controller.gd`. The `anchor_requested`, `skip_requested`, `restart_requested`, and `calm_requested` signals pass player intent to the main loop without coupling the controller to a room.

Keep the title-screen guide in `scripts/game_hud.gd` synchronized whenever a VR binding changes.

## Robot guide

`GuideRobot.enter_room()` selects the room introduction and moves the robot to
its speaking position. The guide reacts to warnings, plate activation, failed
cycles, and completion through methods called by `main.gd`. To add dialogue for
a new room, add a branch to `enter_room()` and set that room's `objective` in
`room_catalog.gd`. The animation controller maps emotion names such as `wave`,
`yes`, `no`, `thumbsup`, and `dance` to the imported FBX clips. Idle and walking
are chosen automatically from the guide's movement state. The `GuideHitbox`
area uses collision layer 4, which `PlayerController` includes in its grab ray.
Guide dialogue alternates `sfx/robot-sound1.wav` and `robot-sound2.wav`; a hit
plays `sfx/robot-hit.wav`, pauses dialogue, lifts the robot into a short drift,
lands it on the floor, and walks it back to its position at the instant of the hit.
The separate head mesh turns toward the active camera while dialogue is visible.

The training room is defined by `RoomCatalog.tutorial_room()` and runs as a
separate game mode. `PlayerController` reports grab, release, push, and distance
changes to `main.gd`, which advances the live objective and the robot's lesson.

## Verification

`tests/smoke_test.gd` checks scene loading, VR components, the title-screen controls guide, mouse grab, pressure plates, all three visual themes, the between-room flight, anchors, and the complete bedroom-to-kitchen transition. `tests/tutorial_test.gd` checks the tutorial button, every guided interaction, anchor release, completion, and return to the title menu. `tests/menu_finish_test.gd` checks difficulty selection and the desktop/VR final screens.
