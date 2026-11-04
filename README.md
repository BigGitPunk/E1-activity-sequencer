# E1 Activity Sequencer

A step sequencer ("activity sequencer") for the [Electra One](https://electra.one/) MIDI controller, written as an Electra One Lua preset.

## Features

- 16 steps, each with note, velocity and gate length ("activity" per step)
- Runs from the Electra One MIDI clock (`onStart` / `onStop` / `onContinue` / `onClock`)
- Configurable clock divisor (1/1 … 1/24) per step
- Configurable output MIDI channel
- Incoming note events set the note of the selected step

## Controls

| Pot | Function |
|-----|----------|
| 1   | Step select / edit |
| 2   | Note number of the selected step |
| 3   | Velocity of the selected step |
| 4   | Gate length of the selected step |
| 5   | Clock divisor (ticks per step) |
| 6   | Output MIDI channel |

## Installation

1. Open the Electra One Web Editor (Chrome-based browser, Web MIDI).
2. Create a new preset with at least six pots on the first page.
3. Open the preset's Lua script editor and paste the contents of
   [`src/activity-sequencer.lua`](src/activity-sequencer.lua).
4. Upload the preset to the controller.

The script uses the Electra One controller Lua runtime; see the
[Lua reference](https://electra.one/learn-more/) for the full API.

## Repository layout

```
src/activity-sequencer.lua   # the preset Lua script
```

## License

MIT
