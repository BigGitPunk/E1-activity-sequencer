# E1 Activity Sequencer

Ein 16-Step-MIDI-Sequencer („Activity Sequencer") für die [Electra One](https://electra.one/),
inspiriert von der Activity-Funktion des Droid-Motoquencers (Der Mann mit der Maschine).
Activity ist ein deterministischer Schwellenwert – keine Wahrscheinlichkeit.

Später geplant: Adapter für OXI E16 auf demselben `core.lua`.

## Konzept

- **Trigger-Regel:** Step spielt ⇔ `gate == true` UND `step.activity ≤ ACT` (global)
  UND `noteActivity(note) ≤ ACT`
- **Note-Activity:** `MODE` = `pc` (12 Pitch-Classes) / `pc+oct` (additiv, geclampt auf 0–127) /
  `abs` (128 absolute Noten)
- **Clock:** `CLK` = `ext` (MIDI-Clock/Controller-Clock) / `int` (eigener Timer mit BPM)
- **Direction:** `DIR` = forward / backward / pendulum (Endpunkte doppelt: 1,2,3,4,4,3…)
- **Länge:** `LEN` 1–16, pro Step Gate-Länge in Ticks (Note-Off über interne Active-Liste)
- **Timing:** 24 ppqn, 6 Ticks/Step, 96 Ticks/Takt

## Bedienung (Control-IDs)

| Controls    | Funktion                                                    |
|-------------|-------------------------------------------------------------|
| S1–S16      | Step-Noten (Fader, Formatter `formatNote`)                   |
| G1–G16      | Gate-Buttons (Toggle)                                        |
| A1–A16      | Step-Activity (0–127)                                        |
| C…B         | Pitch-Class-Activity (12 Fader)                              |
| O0–O10      | Oktav-Activity (11 Fader, für `pc+oct`)                     |
| ACT         | globale Activity-Schwelle (0–127)                            |
| LEN         | Sequencer-Länge (1–16)                                       |
| CH          | MIDI-Kanal (0–15 → Kanal 1–16)                               |
| BPM         | Tempo für interne Clock (30–300)                            |
| PLAY / STOP | Transport                                                    |
| DIR         | Richtung: forward → backward → pendulum                     |
| MODE        | Note-Activity: pc → pc+oct → abs                             |
| CLK         | Clock: ext → int                                             |

## Upload auf die Electra One

Wichtig: `electra/preset.json` ist ein **Preset-File** (Format-Version 3, wie es die
Firmware liest). Es ist **kein Project-File** – „Import Project" im Editor erwartet das
Project-Format (`.eproj`) und lehnt Preset-JSON ab.

1. Gerät per USB verbinden, in der Electra One App (Chrome/Edge) verbinden, Bank/Slot wählen.
2. Preset in die eigene Preset-Bibliothek importieren (`electra/preset.json`, ggf. als `.epr`)
   und von dort per **„Upload to Slot"** / **„Send to Electra"** in den gewählten Slot laden.
   Alternativ kann das Preset-JSON per SysEx-File-Transfer direkt in einen Slot
   hochgeladen werden.
3. Lua-Script in denselben Slot laden (im Editor am Script des Presets) – entweder
   - `electra/main_standalone.lua` (einfach, Kern eingebettet), oder
   - `electra/main.lua` + `electra/core.lua` als Zusatzdatei.
4. Slot am Gerät auswählen.

MIDI-Out geht auf `PORT_1` (alle Interfaces), Kanal über `CH`.

## Dateien

```
core.lua                     hardware-neutraler Kern (reines Lua, keine Hardware-API)
electra/main.lua             Adapter: require("core") + transport.* + valuesChanged
electra/main_standalone.lua  generiert: gleicher Adapter, Kern eingebettet
electra/core.lua             Kopie des Kerns für den Slot (bei main.lua-Variante)
electra/preset.json          generiert von gen_preset.py (80 Controls, 1 Page, 800×480)
gen_preset.py                Preset-Generator (Layout)
build_standalone.py          erzeugt electra/main_standalone.lua aus core.lua + main.lua
test.lua                     Kern-Tests (16 Checks)
test_electra.lua             Adapter-Tests mit gestubbter Electra-API (27 Checks);
                             arg[1] wählt die Main-Datei (Default electra/main.lua)
```

## Tests

```bash
lua5.4 test.lua                                    # 16 passed
lua5.4 test_electra.lua                            # 27 passed
lua5.4 test_electra.lua electra/main_standalone.lua  # 27 passed
```

`preset.json` und `main_standalone.lua` sind generiert:

```bash
python3 gen_preset.py        # → electra/preset.json (80 Controls)
python3 build_standalone.py  # → electra/main_standalone.lua
```

## Offene Punkte für den Hardware-Test

- ~~JSON-Schema-Details~~ – erledigt: Values tragen jetzt `virtual`-Messages mit
  eindeutiger `parameterNumber`, ein Device ist deklariert, ACT/LEN/CH/BPM liegen auf
  Pot 1–4 (restliche Controls Touch); Layout ist 800×480 (Electra One mini; auf dem
  mk2 mit 1024×600 erscheint es oben links)
- exakte `valuesChanged`-Form (beide Formen werden behandelt), Timer-/`transport.*`-Namen
  (per `pcall` defensiv gekapselt), ob die interne Controller-Clock sauber in
  `transport.onClock` ankommt

## Nächste Ausbaustufen

- OXI-E16-Adapter auf demselben `core.lua` (16 Encoder = 16 Steps, Pages pro Parameter-Ebene)
- Velocity-Page, Pattern-Persistenz (`persist()`/`data.json`), optionaler Probability-Mode

## Lizenz

MIT – siehe [LICENSE](LICENSE).
