# input-and-touch Specification

## Purpose
Keyboard, mouse, gamepad, touch and VR controller input are mapped to named actions so scripts never deal with devices. Mobile browsers get on-screen touch controls.

## Requirements
### Requirement: Action bindings from configuration
Bindings SHALL be read from `game/config/input.ini` as `action = binding, binding`, where a leading `-` makes a binding contribute negatively to an axis action; unknown names SHALL be ignored with a warning.

#### Scenario: Axis from two keys
- **WHEN** `move_y = W, -S` is configured and S is held
- **THEN** `mvl.value("move_y")` is -1

#### Scenario: Gamepad deadzone
- **WHEN** an analog stick reports a value below the deadzone (0.2)
- **THEN** the action value is 0

### Requirement: Edge detection per tick
`mvl.pressed` and `mvl.released` SHALL report a transition exactly once, on the first fixed update after it happened.

#### Scenario: Two ticks in one frame
- **WHEN** two fixed updates run after a key went down
- **THEN** only the first one sees `pressed`

### Requirement: Touch controls on mobile
The web build SHALL enable touch controls on touch devices: a floating movement stick on the left half, drag-to-look on the right half and USE, back and pause buttons; any touch SHALL enable them, a real mouse click SHALL disable them, and synthetic mouse events that follow a tap SHALL be ignored.

#### Scenario: Moving with the stick
- **WHEN** the player drags upwards from a touch on the left half
- **THEN** `move_y` becomes positive in proportion to the drag, clamped to 1

#### Scenario: Short tap
- **WHEN** a button is pressed and released within the same frame
- **THEN** its action is still reported as down for that frame

#### Scenario: Portrait phone
- **WHEN** the screen is taller than wide
- **THEN** the touch layout is scaled down by the aspect ratio and anchored to the screen edges so controls do not overlap
