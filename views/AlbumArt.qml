import QtQuick
import qs.Commons

// Show the entire cover inside its tile. ShapePath.fillItem sampled the wrong
// part of some MPRIS images; a regular Image keeps its aspect ratio reliably.
Item {
  id: art

  property string source: ""
  property color tint: Color.accent
  property string fontFamily: Style.font.family
  property real radius: Math.round(width * 0.24)
  property string placeholder: "󰝚"

  readonly property bool themeIcon: source.indexOf("image://icon/") === 0
  readonly property int decodeSize: Math.max(64, Math.ceil(Math.max(width, height) * 2))

  Rectangle {
    anchors.fill: parent
    radius: art.radius
    color: Util.alpha(art.tint, 0.22)
    visible: !art.themeIcon
  }

  Image {
    id: image
    anchors.fill: parent
    source: art.source
    fillMode: Image.PreserveAspectFit
    sourceSize.width: art.decodeSize
    asynchronous: true
    cache: true
    smooth: true
    mipmap: true
  }

  Text {
    anchors.centerIn: parent
    visible: image.status !== Image.Ready
    text: art.placeholder
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: art.fontFamily
    font.pixelSize: Math.round(art.height * 0.5)
    color: art.tint
  }
}
