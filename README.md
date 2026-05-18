<div align="center">

# ❄️ corechunk / quickshell
### *Modern QML-based Shell Modules & Widgets*
### -----> This proj is incomplete. All of these are mostly planning and main plan is in plan.md <-----
#### -----> We only have two modules right now. so, usable .. and u can try them <-----

---

[![Version](https://img.shields.io/badge/version-1.0.0.0-blue?style=for-the-badge&logo=gitbook&logoColor=white)](https://github.com/corechunk/quickshell)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/platform-linux-lightgrey?style=for-the-badge&logo=linux&logoColor=white)](https://www.kernel.org/)
[![Quickshell](https://img.shields.io/badge/built_with-quickshell-A371F7?style=for-the-badge&logo=qt)](https://github.com/outfoxxed/quickshell)
[![License](https://img.shields.io/badge/license-MIT-red?style=for-the-badge)](./LICENSE)

[📦 Installation](#-installation) • [🚀 Usage](#-usage) • [🛠️ Features](#-features) • [📋 Dependencies](#-dependencies) • [📂 Structure](#-project-structure)

---

</div>

## 📖 Overview

Welcome to **quickshell**, a collection of modular QML widgets designed for modern Wayland environments. These modules are specifically crafted to integrate seamlessly with **Hyprland** dotfiles while remaining completely standalone for any setup using `quickshell`.

This repository provides highly interactive and aesthetic menus for networking and audio control, powered by the performance of QML.

---

## 🖼️ Screenshots

<div align="center">
  <img src="https://via.placeholder.com/800x450?text=Quickshell+Audio+Menu+Preview" width="400" />
  <img src="https://via.placeholder.com/800x450?text=Quickshell+Network+Menu+Preview" width="400" />
  <p><i>(Screenshots coming soon! Replace these placeholders with your actual rices.)</i></p>
</div>

---

## 🛠️ Features

- **📶 Connection Manager**: A full-featured Wi-Fi and Bluetooth manager using `nmcli` and Quickshell's Bluetooth modules.
- **🔊 Media Control**: Dynamic media controls and volume management with `playerctl` and metadata support.
- **🚀 Smart Installer**: A feature-rich bash script that automates the deployment and management of your configuration.
- **❄️ Unified Architecture**: Scalable folder structure (`modules/`, `shell/`, `panels/`, `apps/`) designed for future expansion.
- **🎨 Rectangular Path logic**: Advanced positioning that centers on click and clamps to screen edges (e.g., Waybar zones) with consistent margins.
- **💾 Automatic Backups**: Every install triggers a backup of your current configuration, ensuring you can always revert.

---

## 📋 Dependencies

To ensure all modules work correctly, please install the following:

| Component | Purpose | Package (Arch) |
| :--- | :--- | :--- |
| **Quickshell** | Core runtime for QML modules | `quickshell-git` |
| **NetworkManager** | Backend for network management | `networkmanager` |
| **Playerctl** | Media control backend | `playerctl` |
| **jq** | JSON processing for scripts | `jq` |
| **Libnotify** | Desktop notifications | `libnotify` |
| **Hyprland** | Window manager (optional but recommended) | `hyprland` |

*Note: QML modules like `QtQuick.Layouts` and `QtQuick.Controls` are required (usually provided by `qt6-declarative`).*

---

## 📂 Project Structure

```bash
.
├── modules/                    # On-demand Flyout modules
│   ├── MediaControl/           # Media playback and metadata
│   └── ConnectionManager/      # Wi-Fi and Bluetooth management
├── core/                       # Shared UI components and global Theme
├── shell/                      # Persistent elements (TaskBar, Widgets)
├── panels/                     # Side/Floating panels (AI Sidebar)
├── apps/                       # Overlays (AppLauncher, ThemeSelector)
├── scripts/                    # Unified category-based launchers
│   └── modules/launch.sh       # Handles "Rectangular Path" positioning
├── .version                    # Current version of the project
├── installer_quickshell_dots.sh # The core management script
└── README.md                   # This documentation
```

---

## 📦 Installation

To install the modules to your config directory:

```bash
git clone https://github.com/corechunk/quickshell.git
cd quickshell
chmod +x installer_quickshell_dots.sh
./installer_quickshell_dots.sh
```

---

## 🚀 Usage

### 🛠️ Standalone
You can launch any module directly with `quickshell`:
```bash
quickshell -p ~/.config/quickshell/modules/MediaControl/Main.qml
```

### ❄️ Hyprland & Waybar Integration
Use the unified launcher for smart positioning and lock-management:

```bash
# General usage:
# ./scripts/modules/launch.sh [ModuleName] [--fromShortcut]

# 1. Launch at cursor position (Centered + Clamped)
./scripts/modules/launch.sh ConnectionManager

# 2. Launch at fixed position (Bottom-Right corner)
./scripts/modules/launch.sh MediaControl --fromShortcut
```

**Hyprland Bindings:**
```hyprlang
bind = SUPER ALT, N, exec, ~/.config/quickshell/scripts/modules/launch.sh ConnectionManager --fromShortcut
bind = SUPER ALT, A, exec, ~/.config/quickshell/scripts/modules/launch.sh MediaControl --fromShortcut
```

---

## 📐 Versioning System

The installer tracks versions using:
`[Major].[Minor].[Patch].[Hotfix]`

- **Major**: Breaking architectural changes.
- **Minor**: New modules or features.
- **Patch/Hotfix**: Bug fixes and CSS tweaks.

---

## 🤝 Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request for new QML modules or improvements.

---

<div align="center">

### ❄️ Stay Chilly
Built with ❤️ by [netchunk](https://github.com/netchunk)

[Back to Top](#-corechunk--quickshell)

</div>
