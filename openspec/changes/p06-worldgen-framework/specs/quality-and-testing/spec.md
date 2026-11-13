# Spec Delta

## ADDED Requirements

### Requirement: Generation determinism tests
Tests SHALL check that generation is deterministic for a seed on every CI platform (comparing stored fingerprints of reference addresses) and independent of the order in which places are generated.

#### Scenario: Fingerprint mismatch
- **WHEN** a platform produces a different fingerprint for a reference address
- **THEN** CI fails on that platform

### Requirement: Consistency checker
A consistency checker SHALL verify generated places (every commitment honoured, no references to missing entities, chronological order, plus checks registered by generators) and tests SHALL run it over many seeds.

#### Scenario: Broken commitment
- **WHEN** a generator leaves a commitment unhonoured
- **THEN** the consistency test fails naming the commitment

### Requirement: World bible export
A tool SHALL export any address as readable Markdown describing everything generated there and on its path, for review and tuning.

#### Scenario: Reviewing a place
- **WHEN** the exporter runs for an address
- **THEN** it writes a document with one section per generated node on the path and every fact with its causes
