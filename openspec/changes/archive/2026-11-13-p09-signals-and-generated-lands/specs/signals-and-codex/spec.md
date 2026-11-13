# Spec Delta

## Purpose

Lets the player reach the cosmos through Juniper: nightly signals from places in trouble, a logbook of visited places to return to, and later a codex of discovered lore.

## ADDED Requirements

### Requirement: Nightly signals
Each night the van console SHALL offer three signals, each pointing to a land with an active trouble, described in Juniper's words; signals SHALL be chosen by severity and variety and SHALL never lie in the Prime universe.

#### Scenario: Choosing a signal
- **WHEN** the player chooses a signal
- **THEN** the van travels to that land, generating only what is still missing on its path, and the destination is ready when the travel sequence ends

#### Scenario: Variety
- **WHEN** signals are offered on several consecutive nights
- **THEN** they do not all come from the same galaxy or concern the same kind of trouble

#### Scenario: Signals avoid Prime
- **WHEN** signals are generated on any night
- **THEN** none of them lies in the Prime universe

### Requirement: Logbook
The console SHALL list every visited land with its name and world, and the player SHALL be able to travel back to any of them.

#### Scenario: Going back
- **WHEN** the player chooses a land in the logbook
- **THEN** the van travels there
