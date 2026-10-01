import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import "views"
import "MediaModel.js" as Model

// A media-only panel. It draws over the Omarchy bar without reserving space.
Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "whoiscalebbrown.media-player"
  property var settings: ({})
  property bool barTransparent: false

  function setting(key, fallback) {
    var value = settings ? settings[key] : undefined
    return value === undefined || value === null ? fallback : value
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var config = {}
      try { config = JSON.parse(text()) } catch (error) {}
      var entries = config && Array.isArray(config.plugins) ? config.plugins : []
      root.settings = entries.find(function(entry) { return entry && entry.id === root.pluginId }) || ({})
      root.barTransparent = !!(config.bar && config.bar.transparent)
    }
  }

  readonly property real scaleFactor: Math.max(0.6, Math.min(2, Number(setting("scale", 1)) || 1))
  readonly property int topMargin: s(Number(setting("topMargin", 0)))
  readonly property string monitorSetting: String(setting("monitor", "primary"))
  readonly property bool expandOnHover: setting("expandOnHover", false) === true
  readonly property bool artworkTint: setting("visualizerColor", "accent") === "artwork"
  readonly property bool blackBackground: setting("background", "theme") === "black"
  readonly property string fontFamily: Style.font.family
  readonly property string textFamily: setting("textFont", "theme") === "theme" ? fontFamily : String(setting("textFont", "theme"))
  readonly property color accentColor: Color.accent
  readonly property real dpr: win.devicePixelRatio > 0 ? win.devicePixelRatio : 1

  function s(px) { return Math.round(Style.space(px) * scaleFactor) }
  function f(px) { return Math.max(6, Math.round(px * Style.fontScale * scaleFactor)) }
  function snap(px) { return Math.round(px * dpr) / dpr }

  readonly property var players: Mpris.players ? Mpris.players.values : []
  property string currentPlayerKey: ""
  property int playerTick: 0
  readonly property var player: { playerTick; return Model.pickPlayer(players, currentPlayerKey) }
  readonly property var mediaSources: { playerTick; return Model.candidates(players) }
  readonly property string mediaSourceKey: Model.playerKey(player)
  onPlayerChanged: Qt.callLater(function() {
    if (root.player) root.currentPlayerKey = Model.playerKey(root.player)
  })

  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() {
        if (modelData.isPlaying && Model.candidates(root.players).indexOf(modelData) !== -1)
          root.currentPlayerKey = Model.playerKey(modelData)
        root.playerTick++
      }
      function onTrackTitleChanged() { root.playerTick++ }
      function onTrackArtistChanged() { root.playerTick++ }
    }
  }

  readonly property bool hasMedia: player !== null
  readonly property bool mediaPlaying: player ? player.isPlaying : false
  readonly property string mediaTitle: player ? (player.trackTitle || "") : ""
  readonly property string mediaArtist: player ? (player.trackArtist || "") : ""
  readonly property string mediaArt: player ? (player.trackArtUrl || "") : ""
  property string retainedMediaArt: ""
  onMediaArtChanged: if (mediaArt !== "") retainedMediaArt = mediaArt
  readonly property real mediaLength: player && player.lengthSupported ? player.length : 0
  readonly property bool mediaCanSeek: !!player && player.canSeek && player.positionSupported
  readonly property bool mediaCanNext: !!player && player.canGoNext
  readonly property bool mediaCanPrevious: !!player && player.canGoPrevious
  readonly property bool mediaVolumeSupported: !!player && player.canControl && player.volumeSupported
  property real pendingMediaVolume: -1
  property string pendingMediaVolumeKey: ""
  readonly property real mediaVolume: pendingMediaVolume >= 0 && pendingMediaVolumeKey === mediaSourceKey
    ? pendingMediaVolume : (mediaVolumeSupported ? player.volume : 0)
  property real mediaPosition: 0

  Timer { id: mediaVolumeFlush; interval: 60; onTriggered: root.flushMediaVolume() }

  function flushMediaVolume() {
    mediaVolumeFlush.stop()
    if (pendingMediaVolume >= 0 && pendingMediaVolumeKey === mediaSourceKey && mediaVolumeSupported)
      player.volume = pendingMediaVolume
    pendingMediaVolume = -1
  }

  function setMediaVolume(value, finalChange) {
    if (!mediaVolumeSupported) return
    pendingMediaVolumeKey = mediaSourceKey
    pendingMediaVolume = Math.max(0, Math.min(1, value))
    if (finalChange) flushMediaVolume()
    else mediaVolumeFlush.restart()
  }

  function selectMediaSource(source) {
    if (!source) return
    flushMediaVolume()
    currentPlayerKey = Model.playerKey(source)
    mediaPosition = 0
  }

  function mediaToggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
  function mediaNext() { if (mediaCanNext) player.next() }
  function mediaPrevious() { if (mediaCanPrevious) player.previous() }
  function mediaSeek(fraction) {
    if (!mediaCanSeek || mediaLength <= 0) return
    var target = Math.max(0, Math.min(1, fraction)) * mediaLength
    player.position = target
    mediaPosition = target
  }

  Timer {
    interval: 500
    repeat: true
    running: root.hasMedia && root.expanded && !root.outputsOpen
    triggeredOnStart: true
    onTriggered: {
      if (root.player && root.player.positionSupported) {
        root.player.positionChanged()
        root.mediaPosition = root.player.position
      }
    }
  }

  ColorQuantizer {
    id: quantizer
    source: root.artworkTint && root.mediaArt ? root.mediaArt : ""
    depth: 3
    rescaleSize: 64
  }

  readonly property color mediaTint: {
    if (!artworkTint) return accentColor
    var best = null
    var score = 0
    var colors = quantizer.colors || []
    for (var i = 0; i < colors.length; i++) {
      var color = colors[i]
      if (color.hsvValue < 0.35) continue
      var value = color.hsvSaturation * color.hsvValue
      if (value > score) { best = color; score = value }
    }
    return best && score > 0.12
      ? Qt.hsva(best.hsvHue, Math.max(0.45, best.hsvSaturation), Math.max(0.75, best.hsvValue), 1)
      : accentColor
  }

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audioOutputs: Pipewire.nodes ? Pipewire.nodes.values.filter(function(node) {
    return node && node.isSink && !node.isStream && node.audio
  }) : []
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  property bool outputsOpen: false
  property bool expanded: false
  readonly property bool opened: expanded

  function outputGlyph(node) {
    if (!node) return "󰓃"
    var label = (String(node.name || "") + " " + String(node.description || "")).toLowerCase()
    if (/bluez|headphone|headset/.test(label)) return "󰋋"
    if (/hdmi|displayport/.test(label)) return "󰡁"
    return "󰓃"
  }

  function outputLabel(node) {
    var name = String(node && (node.description || node.nickname || node.name) || "")
    var first = name.split(" ")[0]
    var group = audioOutputs.map(function(item) { return String(item.description || item.nickname || item.name || "") })
      .filter(function(label) { return label.split(" ")[0] === first })
    if (group.length < 2) return name
    var words = name.split(" ")
    var common = 0
    while (common < words.length - 1 && group.every(function(label) {
      var parts = label.split(" ")
      return parts.length > common + 1 && parts[common] === words[common]
    })) common++
    return words.slice(common).join(" ") || name
  }

  function selectOutput(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSink = node
    closeOutputs()
  }

  function openOutputs() { outputsOpen = true; expanded = true }
  function closeOutputs() { outputsOpen = false }
  function expand() { if (hasMedia) expanded = true }
  function collapse() { outputsOpen = false; expanded = false }
  function toggle() { if (expanded) collapse(); else expand() }
  function open() { expand() }
  function close() { collapse() }

  readonly property string view: !hasMedia ? "hidden" : !expanded ? "compact" : outputsOpen ? "outputs" : "expanded"
  readonly property var viewSize: {
    if (view === "compact") return { w: 300, h: 32, r: 16 }
    if (view === "outputs") return { w: 392, h: 62 + Math.max(1, Math.min(6, audioOutputs.length)) * 44, r: 36 }
    if (view === "expanded") return mediaSources.length > 1
      ? { w: 404, h: 260 + Math.min(3, mediaSources.length) * 30, r: 42 }
      : { w: 404, h: 230, r: 42 }
    return { w: 0, h: 32, r: 16 }
  }
  readonly property real expansionProgress: Math.max(0, Math.min(1, (stage.h - s(32)) / s(40)))
  readonly property bool mediaBackdropMode: retainedMediaArt !== "" && (view === "expanded"
    || (view === "compact" && stage.h > s(33)))
  readonly property real barSurfaceOpacity: mediaBackdropMode
    ? 0.85 * expansionProgress * expansionProgress : expansionProgress
  readonly property color surface: blackBackground ? "#000000" : Qt.rgba(
    Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, barSurfaceOpacity)
  readonly property color fg: blackBackground ? "#f5f5f7" : (barTransparent && expansionProgress < 0.5
    ? Qt.rgba(Color.bar.background.r, Color.bar.background.g, Color.bar.background.b, 1) : Color.bar.text)
  readonly property color fgDim: Util.alpha(fg, 0.6)
  readonly property color rim: Util.alpha(fg, blackBackground ? 0.08 : 0.1)
  function bodyAt() { return surface }
  readonly property bool shapeSettled: Math.abs(stage.w - s(viewSize.w)) < s(18)
    && Math.abs(stage.h - s(viewSize.h)) < s(12)

  readonly property var targetScreen: {
    var screens = Quickshell.screens
    if (!screens || !screens.length) return null
    var wanted = monitorSetting
    if (wanted === "focused" && Hyprland.focusedMonitor) wanted = Hyprland.focusedMonitor.name
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === wanted) return screens[i]
    return screens[0]
  }

  IpcHandler {
    target: "media-player"
    function expand(): string { root.expand(); return "ok" }
    function collapse(): string { root.collapse(); return "ok" }
    function toggle(): string { root.toggle(); return "ok" }
    function state(): string { return JSON.stringify({ view: root.view, playing: root.mediaPlaying,
      title: root.mediaTitle, sources: root.mediaSources.length, monitor: win.screen ? win.screen.name : null }) }
  }

  PanelWindow {
    id: win
    screen: root.targetScreen
    anchors { top: true; left: true; right: true }
    margins.top: -Style.bar.sizeHorizontal
    implicitHeight: root.s(400) + root.topMargin
    color: "transparent"
    WlrLayershell.namespace: "media-player"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    mask: Region { item: pill }

    Item {
      id: stage
      anchors.fill: parent
      property real w: root.s(root.viewSize.w)
      property real h: root.s(root.viewSize.h)
      property real r: root.s(root.viewSize.r)
      Behavior on w { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
      Behavior on h { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
      Behavior on r { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

      ClippingRectangle {
        id: pill
        x: root.snap(Number(root.setting("leftOffset", 0)))
        y: root.snap(Style.bar.sizeHorizontal + root.topMargin)
        width: root.snap(Math.max(0, stage.w))
        height: root.snap(Math.max(0, stage.h))
        radius: Math.max(0, Math.min(stage.r, height / 2, width / 2))
        color: root.surface
        border.width: 1
        border.color: root.rim
        contentUnderBorder: true
        opacity: width < 4 ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 160 } }

        HoverHandler { id: hover }

        Image {
          id: mediaWashSource
          anchors.fill: parent
          source: root.retainedMediaArt
          sourceSize.width: 96
          sourceSize.height: 96
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          retainWhileLoading: true
          visible: false
        }

        MultiEffect {
          anchors.fill: parent
          source: mediaWashSource
          blurEnabled: true
          blur: 1
          blurMax: 64
          saturation: 0.45
          opacity: root.mediaBackdropMode ? 0.95 * root.expansionProgress : 0
          visible: opacity > 0
        }

        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(Color.bar.background.r, Color.bar.background.g,
            Color.bar.background.b, root.mediaBackdropMode ? 0.62 * root.expansionProgress : 0)
          visible: root.mediaBackdropMode && root.expansionProgress > 0
        }

        Item {
          id: content
          readonly property real dpr: root.dpr
          width: pill.width
          height: pill.height

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (mouse.button === Qt.MiddleButton) root.mediaToggle()
              else root.toggle()
            }
            onWheel: function(wheel) {
              if (root.sink && root.sink.audio && wheel.angleDelta.y !== 0) {
                root.sink.audio.muted = false
                root.sink.audio.volume = Math.max(0, Math.min(1,
                  root.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
              }
            }
          }

          ViewSlot {
            active: root.view === "compact" && root.shapeSettled
            blurTransition: false
            width: root.s(300); height: root.s(32)
            MediaCompact { anchors.fill: parent; island: root }
          }
          ViewSlot {
            active: root.view === "expanded" && root.shapeSettled
            blurTransition: false
            width: root.s(root.viewSize.w); height: root.s(root.viewSize.h)
            MediaExpanded { anchors.fill: parent; island: root }
          }
          ViewSlot {
            active: root.view === "outputs" && root.shapeSettled
            blurTransition: false
            width: root.s(root.viewSize.w); height: root.s(root.viewSize.h)
            OutputsView { anchors.fill: parent; island: root }
          }
        }
      }
    }
  }

  Timer {
    id: collapseTimer
    interval: 500
    onTriggered: if (!hover.hovered) root.collapse()
  }
  Timer {
    id: hoverExpandTimer
    interval: 380
    onTriggered: if (hover.hovered && !root.expanded) root.expand()
  }
  Connections {
    target: hover
    function onHoveredChanged() {
      if (hover.hovered) {
        collapseTimer.stop()
        if (root.expandOnHover) hoverExpandTimer.restart()
      } else {
        hoverExpandTimer.stop()
        if (root.expanded) collapseTimer.restart()
      }
    }
  }
}
