# Design

## Context

Phases 10 and 21 record changes, outcomes and character memory; phase 19–20 provide the history engine and tensions.

## Goals / Non-Goals

**Goals:** visible, believable consequences that bring the player back.
**Non-Goals:** simulating unvisited places over time.

## Decisions

- **Clock**: each land record stores the night of the last visit; elapsed nights map to local days (Juniper lands on the same night-to-day ratio everywhere, about a week per night) for the aftermath.
- **Aftermath**: the land-level chronicle engine runs from the stored state for the elapsed time with the player's outcomes as inputs; its results (population, buildings, relationships, new or resolved tensions) are written as changes.
- **Spread**: deeds get a fame value; neighbouring lands, the country and higher levels receive rumour events (distorted by cultural memory) when they are generated or revisited; fame decays with distance; faction attitudes adjust.
- **Marks**: aftermath rules add features (monument, shrine, mural, renamed settlement, festival in the calendar) built with phase 18 builders in the local style.
- **Follow-ups**: aftermath emits needs and invitations into a queue; the signal selector reserves one slot for them.

## Risks / Trade-offs

- [Aftermath cost on arrival] → simulated during the travel vortex; capped steps.
