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
