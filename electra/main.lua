local seq = require("core")

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
