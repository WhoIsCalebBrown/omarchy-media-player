import QtQuick
import QtQuick.Effects

// Keep player content at its target size while the rounded shell animates.
Item {
  id: slot

  property bool active: false
  property bool blurTransition: true

  // Centered, but on whole device pixels (the parent says how big one is),
  // so text and edges inside don't land between pixels.
  readonly property real dpr: parent && parent.dpr > 0 ? parent.dpr : 1
  x: parent ? Math.round((parent.width - width) / 2 * dpr) / dpr : 0
  y: parent ? Math.round((parent.height - height) / 2 * dpr) / dpr : 0
  opacity: active ? 1 : 0
  scale: active ? 1 : 0.86
  visible: opacity > 0.01
  enabled: active

  Behavior on opacity {
    SequentialAnimation {
      PauseAnimation { duration: slot.active ? 40 : 0 }
      NumberAnimation { duration: slot.active ? 240 : 80; easing.type: Easing.OutCubic }
    }
  }

  Behavior on scale {
    SequentialAnimation {
      PauseAnimation { duration: slot.active ? 40 : 0 }
      NumberAnimation { duration: slot.active ? 380 : 90; easing.type: slot.active ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 }
    }
  }

  layer.enabled: blurTransition && opacity > 0.01 && opacity < 0.99
  layer.effect: MultiEffect {
    blurEnabled: true
    blurMax: 32
    blur: 1 - slot.opacity
  }
}
