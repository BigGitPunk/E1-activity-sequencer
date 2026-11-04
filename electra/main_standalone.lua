local seq = (function()
local M = {}

M.STEPS = 16
M.PPQN = 24
M.STEP_TICKS = 6

local steps = {}
local noteActPC = {}
local noteActOct = {}
local noteActAbs = {}
local active = {}

local g = {
  activity = 127,
  length = M.STEPS,
  direction = "forward",
  pendDir = 1,
  noteMode = "pc+oct",
  playing = false,
  tick = 0,
  pos = 1,
}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.init()
  steps = {}
  for i = 1, M.STEPS do
    steps[i] = { note = 59 + i, velocity = 100, gate = true, gateLen = M.STEP_TICKS, activity = 0 }
  end
  noteActPC = {}
  for i = 0, 11 do noteActPC[i] = 0 end
  noteActOct = {}
  for i = 0, 10 do noteActOct[i] = 0 end
  noteActAbs = {}
  for i = 0, 127 do noteActAbs[i] = 0 end
  active = {}
  g.activity = 127
  g.length = M.STEPS
  g.direction = "forward"
  g.pendDir = 1
  g.noteMode = "pc+oct"
  g.playing = false
  g.tick = 0
  g.pos = 1
end

function M.noteActivity(note)
  local pc = note % 12
  local oct = math.floor(note / 12)
  if g.noteMode == "pc" then
    return noteActPC[pc]
  elseif g.noteMode == "pc+oct" then
    return clamp(noteActPC[pc] + noteActOct[oct], 0, 127)
  elseif g.noteMode == "abs" then
    return noteActAbs[note]
  end
  return 0
end

function M.stepPlays(i)
  local s = steps[i]
  if s == nil or not s.gate then return false end
  if s.activity > g.activity then return false end
  return M.noteActivity(s.note) <= g.activity
end

local function advance()
  if g.direction == "forward" then
    g.pos = g.pos + 1
    if g.pos > g.length then g.pos = 1 end
  elseif g.direction == "backward" then
    g.pos = g.pos - 1
    if g.pos < 1 then g.pos = g.length end
  elseif g.direction == "pendulum" then
    g.pos = g.pos + g.pendDir
    if g.pos > g.length then
      g.pos = g.length
      g.pendDir = -1
    elseif g.pos < 1 then
      g.pos = 1
      g.pendDir = 1
    end
  end
end

function M.tick()
  local events = {}
  if not g.playing then return events end
  for i = #active, 1, -1 do
    if active[i].offTick <= g.tick then
      events[#events + 1] = { type = "off", note = active[i].note }
      table.remove(active, i)
    end
  end
  if g.tick % M.STEP_TICKS == 0 then
    local s = steps[g.pos]
    if s ~= nil and M.stepPlays(g.pos) then
      events[#events + 1] = { type = "on", note = s.note, velocity = s.velocity, step = g.pos }
      active[#active + 1] = { note = s.note, offTick = g.tick + s.gateLen }
    end
    advance()
  end
  g.tick = g.tick + 1
  return events
end

function M.start()
  g.playing = true
end

function M.stop()
  g.playing = false
  active = {}
end

function M.reset()
  g.tick = 0
  if g.direction == "backward" then
    g.pos = g.length
  else
    g.pos = 1
  end
  g.pendDir = 1
  active = {}
end

function M.setStep(i, field, value)
  if steps[i] ~= nil then steps[i][field] = value end
end

function M.getStep(i)
  return steps[i]
end

function M.setGlobalActivity(v)
  g.activity = clamp(math.floor(v), 0, 127)
end

function M.getGlobalActivity()
  return g.activity
end

function M.setNoteMode(m)
  g.noteMode = m
end

function M.getNoteMode()
  return g.noteMode
end

function M.setNoteActivityPC(pc, v)
  noteActPC[pc % 12] = clamp(math.floor(v), 0, 127)
end

function M.setNoteActivityOct(oct, v)
  noteActOct[clamp(math.floor(oct), 0, 10)] = clamp(math.floor(v), 0, 127)
end

function M.setNoteActivityAbs(note, v)
  noteActAbs[clamp(math.floor(note), 0, 127)] = clamp(math.floor(v), 0, 127)
end

function M.setDirection(d)
  g.direction = d
end

function M.setLength(n)
  g.length = clamp(math.floor(n), 1, M.STEPS)
end

function M.state()
  return {
    playing = g.playing,
    tick = g.tick,
    pos = g.pos,
    activity = g.activity,
    length = g.length,
    direction = g.direction,
    noteMode = g.noteMode,
  }
end

M.init()

return M

end)()


transport = transport or {}

local outChannel = 1
local clockMode = "ext"
local bpm = 120
local clockTimer = nil

local NOTE_NAMES = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }
local DIRECTIONS = { "forward", "backward", "pendulum" }
local MODES = { "pc", "pc+oct", "abs" }
local CLOCKMODES = { "ext", "int" }

function formatNote(controlId, value)
  local n = math.floor(value + 0.5)
  return NOTE_NAMES[(n % 12) + 1] .. tostring(math.floor(n / 12) - 1)
end

local function setControlValue(id, v)
  local ok, c = pcall(controls.get, id)
  if ok and c then
    pcall(function() c:setValue(v) end)
  end
end

local function cycle(list, current)
  for i, v in ipairs(list) do
    if v == current then return list[i % #list + 1] end
  end
  return list[1]
end

local function tickOnce()
  local events = seq.tick()
  for _, e in ipairs(events) do
    if e.type == "on" then
      midi.sendNoteOn(PORT_1, outChannel, e.note, e.velocity)
    elseif e.type == "off" then
      midi.sendNoteOff(PORT_1, outChannel, e.note, 0)
    end
  end
end

local function tickIntervalUs()
  return math.floor(60000000 / (bpm * seq.PPQN) + 0.5)
end

local function onTimerTick()
  if seq.state().playing then
    tickOnce()
  end
end

local function stopIntClock()
  if clockTimer then
    pcall(function() clockTimer:stop() end)
    clockTimer = nil
  end
end

local function startIntClock()
  if not (Timer and Timer.new) then return end
  stopIntClock()
  clockTimer = Timer.new(onTimerTick, tickIntervalUs())
  pcall(function() clockTimer:start() end)
end

local function refreshIntClock()
  if clockMode == "int" and seq.state().playing then
    startIntClock()
  else
    stopIntClock()
  end
end

local function startTransport()
  seq.reset()
  seq.start()
  refreshIntClock()
end

local function stopTransport()
  seq.stop()
  stopIntClock()
end

local function handleChange(id, value)
  if id >= 1 and id <= 16 then
    seq.setStep(id, "note", math.floor(value))
  elseif id >= 101 and id <= 116 then
    if value >= 1 then
      local s = id - 100
      local st = seq.getStep(s)
      if st then
        seq.setStep(s, "gate", not st.gate)
        setControlValue(id, st.gate and 1 or 0)
      end
    end
  elseif id >= 201 and id <= 216 then
    seq.setStep(id - 200, "activity", math.floor(value))
  elseif id >= 301 and id <= 312 then
    seq.setNoteActivityPC(id - 301, value)
  elseif id >= 401 and id <= 411 then
    seq.setNoteActivityOct(id - 401, value)
  elseif id == 501 then
    seq.setGlobalActivity(value)
  elseif id == 502 then
    seq.setLength(math.floor(value))
  elseif id == 503 then
    outChannel = math.floor(value) + 1
  elseif id == 504 then
    bpm = math.min(300, math.max(30, math.floor(value)))
    refreshIntClock()
  elseif id == 601 and value >= 1 then
    startTransport()
  elseif id == 602 and value >= 1 then
    stopTransport()
  elseif id == 603 and value >= 1 then
    seq.setDirection(cycle(DIRECTIONS, seq.state().direction))
  elseif id == 604 and value >= 1 then
    seq.setNoteMode(cycle(MODES, seq.getNoteMode()))
  elseif id == 605 and value >= 1 then
    clockMode = cycle(CLOCKMODES, clockMode)
    refreshIntClock()
  end
end

function valuesChanged(values)
  if type(values) ~= "table" then return end
  for k, v in pairs(values) do
    local id, val
    if type(v) == "table" then
      id, val = v.controlId, v.value
    else
      id, val = k, v
    end
    if id ~= nil and val ~= nil then
      handleChange(id, val)
    end
  end
end

function transport.onClock()
  if clockMode == "int" then return end
  tickOnce()
end

function transport.onStart()
  startTransport()
end

function transport.onStop()
  stopTransport()
end

function transport.onContinue()
  seq.start()
  refreshIntClock()
end

function init()
  seq.init()
  if type(requestValues) == "function" then
    pcall(requestValues)
  end
end

ACTSEQ = seq
