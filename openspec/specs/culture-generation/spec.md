# culture-generation Specification

## Purpose
Generates the cultures of intelligent species so that their languages, beliefs, customs, technology and buildings follow from their biology, environment and history.

## Requirements

### Requirement: Languages
Each culture SHALL have a language with a sound inventory its speakers' anatomy can produce, a syllable structure and a lexicon with meanings; place, person and god names SHALL be composed from that lexicon so they can be translated.

#### Scenario: Translated name
- **WHEN** a place name is generated
- **THEN** its literal meaning in its language is stored with it

#### Scenario: Beaked speakers
- **WHEN** a species has a beak instead of lips
- **THEN** its language has no sounds that require lips

### Requirement: Language families
When a culture splits, its language SHALL split into daughter languages that drift apart by sound changes, so related cultures have recognisably related names and older places keep older forms.

#### Scenario: Related names
- **WHEN** two cultures descend from the same ancestral people
- **THEN** many of their words and names share roots with regular sound differences

### Requirement: Religions
Religions SHALL arise from what their founders experience: the sky (suns, moons, eclipses, auroras), the land (volcanoes, floods, seasons), their biology (lifespan, death, reproduction), magic or psionics where present, and history (founders, saints, schisms); each has deities or principles, doctrines, sacred places and clergy.

#### Scenario: Moon gods
- **WHEN** a planet has two prominent moons and frequent eclipses
- **THEN** the religions that arise there are likely to feature the moons and treat eclipses as significant

#### Scenario: Real gods
- **WHEN** the universe allows real gods and a religion is widely followed
- **THEN** its deity is marked as real and can act in history
