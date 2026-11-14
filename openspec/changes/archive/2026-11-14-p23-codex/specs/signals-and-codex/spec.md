# Spec Delta

## ADDED Requirements

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
