# Tasks

## 1. Core

- [x] 1.1 Add decal flag and layer to entities and the frustum culling helpers; verify unit tests for field mapping and sphere/plane classification
- [x] 1.2 Add portal definitions with portal transform and oblique near-plane projection, and `mvl.portal`; verify unit tests that points map to the target frame and points behind the target plane are clipped

## 2. Renderer

- [x] 2.1 Switch to depth+stencil targets, request stencil for the window and WebXR layer, set `znear`/`zfar`; verify GL game tests under Xvfb
- [x] 2.2 Add the decal pass; verify a GL test that renders a red decal over green ground at 60 m and a shallow angle and finds no green pixels in the decal area
- [x] 2.3 Add the portal passes for flat and XR rendering; verify a GL screenshot test that a portal shows its target scene and nothing when occluded
- [x] 2.4 Apply frustum culling in all passes; verify draw counts drop in a GL test log

## 3. Game

- [x] 3.1 Turn water, roads and rugs in the current worlds into decals or water surfaces; verify by GL screenshots of each world from a distance and the existing game tests
- [x] 3.2 Document decals and portals in `docs/MODDING.md`; verify the documented example runs in a game test
