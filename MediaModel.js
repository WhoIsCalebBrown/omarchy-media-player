.pragma library

function formatTime(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor(total % 3600 / 60)
  var rest = String(total % 60).padStart(2, "0")
  return hours ? hours + ":" + String(minutes).padStart(2, "0") + ":" + rest : minutes + ":" + rest
}

function playerKey(player) {
  return player ? String(player.dbusName || player.identity || "") : ""
}

function isProxy(player) {
  return playerKey(player).toLowerCase().indexOf("playerctld") !== -1
    || String(player && player.desktopEntry || "").toLowerCase() === "playerctld"
}

function richness(player) {
  var art = String(player && player.trackArtUrl || "")
  var realArt = art && !/\/\.(org\.chromium|com\.google\.Chrome|com\.brave|com\.microsoft\.Edge)\./.test(art)
  return (realArt ? 2 : 0) + (player.trackArtist ? 1 : 0)
}

function sameTrack(a, b) {
  var left = String(a.trackTitle || "").toLowerCase().replace(/\s+/g, " ").trim()
  var right = String(b.trackTitle || "").toLowerCase().replace(/\s+/g, " ").trim()
  if (!left || !right || !(left === right || left.startsWith(right) || right.startsWith(left))) return false
  if (a.lengthSupported && b.lengthSupported && a.length > 0 && b.length > 0)
    return Math.abs(a.length - b.length) < 2
  return true
}

function candidates(players) {
  var list = []
  for (var i = 0; i < players.length; i++) {
    var player = players[i]
    if (!player || isProxy(player) || !(player.trackTitle || player.trackArtist)) continue
    var duplicate = -1
    for (var j = 0; j < list.length; j++)
      if (sameTrack(player, list[j])) { duplicate = j; break }
    if (duplicate < 0) list.push(player)
    else if (richness(player) > richness(list[duplicate])) list[duplicate] = player
  }
  return list
}

function pickPlayer(players, currentKey) {
  var list = candidates(players)
  var current = null
  var playing = null
  var fallback = null
  for (var i = 0; i < list.length; i++) {
    var player = list[i]
    if (playerKey(player) === currentKey) current = player
    if (player.isPlaying && (!playing || richness(player) > richness(playing))) playing = player
    if (!fallback || richness(player) > richness(fallback)) fallback = player
  }
  return current || playing || fallback
}
