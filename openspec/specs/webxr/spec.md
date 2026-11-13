# webxr Specification

## Purpose
The web build can be played in virtual reality through WebXR.

## Requirements
### Requirement: VR entry
When the browser reports support for `immersive-vr`, the web page SHALL show an "Enter VR" button and the pause menu SHALL offer "Enter VR"; starting a session SHALL use the existing WebGL2 context.

#### Scenario: Unsupported browser
- **WHEN** WebXR or `immersive-vr` is not available
- **THEN** no VR entry is shown and the game plays normally

### Requirement: Stereo rendering
While a session is active, the engine SHALL be driven by the XR animation frame callback and render the world once per view with the headset's view and projection matrices, placing the floor at the player's position minus `xr.eye_height`, and show the UI on a head-locked panel 1.5 m ahead.

#### Scenario: Session ends
- **WHEN** the XR session ends
- **THEN** the normal main loop resumes and input state is reset

### Requirement: VR controls
The left thumbstick SHALL move, the right thumbstick SHALL turn, the right trigger SHALL interact, the right grip SHALL go back and the left menu button SHALL pause; walking SHALL follow the head direction.

#### Scenario: Looking sideways while walking
- **WHEN** the head is turned 90 degrees left and the stick is pushed forward
- **THEN** the player walks to the left of the body direction
