# Architecture Proposal: Scalable Quickshell Ecosystem

This document outlines a unified, future-proof folder structure and naming convention for the Quickshell configuration repository. The goal is to ensure that as the project grows from simple menus to a full desktop environment replacement, the paths and names remain consistent and logical.

## 1. Proposed Core Naming
Standardizing the names of current modules using **CamelCase** to reflect their exact function for easier maintenance.

| Current Folder Name | Current Main File | Proposed Folder Name | Proposed Main File | Rationale |
| :--- | :--- | :--- | :--- | :--- |
| `audio-menu` | `Main.qml` | `MediaControl` | `Main.qml` | Practical name for controlling audio streams and playback. |
| `network-menu` | `Main.qml` | `ConnectionManager` | `Main.qml` | Clearly describes its role in managing Wi-Fi and Bluetooth. |

---

## 2. Directory Structure
A categorized hierarchy using CamelCase for all future modules.

```text
quickshell/
├── assets/             # Global icons, images, and font files.
├── core/               # Shared logic and global styling.
│   ├── components/     # Reusable UI parts (Buttons, Sliders, Cards).
│   ├── theme/          # Global colors, typography, and spacing variables.
│   └── utils/          # Common JavaScript helpers.
├── modules/            # On-demand "Flyouts" (launched via shortcut/click).
│   ├── MediaControl/   # Formerly audio-menu.
│   ├── ConnectionManager/ # Formerly network-menu.
│   ├── PowerMenu/      # Session management (Lock, Logout, Shutdown).
│   └── QuickSettings/  # Toggles (DND, Night Light, Brightness).
├── shell/              # Persistent components (always running).
│   ├── TaskBar/        # The main Panel (Waybar replacement).
│   ├── DesktopDock/    # App dock / pinned items.
│   └── DesktopWidgets/ # Desktop widgets (Clock, System Monitors).
├── panels/             # Large interactive side/floating panels.
│   ├── NotificationCenter/ # Unified Notification system.
│   ├── AiSidebar/      # The AI interaction/API integration panel.
│   └── SystemDashboard/ # Full overview of the system status.
├── apps/               # Complex overlays and interactive tools.
│   ├── AppLauncher/    # App Drawer / Search.
│   ├── CommandPalette/ # Runner for quick actions.
│   ├── ThemeSelector/  # Wallpaper and Theme chooser.
│   └── SystemMonitor/  # Detailed resource tracking.
└── scripts/            # Unified entry points and helpers.
    ├── modules/
    │   └── launch.sh   # specialized: "Rectangular Path" & Cursor math.
    ├── shell/
    │   └── launch.sh   # specialized: Static positioning for Bar/Widgets.
    ├── apps/
    │   └── launch.sh   # specialized: Centered/Full-screen overlays.
    └── setup/          # Configuration and installation helpers.
```

---

## 3. Hybrid Script Architecture
Instead of a single global launcher, we use **Category Launchers** to isolate specialized behaviors.

| Launcher Path | Behavior Style | Best For |
| :--- | :--- | :--- |
| `scripts/modules/launch.sh` | **Flyout** (Centered/Clamped) | MediaControl, ConnectionManager, PowerMenu. |
| `scripts/shell/launch.sh` | **Static** (Fixed anchor) | TaskBar, DesktopWidgets. |
| `scripts/apps/launch.sh` | **Overlay** (Centered/Modal) | AppLauncher, CommandPalette. |

### Key Advantage for Updaters:
By passing the **Sub-Path** (e.g., `modules/launch.sh MediaControl`), the script automatically:
1. Locates the correct `Main.qml`.
2. Generates a unique lockfile based on the name (e.g., `QuickshellMediaControl.lock`).
3. Applies the correct mathematical model (Rectangular Path vs Static).

---

## 4. Migration Strategy
To avoid breaking current Hyprland/Waybar integrations during this transition:
1. **The Launchers**: Create the specialized `launch.sh` scripts in their respective category folders.
2. **Paths**: Use `$QS_CONFIG_DIR` internally so that moving the whole `quickshell` folder doesn't break relative imports.
3. **Hyprland Update**: Update bindings to point to the new category launchers.

## 5. Verification
- [ ] Confirm `ConnectivityHub` and `MediaCenter` names are acceptable.
- [ ] Verify that the `modules/`, `shell/`, `panels/`, and `apps/` categorization covers all future ideas.
- [ ] Ensure the script logic can dynamically resolve paths within this structure.
