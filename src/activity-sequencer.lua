-- E1 Activity Sequencer
-- A step sequencer for the Electra One MIDI controller.
--
-- Each step can carry a note activity (on/off), velocity and gate length.
-- The sequencer runs from the Electra One MIDI clock and sends notes to a
-- configurable MIDI channel and port.
--
-- Controls (pots on the current page):
--   Pot 1: step select / edit
--   Pot 2: note number of the selected step
--   Pot 3: velocity of the selected step
--   Pot 4: gate length of the selected step
--   Pot 5: playback tempo divisor (1/1, 1/2, 1/4 ...)
--   Pot 6: output MIDI channel
--
-- See the Electra One Lua reference for the exact runtime API:
-- https://electra.one/learn-more/

local STEPS = 16
local PPQN = 24

local NOTE_OFF = 0
local NOTE_ON = 1

local sequencer = {
    bpm = 120,
    divisor = 4,            -- clock ticks per step (24 / divisor)
    running = false,
    currentStep = 1,
    lastStepTime = 0,
    tickCounter = 0,
    channel = 1,
    notes = {},
    velocity = {},
    gate = {},
    active = {},
    heldNote = nil,
}

local function initSteps()
    for i = 1, STEPS do
        sequencer.notes[i] = 60
        sequencer.velocity[i] = 100
        sequencer.gate[i] = 50
        sequencer.active[i] = NOTE_OFF
    end
end

local function stepDuration()
    return math.floor(PPQN / sequencer.divisor)
end

local function noteOffHeld()
    if sequencer.heldNote then
        midi.sendNoteOff(sequencer.channel, sequencer.heldNote.note, 0)
        sequencer.heldNote = nil
    end
end

local function triggerStep(step)
    if sequencer.active[step] == NOTE_ON then
        noteOffHeld()
        midi.sendNoteOn(sequencer.channel, sequencer.notes[step], sequencer.velocity[step])
        sequencer.heldNote = {
            note = sequencer.notes[step],
            offAt = sequencer.tickCounter
                + math.max(1, math.floor(stepDuration() * sequencer.gate[step] / 100)),
        }
    end
end

local function advanceStep()
    sequencer.currentStep = (sequencer.currentStep % STEPS) + 1
    triggerStep(sequencer.currentStep)
end

function onStart()
    sequencer.running = true
    sequencer.tickCounter = 0
    sequencer.currentStep = STEPS
    advanceStep()
end

function onStop()
    sequencer.running = false
    noteOffHeld()
end

function onContinue()
    sequencer.running = true
end

function onClock()
    if not sequencer.running then
        return
    end

    sequencer.tickCounter = sequencer.tickCounter + 1

    if sequencer.heldNote and sequencer.tickCounter >= sequencer.heldNote.offAt then
        noteOffHeld()
    end

    if sequencer.tickCounter % stepDuration() == 0 then
        advanceStep()
    end
end

function onPotMove(potId, midiValue)
    local step = math.floor(midiValue / 127 * (STEPS - 1)) + 1

    if potId == 1 then
        sequencer.selectedStep = step
    elseif sequencer.selectedStep then
        local s = sequencer.selectedStep
        if potId == 2 then
            sequencer.notes[s] = midiValue
        elseif potId == 3 then
            sequencer.velocity[s] = midiValue
        elseif potId == 4 then
            sequencer.gate[s] = midiValue
        elseif potId == 5 then
            sequencer.divisor = math.max(1, math.min(PPQN, midiValue))
        elseif potId == 6 then
            sequencer.channel = math.floor(midiValue / 127 * 15) + 1
        end
    end
end

function onReceiveMidi(message)
    if message:type() == "NOTE_ON" and message:velocity() > 0 then
        local step = sequencer.selectedStep or 1
        sequencer.notes[step] = message:note()
        sequencer.active[step] = NOTE_ON
    elseif message:type() == "NOTE_OFF" then
        -- leaving activity untouched; steps are toggled from the controller UI
    end
end

function onInit()
    initSteps()
    sequencer.selectedStep = 1
end
