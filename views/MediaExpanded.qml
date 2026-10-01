import QtQuick
import qs.Commons
import "../MediaModel.js" as Model

// Expanded player: art, progress, transport, volume, and source selection.
Item {
  id: view

  property var island: null
  readonly property int pad: island.s(22)
  readonly property real progress: island.mediaLength > 0
    ? Math.max(0, Math.min(1, island.mediaPosition / island.mediaLength)) : 0

  AlbumArt {
    id: art
    x: view.pad
    y: island.s(20)
    width: island.s(58)
    height: width
    source: island.mediaArt
    tint: island.accentColor
    fontFamily: island.fontFamily
  }

  Visualizer {
    id: viz
    anchors.right: parent.right
    anchors.rightMargin: view.pad + island.s(2)
    anchors.verticalCenter: art.verticalCenter
    playing: island.mediaPlaying
    color: island.mediaTint
    barWidth: island.s(3)
    maxHeight: island.s(20)
  }

  Column {
    anchors.left: art.right
    anchors.leftMargin: island.s(14)
    anchors.right: viz.left
    anchors.rightMargin: island.s(14)
    anchors.verticalCenter: art.verticalCenter
    spacing: island.s(3)

    Text {
      width: parent.width
      text: island.mediaTitle || "Not playing"
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(17)
      font.weight: Font.DemiBold
      color: island.fg
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: island.mediaArtist
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
      font.family: island.textFamily
      font.pixelSize: island.f(15)
      color: Util.alpha(island.fg, 0.84)
    }
  }

  // Elapsed · bar · remaining
  Item {
    id: progressRow
    x: view.pad
    width: parent.width - view.pad * 2
    y: art.y + art.height + island.s(16)
    height: island.s(16)
    visible: island.mediaLength > 0

    Text {
      id: elapsed
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: Model.formatTime(island.mediaPosition)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(13)
      font.features: { "tnum": 1 }
      color: Util.alpha(island.fg, 0.82)
    }

    Text {
      id: remaining
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: "-" + Model.formatTime(island.mediaLength - island.mediaPosition)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      font.family: island.fontFamily
      font.pixelSize: island.f(13)
      font.features: { "tnum": 1 }
      color: Util.alpha(island.fg, 0.82)
    }

    Item {
      id: track
      anchors.left: elapsed.right
      anchors.leftMargin: island.s(10)
      anchors.right: remaining.left
      anchors.rightMargin: island.s(10)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height

      readonly property real barHeight: seek.containsMouse ? island.s(7) : island.s(5)

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: track.barHeight
        radius: height / 2
        color: Util.alpha(island.fg, 0.32)

        Behavior on height { NumberAnimation { duration: 120 } }

        Rectangle {
          id: played
          height: parent.height
          radius: height / 2
          width: Math.max(view.progress > 0 ? height : 0, parent.width * view.progress)
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Util.alpha(island.fg, 0.55) }
            GradientStop { position: 1; color: island.fg }
          }
        }

        // The playhead.
        Rectangle {
          property real d: seek.containsMouse ? island.s(13) : island.s(9)
          width: d
          height: d
          radius: d / 2
          x: played.width - d / 2
          anchors.verticalCenter: parent.verticalCenter
          color: island.fg
          border.width: Math.max(1, island.s(2))
          border.color: island.bodyAt(0.6)

          Behavior on d { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        }
      }

      MouseArea {
        id: seek
        anchors.fill: parent
        hoverEnabled: true
        enabled: island.mediaCanSeek
        cursorShape: island.mediaCanSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: function(mouse) { island.mediaSeek(mouse.x / width) }
      }
    }
  }

  // MPRIS volume changes this player only. The output picker controls which
  // speakers receive it; scrolling the compact player changes output volume.
  Item {
    id: playerVolume
    x: view.pad
    y: island.s(122)
    width: parent.width - view.pad * 2
    height: island.s(28)
    readonly property real level: Math.max(0, Math.min(1, island.mediaVolume))

    IconButton {
      id: quietVolume
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰕿"
      glyphSize: island.f(16)
      color: island.fg
      fontFamily: island.fontFamily
      available: island.mediaVolumeSupported
      onClicked: island.setMediaVolume(0, true)
    }

    IconButton {
      id: loudVolume
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰕾"
      glyphSize: island.f(16)
      color: island.fg
      fontFamily: island.fontFamily
      available: island.mediaVolumeSupported
      onClicked: island.setMediaVolume(1, true)
    }

    Item {
      id: volumeTrack
      anchors.left: quietVolume.right
      anchors.leftMargin: island.s(4)
      anchors.right: loudVolume.left
      anchors.rightMargin: island.s(4)
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: island.s(6)
        radius: height / 2
        color: Util.alpha(island.fg, island.mediaVolumeSupported ? 0.32 : 0.14)

        Rectangle {
          width: parent.width * playerVolume.level
          height: parent.height
          radius: height / 2
          color: island.fg
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: island.mediaVolumeSupported
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: function(mouse) { island.setMediaVolume(mouse.x / width, false) }
        onPositionChanged: function(mouse) { if (pressed) island.setMediaVolume(mouse.x / width, false) }
        onReleased: function(mouse) { island.setMediaVolume(mouse.x / width, true) }
      }
    }
  }

  // Where the sound goes (speakers, headphones, Bluetooth, HDMI).
  IconButton {
    anchors.right: parent.right
    anchors.rightMargin: view.pad - island.s(8)
    y: island.s(170)
    glyph: island.outputGlyph(island.sink)
    glyphSize: island.f(15)
    color: island.fg
    fontFamily: island.fontFamily
    onClicked: island.openOutputs()
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: island.s(166)
    spacing: island.s(26)

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒮"
      glyphSize: island.f(22)
      color: island.fg
      fontFamily: island.fontFamily
      available: island.mediaCanPrevious
      onClicked: island.mediaPrevious()
    }

    // Play / pause is the one solid control: a disc in the text color.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: island.s(44)
      height: width
      radius: width / 2
      color: island.fg
      scale: playMouse.pressed ? 0.9 : (playMouse.containsMouse ? 1.05 : 1)

      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

      Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: island.mediaPlaying ? 0 : island.s(1)
        text: island.mediaPlaying ? "󰏤" : "󰐊"
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        font.family: island.fontFamily
        font.pixelSize: island.f(22)
        color: island.bodyAt(0.5)
      }

      MouseArea {
        id: playMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: island.mediaToggle()
      }
    }

    IconButton {
      anchors.verticalCenter: parent.verticalCenter
      glyph: "󰒭"
      glyphSize: island.f(22)
      color: island.fg
      fontFamily: island.fontFamily
      available: island.mediaCanNext
      onClicked: island.mediaNext()
    }
  }

  Text {
    x: view.pad
    y: island.s(224)
    visible: island.mediaSources.length > 1
    text: "Audio sources"
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: island.textFamily
    font.pixelSize: island.f(14)
    font.weight: Font.DemiBold
    color: island.fg
  }

  Flickable {
    id: sourceList
    x: view.pad
    y: island.s(246)
    width: parent.width - view.pad * 2
    height: island.s(Math.min(3, island.mediaSources.length) * 30)
    visible: island.mediaSources.length > 1
    clip: true
    contentWidth: width
    contentHeight: sourceRows.height
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: sourceRows
      width: sourceList.width
      spacing: island.s(3)

      Repeater {
        model: island.mediaSources

        Rectangle {
          id: sourceRow
          required property var modelData
          readonly property var source: modelData
          readonly property bool selected: Model.playerKey(source) === island.mediaSourceKey
          width: sourceRows.width
          height: island.s(27)
          radius: island.s(9)
          color: Util.alpha(island.fg, selected ? 0.22 : (sourceMouse.containsMouse ? 0.12 : 0.07))
          border.width: selected ? 1 : 0
          border.color: Util.alpha(island.fg, 0.5)

          Text {
            id: sourceState
            anchors.left: parent.left
            anchors.leftMargin: island.s(9)
            anchors.verticalCenter: parent.verticalCenter
            text: sourceRow.source.isPlaying ? "󰏤" : "󰐊"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            font.family: island.fontFamily
            font.pixelSize: island.f(13)
            color: island.fg
          }

          Text {
            anchors.left: sourceState.right
            anchors.leftMargin: island.s(8)
            anchors.right: sourceName.left
            anchors.rightMargin: island.s(8)
            anchors.verticalCenter: parent.verticalCenter
            text: sourceRow.source.trackTitle || "Untitled media"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            elide: Text.ElideRight
            font.family: island.textFamily
            font.pixelSize: island.f(14)
            font.weight: sourceRow.selected ? Font.DemiBold : Font.Normal
            color: island.fg
          }

          Text {
            id: sourceName
            anchors.right: parent.right
            anchors.rightMargin: island.s(9)
            anchors.verticalCenter: parent.verticalCenter
            width: island.s(80)
            horizontalAlignment: Text.AlignRight
            text: sourceRow.source.identity || sourceRow.source.desktopEntry || "Player"
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            elide: Text.ElideRight
            font.family: island.textFamily
            font.pixelSize: island.f(12)
            color: Util.alpha(island.fg, 0.85)
          }

          MouseArea {
            id: sourceMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.selectMediaSource(sourceRow.source)
          }
        }
      }
    }
  }
}
