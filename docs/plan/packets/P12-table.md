# P12 — Physical sorting table and bird's-eye interaction

Dependencies: P03, P09. Requirements: R12–R14. Read: sorting methods and table defaults.

**Outcome:** both requested sorting interactions operate on the same persistent station contents.

**Own files:** `scenes/stations/sorting_station.tscn`, `scripts/stations/sorting_station.gd`, `scripts/ui/sorting_view.gd`, `scenes/ui/sorting_overlay.tscn`, `table` checks.

**Steps**

1. Build station with table, 240 stable cells, four labelled category bin locations and valuables tray. Art is a wrapper around supplied table/bin candidates or registered cubes. Item proxies can be scaled to cell size without changing physical world definitions.
2. E enters table mode, stows tools, freezes player movement, releases pointer and moves the camera to a readable overhead view. Keep simulation in an explicit table context; world primary/throw cannot run concurrently.
3. Unload transfers the whole bag only when there are enough free cells. Preserve order for deterministic cell assignment. If not, reject unchanged and show how much space is needed. Each item remains an identifiable object with a name/inspection label.
4. Mouse drag uses a transient preview above the table. Valid bin release calls `try_sort`; invalid release/cancel returns to its cell. Selected-bin mode highlights one bin and clicking an item animates it there. Wrong bins accept it and show accuracy feedback without destroying it.
5. Allow correcting unsealed contents: inspect a bin, choose an item and return it to a free cell or move it to another bin through the same methods. If no cell is free, direct bin-to-bin correction remains available. Bin-opening triggers also accept thrown WORLD waste through `try_sort`, honoring capacity and final-category accuracy; they cannot capture through bin walls or accept props/valuables.
6. Controller uses D-pad cell focus, A select, LB/RB category cycling, B back/cancel, with clear selected-bin label. Provide table zoom/pan and matching controller controls without requiring drag input. Retain last focus after a cell empties.
7. Valuables receive identification feedback and move to the labelled valuables tray; selling is implemented by P17. Exit cancels only transient drag and leaves all committed contents at the station.

**Acceptance:** `table` exercises capacity and correction in both interaction modes. Manual controller-only pass can sort and correct every item. Leaving/reentering preserves items; camera/UI input cannot accidentally throw bag contents.

**Handoff:** cell/bin identities, station state schema, selected-bin controls and screenshots at 20 and 200 items.
