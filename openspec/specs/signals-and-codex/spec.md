# signals-and-codex Specification

## Purpose
Lets the player reach the cosmos through Juniper: nightly signals from places in trouble, a logbook of visited places to return to, and later a codex of discovered lore.

## Requirements

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

### Requirement: Follow-up signals
At least one signal per night SHALL come from a visited place when any visited place has a new need or invitation caused by the player's earlier actions.

#### Scenario: Invitation
- **WHEN** a town founded a festival in the player's honour
- **THEN** a signal invites the player to the festival

### Requirement: Codex
The codex SHALL contain entries for discovered places, factions, species, religions, languages, individuals, events, creatures and traditions, cross-linked to each other and to their causes; entries SHALL be unlocked by visiting, talking, reading inscriptions and observing.

#### Scenario: Unlocking by conversation
- **WHEN** a villager tells the player about a saint
- **THEN** the saint's codex entry is unlocked with the villager's version of the story

#### Scenario: Asking why
- **WHEN** the player opens the "why" view of a tradition
- **THEN** it lists the religious, historical and environmental facts that caused it

### Requirement: Belief and truth
For historical topics the codex SHALL show what the people believe and, where Juniper knows it, what really happened.

#### Scenario: Juniper's correction
- **WHEN** a codex entry describes a legend that differs from the true record and Juniper has knowledge of it
- **THEN** the entry shows both versions

### Requirement: Codex access
The codex SHALL be reachable from the van console and the pause menu and usable with keyboard, gamepad and touch.

#### Scenario: Touch
- **WHEN** the player opens the codex on a phone
- **THEN** entries can be browsed and followed by tapping
