# AnalogPad

AnalogPad is a tactile, card-based task app for iPad inspired by Ugmonk’s Analog System. It keeps you focused on what matters today, keeps “Next” nearby (but out of your way), and lets “Someday” ideas wait patiently. You get the analog feel (cards, stacks, dots) with digital conveniences (local persistence, drag-and-drop, and quick signals).

---

## Why you'll like it
- **Today-first**: A hard cap of ~10 tasks on the Today card so you can’t overstuff your day.
- **Card stacks**: Today, Next, Someday live in a split view with a collapsible sidebar (full titles → compact → initials as space tightens).
- **Task signals**: Tap to cycle empty → in progress → delegated → done; move tasks with swipes or drag-and-drop between stacks.
- **Close the day**: Archive Today with one tap; unfinished tasks roll into Next. Archive keeps your streaks.
- **Productivity dots**: 1–3 dots per card to rate your day; shows in the archive list.
- **Local-first**: State is stored locally (JSON) so your board comes back exactly as you left it.

---

## Quick start (Xcode)
1) Open `AnalogPad/AnalogPad.xcodeproj` in Xcode.  
2) Choose an iPad simulator (e.g., iPad Pro 11").  
3) Run (⌘R). The app boots with sample Today/Next/Someday cards ready to interact with.

---

## How to use it
- **Add tasks**: Type into the “Add a task” field; Today enforces the 10-task limit.
- **Mark progress**: Tap the signal icon on each task to cycle status; or swipe leading to complete.
- **Move tasks**: Drag-and-drop between stacks or use swipe actions (send to Today/Next/Someday).
- **Close day**: In the toolbar (or swipe action on Today in the sidebar), close the day to archive and roll incomplete tasks to Next.
- **Sidebar sizing**: Drag the split; as space shrinks, the sidebar auto-switches to titles-only, then initials (T/N/S) to avoid truncation.

---

## What’s next (roadmap)
- Tags/filters and search across active + archived cards
- Reminders and gentle nudges
- PencilKit handwriting + text recognition
- Export (PDF/Markdown) and iCloud sync
- Weekly/monthly review with streaks and dots charts

---

## Support & feedback
Found a rough edge or want a feature prioritized? Open an issue or drop a note—this app is evolving with real workflows in mind.
