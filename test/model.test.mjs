import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

const source = readFileSync(new URL('../MediaModel.js', import.meta.url), 'utf8')
const model = vm.createContext({})
vm.runInContext(source.replace(/^\.pragma library\s*/, ''), model)

const spotify = {
  dbusName: 'spotify', trackTitle: 'Governator', trackArtist: 'Green Day',
  trackArtUrl: 'file:///covers/american-idiot.jpg', length: 150,
  lengthSupported: true, isPlaying: false
}
const browserMirror = {
  dbusName: 'chromium', trackTitle: 'Governator · Green Day', trackArtist: '',
  trackArtUrl: 'file:///tmp/.org.chromium.browser.png', length: 150,
  lengthSupported: true, isPlaying: true
}
const podcast = {
  dbusName: 'firefox', trackTitle: 'Episode 12', trackArtist: 'Radio',
  trackArtUrl: '', length: 720, lengthSupported: true, isPlaying: true
}

assert.deepEqual(Array.from(model.candidates([spotify, browserMirror])), [spotify])
assert.equal(model.pickPlayer([spotify, podcast], 'spotify'), spotify)
assert.equal(model.pickPlayer([spotify, podcast], ''), podcast)
assert.equal(model.formatTime(3701), '1:01:41')
assert.equal(model.formatTime(71), '1:11')
