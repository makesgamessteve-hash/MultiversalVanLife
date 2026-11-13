# Spec Delta

## ADDED Requirements

### Requirement: Save size budget
A save with 200 visited lands and their recorded changes SHALL stay below 20 MB.

#### Scenario: Many visits
- **WHEN** a stress test visits 200 lands and performs changes in each
- **THEN** the save folder is smaller than 20 MB
