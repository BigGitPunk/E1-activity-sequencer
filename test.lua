local seq = require("core")

local passed, failed = 0, 0

local function check(name, cond)
  if cond then
    passed = passed + 1
    print("PASS  " .. name)
  else
    failed = failed + 1
    print("FAIL  " .. name)
  end
end

local function runTicks(n)
  local ons, offs = {}, {}
  for _ = 1, n do
    for _, e in ipairs(seq.tick()) do
      if e.type == "on" then ons[#ons + 1] = e
      elseif e.type == "off" then offs[#offs + 1] = e end
    end
  end
  return ons, offs
end

-- 1. init defaults
seq.init()
check("init: 16 steps, note 59+i, gate on, gateLen 6",
  seq.STEPS == 16
  and seq.getStep(1).note == 60
  and seq.getStep(16).note == 75
  and seq.getStep(1).gate == true
  and seq.getStep(1).gateLen == 6
  and seq.getStep(1).activity == 0)

-- 2. noteActivity: pc mode
seq.init()
seq.setNoteMode("pc")
seq.setNoteActivityPC(0, 40)
check("noteActivity pc: C = 40, C# = 0",
  seq.noteActivity(60) == 40 and seq.noteActivity(61) == 0)

-- 3. noteActivity: pc+oct additive, clamped to 127
seq.init()
seq.setNoteActivityPC(1, 100)
seq.setNoteActivityOct(5, 80)
check("noteActivity pc+oct: additive clamp 127",
  seq.noteActivity(61) == 127
  and seq.noteActivity(60) == 80
  and seq.noteActivity(72) == 0)

-- 4. noteActivity: abs mode
seq.init()
seq.setNoteMode("abs")
seq.setNoteActivityAbs(64, 55)
check("noteActivity abs: note 64 = 55, note 65 = 0",
  seq.noteActivity(64) == 55 and seq.noteActivity(65) == 0)

-- 5. stepPlays: gate
seq.init()
seq.setStep(1, "gate", false)
check("stepPlays: gate off -> no play", seq.stepPlays(1) == false)

-- 6. stepPlays: step activity
seq.init()
seq.setGlobalActivity(64)
seq.setStep(1, "activity", 65)
check("stepPlays: step activity > ACT -> no play", seq.stepPlays(1) == false)

-- 7. stepPlays: note activity (AND rule)
seq.init()
seq.setGlobalActivity(64)
seq.setNoteActivityOct(5, 100)
check("stepPlays: note activity > ACT -> no play", seq.stepPlays(1) == false)

-- 8. one bar: global 64, step activity 0,8,...,120 -> steps 1-9 fire
seq.init()
seq.setGlobalActivity(64)
for i = 1, 16 do seq.setStep(i, "activity", (i - 1) * 8) end
seq.start()
local ons = runTicks(96)
check("one bar: 9 note-ons (steps 1-9)", #ons == 9 and ons[1].step == 1 and ons[9].step == 9)

-- 9. note activity: oct 5 = 100, ACT 64 -> only steps 13-16
seq.init()
seq.setGlobalActivity(64)
seq.setNoteActivityOct(5, 100)
seq.start()
ons = runTicks(96)
check("one bar: only steps 13-16 fire", #ons == 4
  and ons[1].step == 13 and ons[4].step == 16)

-- 10. gateLen: note-off 3 ticks after note-on
seq.init()
seq.setLength(1)
seq.setStep(1, "gateLen", 3)
seq.start()
local events = {}
for t = 1, 6 do
  for _, e in ipairs(seq.tick()) do events[#events + 1] = { t = t, e = e } end
end
check("gateLen: on at tick 1, off at tick 4 (3 ticks later)",
  #events == 2
  and events[1].t == 1 and events[1].e.type == "on"
  and events[2].t == 4 and events[2].e.type == "off")

-- 11. backward starts on step 16
seq.init()
seq.setDirection("backward")
seq.reset()
seq.start()
ons = runTicks(6)
check("backward: first note-on is step 16", #ons == 1 and ons[1].step == 16)

-- 12. stop -> no events
seq.init()
seq.start()
seq.stop()
local any = false
for _ = 1, 24 do
  if #seq.tick() > 0 then any = true end
end
check("stop: no events while stopped", any == false)

-- 13. pendulum, length 4: 1,2,3,4,4,3
seq.init()
seq.setDirection("pendulum")
seq.setLength(4)
seq.start()
local order = {}
for _ = 1, 6 * 6 do
  for _, e in ipairs(seq.tick()) do
    if e.type == "on" then order[#order + 1] = e.step end
  end
end
check("pendulum: 1,2,3,4,4,3",
  #order == 6
  and table.concat(order, ",") == "1,2,3,4,4,3")

-- 14. forward wraps at length
seq.init()
seq.setLength(4)
seq.start()
runTicks(6 * 4)
local pos = seq.state().pos
check("forward: pos wraps to 1 after length", pos == 1)

-- 15. setLength clamps to 1..16
seq.init()
seq.setLength(0)
local lo = seq.state().length
seq.setLength(17)
local hi = seq.state().length
check("setLength: clamped to 1..16", lo == 1 and hi == 16)

-- 16. reset: forward -> pos 1, backward -> pos = length
seq.init()
seq.reset()
local fwdPos = seq.state().pos
seq.setDirection("backward")
seq.reset()
local bwdPos = seq.state().pos
check("reset: pos 1 forward, pos length backward", fwdPos == 1 and bwdPos == 16)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
