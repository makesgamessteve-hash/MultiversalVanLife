# Spec Delta

## ADDED Requirements

### Requirement: Mesh building and instances
The engine SHALL merge meshes with transforms into one mesh and draw a mesh as many instances with per-instance transforms and tints.

#### Scenario: Merging
- **WHEN** a script merges three meshes with transforms
- **THEN** one mesh with all their triangles in place results
