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

### Requirement: Traditions and calendar
Each culture SHALL have a calendar built from its planet's day, year and moons, holidays tied to astronomical events and commemorations of its history, rites of passage, funeral customs fitting its land, food customs and taboos tied to real local species and dangers.

#### Scenario: Commemoration
- **WHEN** a culture's history contains a great flood that ended an era
- **THEN** it can have a holiday commemorating the flood on the flood's date in its calendar

#### Scenario: Funeral fits the land
- **WHEN** a culture lives in high mountains with little soil
- **THEN** its funeral customs do not rely on burial in deep earth

#### Scenario: Taboo with a reason
- **WHEN** a culture has a food taboo
- **THEN** it is linked to a real local species, a religious doctrine or a historic event

### Requirement: Values and society
Each culture SHALL have values and a social structure derived from its species' social instincts, its environment's pressures and its history (for example hierarchy versus equality, honour versus harmony), and these SHALL influence its laws, factions and how its people treat strangers.

#### Scenario: Scarcity
- **WHEN** a culture formed in a harsh desert
- **THEN** customs of hospitality and water sharing are likely

### Requirement: Technology and magic traditions
A culture's technology level SHALL emerge from available resources and fuels, domesticable species, trade contacts, stability and magic availability; where magic or psionics exist, cultures SHALL develop traditions of their use that interact with their technology.

#### Scenario: Iron needs iron
- **WHEN** a culture's lands contain no accessible iron and it has no trade contacts
- **THEN** it does not develop iron working

#### Scenario: Magic instead of machines
- **WHEN** magic is strong and common in a culture's lands
- **THEN** some of its technologies are replaced or complemented by magical traditions

### Requirement: Architecture and dress
Each culture SHALL have an architecture style and dress derived from local materials (rock types, timber, hides), climate (roof pitch, wall thickness), anatomy (door and seat shapes, entry for flyers), religion (temple form and orientation) and technology level.

#### Scenario: Local stone
- **WHEN** a land's bedrock is red sandstone
- **THEN** stone buildings of its culture are built in red sandstone colours

#### Scenario: Flyers
- **WHEN** a culture's species can fly
- **THEN** its buildings have entrances from above
