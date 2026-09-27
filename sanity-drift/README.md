# Sanity Drift

A compact physics puzzle based on the Drifting Thoughts design document. The player remains stationary at the center of each room while gravity follows a sequence shown in advance.

## Running in VR

1. Connect your headset and start an active OpenXR runtime: Meta Quest Link/Air Link, SteamVR, or Virtual Desktop.
2. Double-click `play_sanity_drift.cmd`.

For HTC Vive, keep SteamVR open and use `play_sanity_drift_vive.cmd`. This
launcher explicitly selects the SteamVR OpenXR runtime so Meta XR Simulator
cannot capture the session.

When OpenXR is available, the game starts in the headset. The player remains in place with no artificial locomotion or camera rotation.

Use `play_sanity_drift_desktop.cmd` to test without a headset.

## Controls

The title screen includes a `TUTORIAL` button for an interactive training room
and a `VR CONTROLS` button with the complete in-game guide. In the tutorial, the
same robot from the main dream waits for each action before explaining the next.
Choose `NORMAL` or `HARD` before entering the dream. Hard mode replaces all
three puzzles with new layouts containing three, four, and five plates, longer
gravity sequences, more thoughts, and extra anchor decisions. It also shortens
both the Drift planning phase and the gravity warning. The final screen lets
you replay the campaign or return to the main menu.

### VR

- right trigger — remote grab; release to throw
- right trigger on the robot — give the guide a playful bump
- right grip — push the highlighted thought
- right thumbstick or Vive trackpad up/down — change grab distance
- left trigger or grip — anchor the highlighted thought until the next fall
- left thumbstick/Vive trackpad click or `X` — end the Drift phase early
- left wrist display — timer, next gravity direction, plates, and anchors

### Mouse and keyboard

- `LMB` — remote grab; release to throw
- `LMB` on the robot — give the guide a playful bump
- `RMB` — push the highlighted thought
- `Mouse` — look around
- `Wheel` — move a held thought closer or farther away
- `I` — anchor a thought until the next fall
- `P` — end the Drift phase early
- `O` — comfort mode
- `K` — ask the robot guide to repeat the room objective
- `L` — restart the room
- `Esc` — release the cursor; click to capture it again
- `U` — start the tutorial from the title screen

Room shapes, materials, and sounds are generated inside the game. The robot guide uses the imported `Robot.fbx` model.

The robot guide starts on the floor about five meters ahead of the player, walks into position,
explains the puzzle, reacts to gravity warnings and plate progress, and gives a
hint after a failed fall. Its dialogue appears beside the model in VR and in a
desktop HUD panel. Its head turns toward the camera as it speaks, and each line
plays one of the two robot voice chirps. Clicking
the robot on desktop, or pointing at it and pressing the right trigger in VR,
plays its hit sound and sends it briefly into the air. It lands and walks back
to the exact place where it was hit.

After a room is completed, its geometry breaks into fragments and dissolves into a blurred mist. The player then flies through a mind-space tunnel of luminous streaks and rings. A second transition conceals the construction of the next dream layer. The camera itself remains stationary, and VR also uses a soft comfort fade.

Each room has its own silhouette: the bedroom features a bed and moonlit window, the kitchen uses tiled flooring, cabinets, and pendant lights, and the library is built from tall shelves and glowing books.

See `DEVELOPMENT.md` for the project structure and instructions for adding rooms.

## Codex ↔ Godot MCP bridge

`tools/godot_mcp.py` is a local stdio MCP server. It gives Codex three tools:
project information, headless project validation, and running a named script from
`tests/`. It uses the Godot executable in `GODOT_EXE`, a `godot`/`godot4` command
on `PATH`, or the local Godot 4.7.2 desktop installation. Set `GODOT_EXE` if your
installation is elsewhere.

From this project directory, register it with Codex:

```powershell
codex mcp add sanity-drift-godot -- python (Join-Path (Get-Location) 'tools\godot_mcp.py')
codex mcp get sanity-drift-godot
```

Restart Codex after registration to load the new MCP tools. The bridge starts
Godot headlessly for each validation or test call; it does not control an open
editor window.

## Supported VR modes

The project uses Godot's built-in OpenXR support and targets PCVR headsets, including HTC Vive controllers through SteamVR and Quest through Link/Air Link, Steam Link, or Virtual Desktop. A standalone Quest `.apk` requires an Android export template, the Android SDK, and an export configuration for the target headset.
