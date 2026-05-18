# QML Basics for Quickshell

QML is a declarative language used to design user interfaces. It looks like a mix of JSON and CSS, but it has the power of JavaScript.

## 1. Basic Structure
Everything in QML is an **Object**. Objects have **Properties**, **Signals**, and **Methods**.

```qml
Rectangle {          // The Object Type
    id: myRect       // Unique ID to refer to this object
    width: 200       // Property: width
    height: 100      // Property: height
    color: "red"     // Property: color

    Text {           // Nested Child Object
        text: "Hello"
        anchors.centerIn: parent // Positioning relative to parent
    }
}
```

## 2. Properties & Bindings
The most powerful part of QML is **Bindings**. If one property changes, anything linked to it changes automatically.

```qml
Rectangle {
    width: 100
    height: width * 2 // Binding: height is always double the width
}
```

## 3. Interaction
Interaction is handled via `MouseArea` or `Keys`.

```qml
Rectangle {
    width: 100; height: 100
    color: mouse.pressed ? "blue" : "red"

    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: console.log("I was clicked!")
    }
}
```

## 4. Singletons
Singletons are special files that are loaded once and shared everywhere.
- Must have `pragma Singleton` at the top.
- Used for global things like `Theme` or `Settings`.

## 5. JavaScript in QML
You can write JS functions directly inside objects.

```qml
Rectangle {
    function calculateArea() {
        return width * height;
    }
}
```
