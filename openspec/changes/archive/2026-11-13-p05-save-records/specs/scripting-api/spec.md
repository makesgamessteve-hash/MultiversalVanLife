# Spec Delta

## ADDED Requirements

### Requirement: Persistent place storage
Scripts SHALL be able to read and write structured data records (tables of numbers, strings, booleans and nested tables) by name in the save folder.

#### Scenario: Record round trip
- **WHEN** a script stores a nested table and loads it again after a restart
- **THEN** the loaded table equals the stored one
