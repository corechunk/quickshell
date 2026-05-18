# Architecture: Scalable Quickshell Ecosystem

This document outlines the unified folder structure and naming convention for the Quickshell configuration repository.

## 1. Directory Structure
A categorized hierarchy using CamelCase for all modules.

```text
quickshell/
├── assets/             # Global icons, images, and font files.
├── core/               # Shared logic and global styling.
│   ├── components/     # Reusable UI parts (Buttons, Sliders, Cards).
│   ├── theme/          # Global colors, typography, and spacing variables.
│   └── utils/          # Common JavaScript helpers.
├── modules/            # On-demand "Flyouts" (launched via shortcut/click).
│   ├── MediaControl/
│   ├── ConnectionManager/
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

## 2. Hybrid Script Architecture
Instead of a single global launcher, we use **Category Launchers** to isolate specialized behaviors.

| Launcher Path | Behavior Style | Best For |
| :--- | :--- | :--- |
| `scripts/modules/launch.sh` | **Flyout** (Centered/Clamped) | MediaControl, ConnectionManager, PowerMenu. |
| `scripts/shell/launch.sh` | **Static** (Fixed anchor) | TaskBar, DesktopWidgets. |
| `scripts/apps/launch.sh` | **Overlay** (Centered/Modal) | AppLauncher, CommandPalette. |

### Key Advantage:
By passing the **Sub-Path** (e.g., `modules/launch.sh MediaControl`), the script automatically:
1. Locates the correct `Main.qml`.
2. Generates a unique lockfile based on the name (e.g., `QuickshellMediaControl.lock`).
3. Applies the correct mathematical model (Rectangular Path vs Static).
