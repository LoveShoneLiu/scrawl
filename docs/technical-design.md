# Scrawl — Technical design

| | |
|------|------|
| Version | v0.1 |
| Date | 2026-08-28 |
| Related | [requirements.md](./requirements.md) |
| Platform | iPad, iPadOS 17.0+ |
| Stack | Swift + SwiftUI + PencilKit + SpriteKit |
| Network | None. No network permission, no server |

---

## 1. Principles

| Principle | Meaning |
|------|------|
| System canvas | PencilKit owns stroke feel; do not invent prediction |
| Sprites from doodles | Pond beings are bitmap sprites of the child’s marks |
| Local only | PNG + JSON in Application Support |
| Open and play | No account, permission sheets, or tutorial |
| Hide system tools | Never show `PKToolPicker` |

### Choices

SwiftUI app shell; `PKCanvasView` for paper; crayon + sketch inks; SpriteKit pond; `FileManager` + Codable; `UserDefaults` for sound; in-memory WAV + `AVAudioPlayer`; light haptics.

**Do not use:** React Native, CloudKit, Core Data, Game Center, analytics SDKs, system PencilKit toolbar.

### Locked product decisions

| Item | Decision |
|------|----------|
| Paper after put-in | Clear |
| Unsaved strokes | Not persisted |
| Orientation | iPad; portrait and landscape supported in current build |
| Put-in | Large button on the paper/pond seam |
| Capacity | 10 |
| Settings | Long-press speaker ~1.2s; empty pond needs confirm |
| Music | None |
| Save failure | Silent for the child; parent settings copy |
| OS | iPadOS 17.0 (`PKInkType.crayon`) |

Parent settings copy is **English**.

---

## 2. Hard parts

### Hide the system picker

`PKCanvasView` as first responder tries to show `PKToolPicker`. Hold a hidden picker, set it invisible, and keep restoring our crayon/sketch + width so the picker cannot steal the tool.

### Doodle → creature

Render `PKDrawing` (+ stamps) to PNG, scale into the pond (~120–160pt long side), write `creatures/{uuid}.png` and `world.json`. SpriteKit uses that texture. Never swap in a stock character.

Put-in to first enter motion: target ≤ 0.3s.

### Motion and cap

Each creature is an `SKSpriteNode`. Wander in the pond rect; tap bounce; at 10, oldest swims off and its PNG is deleted.

### Persistence

Live pond is in memory only. Launch always starts empty.

Parent **Save this pond** writes `Application Support/Scrawl/snapshots/{id}/` (`world.json` + PNGs + `thumb.png`) and `snapshots.json`. Cap 16 saved ponds; oldest is removed when full. A leftover `world.json` from older builds is migrated into one saved pond, not restored into the live pond.

Paper `PKDrawing` is not saved.

---

## 3. Modules

| Module | Role |
|------|------|
| `ScrawlApp` | Entry; injects stores |
| `PlayView` | Only play screen |
| `DrawingCanvas` | PencilKit bridge; hide picker; lock tool |
| `DrawingSession` | Current drawing, undo, new paper, export |
| `PondScene` | Swim, tap, enter/leave, skill toys, fishing play |
| `WorldStore` | Live pond (memory), saved ponds, empty, skill pulse |
| `SoundPlayer` | Short sounds; follows mute |
| `ParentSettingsView` | Sound, save/open/delete ponds, empty, save status |

---

## 4. Constraints

iPad only (`TARGETED_DEVICE_FAMILY = 2`). UI, PencilKit, and SpriteKit on the main thread. Hard cap 10 creatures. No URLSession. Play is icon-based; settings strings are English.

---

## 5. Engineering checks

1. Cold start: draw with no login.
2. Color → draw → put in → **same doodle** swims.
3. Empty put-in: no new creature, no error copy.
4. Kill and relaunch: pond is empty, paper is blank. Saved ponds stay in parent settings.
5. 11th put-in: oldest leaves.
6. Long-press speaker: mute and empty pond.
7. Fish toy: tap to drop hook, tap again to cancel; catch goes into the pond net.
8. Save next to undo writes a snapshot (doodles + netted fish). Launch still starts empty.

Implementation follows this note. If play changes, update [requirements.md](./requirements.md) too.
