# Spec Delta

## ADDED Requirements

### Requirement: Buildings at human scale
Generated buildings SHALL be sized from the height of the people who build them: storeys of at least 1.75 times their height (and at least 3 m), doors of 1.25 times their height, and footprints by kind (an 8 x 6 m cottage, a 10 x 8 m two-storey village house, a 14 x 9 m barn, a 14 x 24 m temple for 1.7 m tall people).

#### Scenario: A village house
- **WHEN** a village house of 1.7 m tall people is generated
- **THEN** it is about 10 m wide, 8 m deep and two storeys high, and its door is about 2.1 m tall

#### Scenario: A giant people
- **WHEN** a people 2.5 m tall builds a house
- **THEN** its storeys and doors are proportionally larger

### Requirement: Buildings larger than one model
Buildings longer than 24 m SHALL be assembled from several models that join without gaps.

#### Scenario: A long hall
- **WHEN** a 40 m hall is placed
- **THEN** it consists of joined modules with continuous walls and roof
