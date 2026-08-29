# Scrawl — Product requirements

| | |
|------|------|
| Version | v0.1 |
| Date | 2026-08-28 |
| Working name | Scrawl (folder `scrawl`) |
| Form | Local iPad app |
| Age | About 3 years old |
| Core value | A scribble counts: draw a mark, put it in the pond, it comes alive |

---

## 1. Overview

A parent wants an iPad toy for a 3-year-old who loves drawing. The fun is **making marks**, not drawing well or filling a template.

Coloring books and levels turn drawing into a task. A blank canvas has no “what happens after I draw.” This product adds that beat: **drawing is input; a living doodle in a small world is feedback.**

### Goals

- Draw with a finger and immediately see the doodle live in the pond.
- No reading, no failure, no scores, no timer.
- Fully offline: no ads, no account, data stays on device.
- Prove the loop: does a 3-year-old draw another page because “it came alive”?

### Positioning

A cause-and-effect scribble toy. Success is “she drew another one and put it in,” not whether the picture is recognizable.

---

## 2. Users and scenes

| Role | Need |
|------|------|
| Child (~3) | Huge color dots, huge buttons, scribbles celebrated, easy new paper |
| Parent | Offline, no ads, no outbound links, doodles still there, emptying the pond gated |

Typical: sofa play (draw → put in → watch it swim); show a parent; open next day and the pond is still there; waiting rooms with no network.

---

## 3. Scope

### MVP

- One screen: paper on top, pond below.
- 4–8 fat color dots; finger drawing; no nested tool menus.
- **Put in**: current paper becomes one living doodle in the pond.
- Short enter animation and sound; tap it to bounce.
- Any scribble lives; no shape recognition.
- Empty paper: put-in shakes, no lecture.
- Paper clears after put-in.
- Pond persists after kill.
- Cap (~10): oldest swims off when full.
- New paper; sound on/off.
- Offline; no account, ads, or IAP.

### Out of MVP

Fill-in outlines, levels, stars, scores, AI recognition, complex toolbars, accounts, cloud, ads, analytics, requiring Apple Pencil.

### Later (not MVP)

Weather pens, parent voice notes, photo of the pond (gated), optional Pencil.

---

## 4. Behaviors

- Launch straight into paper + pond. No tutorial, login, or permission sheets.
- Restore pond creatures; paper starts blank.
- Huge hit targets (~120pt). Play loop uses icons, not sentences.
- Color, draw, undo, new paper, put in.
- One paper = one doodle. Looks like the child’s marks, never a stock character.
- Tap a doodle: bounce + sound. Tap water: nothing bad.
- Parent settings: long-press speaker ~1.2s. Sound toggle; empty pond with confirm.
- Save failure: silent for the child; visible only in parent settings.

---

## 5. Success

1. Child can draw and put in with almost no spoken steps.
2. She can tell it is **her** drawing, and taps it or draws another.
3. Parent never feels a “you did it wrong” moment.
4. Pond still has doodles after relaunch.

---

## 6. Privacy and tone

No personal data collection, no upload, no third-party analytics. Calm pond, short round sounds, no chase/fight/death. Oldest doodle **leaves**, it is not punished.

---

*Direction confirmed 2026-08-28: 3-year-old daughter, loves drawing, iPad, make a game.*
