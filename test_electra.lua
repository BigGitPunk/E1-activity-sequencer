local passed, failed = 0, 0
local midiLog = {}

PORT_1 = 1
transport = {}

midi = {
  sendNoteOn = function(port, ch, note, vel)
    midiLog[#midiLog + 1] = { type = "on", port = port, ch = ch, note = note, vel = vel }
  end,
  sendNoteOff = function(port, ch, note, vel)
    midiLog[#midiLog + 1] = { type = "off", port = port, ch = ch, note = note, vel = vel }
  end,
}

local controlValues = {}
local controlStubs = {}
controls = {
  get = function(id)
    if controlStubs[id] == nil then
      controlStubs[id] = {
        setValue = function(_, v) controlValues[id] = v end,
      }
    end
    return controlStubs[id]
  end,
}

Timer = { last = nil }
function Timer.new(callback, interval)
  local t = {
    callback = callback,
    interval = interval,
    running = false,
  }
  function t:start() self.running = true end
  function t:stop() self.running = false end
  function t:fire()
    if self.running then self.callback() end
  end
  Timer.last = t
  return t
end

local requestValuesCalled = false
function requestValues()
  requestValuesCalled = true
end

local function check(name, cond)
  if cond then
    passed = passed + 1
    print("PASS  " .. name)
  else
    failed = failed + 1
    print("FAIL  " .. name)
  end
end

local function countOns()
  local n = 0
  for _, m in ipairs(midiLog) do
    if m.type == "on" then n = n + 1 end
  end
  return n
end

dofile(arg and arg[1] or "electra/main.lua")

local seq = ACTSEQ or require("core")

-- 1-3. formatNote
check("formatNote: 60 = C4", formatNote(0, 60) == "C4")
check("formatNote: 61 = C#4", formatNote(0, 61) == "C#4")
check("formatNote: 72 = C5", formatNote(0, 72) == "C5")

-- 4-7. valuesChanged mapping
valuesChanged({ [501] = 64 })
check("valuesChanged: ACT 64", seq.getGlobalActivity() == 64)

valuesChanged({ [3] = 42 })
check("valuesChanged: step 3 note = 42", seq.getStep(3).note == 42)

valuesChanged({ [101] = 1 })
check("valuesChanged: gate 1 toggled off, button set to 0",
  seq.getStep(1).gate == false and controlValues[101] == 0)
valuesChanged({ [101] = 1 })
check("valuesChanged: gate 1 toggled on again", seq.getStep(1).gate == true)

valuesChanged({ { controlId = 503, value = 4 } })
seq.setStep(1, "note", 60)
transport.onStart()
for _ = 1, 6 do transport.onClock() end
transport.onStop()
local chFound = false
for _, m in ipairs(midiLog) do
  if m.type == "on" and m.ch == 5 then chFound = true end
end
check("valuesChanged: CH 4 -> notes on channel 5", chFound)

-- 8-10. mode / dir / clk cycles
valuesChanged({ [604] = 1 })
check("MODE cycle: pc+oct -> abs", seq.getNoteMode() == "abs")
valuesChanged({ [604] = 1 })
check("MODE cycle: abs -> pc", seq.getNoteMode() == "pc")
valuesChanged({ [604] = 1 })
check("MODE cycle: pc -> pc+oct", seq.getNoteMode() == "pc+oct")

valuesChanged({ [603] = 1 })
check("DIR cycle: forward -> backward", seq.state().direction == "backward")
valuesChanged({ [603] = 1 })
check("DIR cycle: backward -> pendulum", seq.state().direction == "pendulum")
valuesChanged({ [603] = 1 })
check("DIR cycle: pendulum -> forward", seq.state().direction == "forward")

-- 11-14. one bar via external clock
seq.init()
valuesChanged({ [501] = 64 })
seq.setStep(3, "gate", false)
seq.setStep(5, "activity", 100)
valuesChanged({ [503] = 4 })
transport.onStart()
midiLog = {}
for _ = 1, 96 do transport.onClock() end
check("ext clock: one bar -> 14 note-ons", countOns() == 14)
local allCh5 = true
for _, m in ipairs(midiLog) do
  if m.type == "on" and m.ch ~= 5 then allCh5 = false end
end
check("ext clock: all note-ons on channel 5", allCh5)
check("ext clock: pos = 1 after one bar", seq.state().pos == 1)
transport.onStop()
midiLog = {}
for _ = 1, 96 do transport.onClock() end
check("stop: no events after stop", #midiLog == 0)

-- 15-17. internal clock
valuesChanged({ [605] = 1 })
transport.onStart()
check("int clock: Timer started", Timer.last ~= nil and Timer.last.running == true)
check("int clock: interval 20833 us at 120 BPM", Timer.last.interval == 20833)
valuesChanged({ [504] = 240 })
check("int clock: interval 10417 us at 240 BPM", Timer.last.interval == 10417)
valuesChanged({ [504] = 120 })

-- 18-20. timer ticks drive the sequencer
midiLog = {}
for _ = 1, 96 do Timer.last:fire() end
check("int clock: 96 timer ticks -> 14 note-ons", countOns() == 14)
midiLog = {}
for _ = 1, 96 do transport.onClock() end
check("int clock: external onClock ignored in int mode", #midiLog == 0)
transport.onStop()
check("int clock: stop stops the timer", Timer.last ~= nil and Timer.last.running == false)
valuesChanged({ [605] = 1 })

-- 21. PLAY resets the sequencer
transport.onStart()
for _ = 1, 10 do transport.onClock() end
transport.onContinue()
local tickBefore = seq.state().tick
transport.onStart()
check("PLAY: resets tick counter", seq.state().tick == 0 and seq.state().playing == true)
transport.onStop()

-- 22. continue keeps position
transport.onStart()
for _ = 1, 12 do transport.onClock() end
transport.onStop()
transport.onContinue()
for _ = 1, 6 do transport.onClock() end
check("CONTINUE: keeps playing after stop/continue", seq.state().playing == true)
transport.onStop()

-- 23. init / requestValues
init()
check("init: sequencer reinitialized and requestValues called",
  requestValuesCalled == true and seq.state().playing == false)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
