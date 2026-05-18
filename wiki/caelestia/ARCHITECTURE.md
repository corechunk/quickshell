# Caelestia Shell Architecture Analysis

Caelestia is a highly modular Quickshell project. Its strength lies in how it separates Data, Logic, and UI.

## 1. Key Structure
- **Services**: QML singletons that handle "Work" (e.g., `Apps.qml` fetches app lists, `Actions.qml` handles commands).
- **Components**: Reusable UI parts (buttons, text fields).
- **Modules**: The actual windows (Launcher, Bar).

## 2. The Singleton Engine
Caelestia uses singletons to store the **State** of the shell.
- When you launch a module, it doesn't search for data. It asks a service (like `Searcher.qml`) for the data.
- This allows multiple windows to see the same information simultaneously.

## 3. Dynamic Theming
Uses a custom CSS-like logic linked to Wallust.
- Colors are processed into "Material You" palettes.
- UI elements use these palettes for consistent, automatically generated colors.

## 4. Fuzzy Searching
Unlike most shells that use simple "starts with" logic, Caelestia includes real fuzzy search libraries:
- `fzf.js`: A JavaScript port of the FZF algorithm.
- `fuzzysort.js`: Fast fuzzy searching for JS objects.
