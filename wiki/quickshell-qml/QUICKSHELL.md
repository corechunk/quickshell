# Quickshell Specific Components

Quickshell adds custom objects to standard QML to allow interaction with the Linux system (Wayland, Shell, Files).

## 1. ShellRoot
The root object of any Quickshell configuration. It manages the lifecycle of the shell.

## 2. PanelWindow
A specialized window for shell components (bars, menus, etc.).
- **WlrLayershell.layer**: Determines if the window is behind windows (`Background`) or on top of them (`Overlay`).
- **WlrLayershell.keyboardFocus**: Controls if the window can receive typing.

## 3. Variants
A powerful object used to repeat a window across multiple monitors.
```qml
Variants {
    model: Quickshell.screens // Repeat for every monitor
    delegate: PanelWindow { ... }
}
```

## 4. Process
The way Quickshell runs shell commands.
```qml
Process {
    command: ["notify-send", "Hello"]
    running: true // Starts the command
}
```

## 5. FileWatcher & Io
Used to read files and watch for changes (essential for our Wallust integration).
```qml
FileWatcher {
    path: "/path/to/file"
    onFileChanged: console.log("File updated!")
}
```
