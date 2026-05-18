# Caelestia Launcher & Command Palette Logic

The Command Palette is the "brain" of the Caelestia shell. It uses a prefix-based system to switch modes.

## 1. Prefix Modes
The launcher watches the first few characters of the input:

| Prefix | Mode | Description |
| :--- | :--- | :--- |
| `>` | **Action Mode** | Searches custom system actions (Lock, Reboot). |
| `!` | **Advanced App Search** | Searches app categories, keywords, or exec strings. |
| `!t` | **Terminal Mode** | Filters for applications that run in a terminal. |

## 2. Logic Implementation
The search logic is handled in `Searcher.qml`.
- **`transformSearch(input)`**: Strips the prefix (like `>`) so the search engine only sees the actual word (e.g., "Lock" instead of ">Lock").
- **`query(input)`**:
    1. Checks for prefix.
    2. Adjusts search "Weights" (e.g., if searching by category, give category names 90% priority).
    3. Returns a filtered list to the UI.

## 3. Autocomplete Feature
Some actions in the Caelestia palette don't execute a command immediately. Instead, they "Autocomplete."
- Example: You type `>Theme`. An action appears: "Switch Theme".
- Clicking it changes your input to `>Theme ` (adding a space) and shows a list of available themes.
