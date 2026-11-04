import json

W, H = 800, 480
controls = []

PARAM = 0

def next_param():
    global PARAM
    PARAM += 1
    return PARAM

def ctrl(cid, ctype, name, bounds, vmin, vmax, color, variant=None, formatter=None, potId=None):
    value = {
        "id": "value",
        "min": vmin,
        "max": vmax,
        "message": {
            "deviceId": 1,
            "type": "virtual",
            "parameterNumber": next_param(),
        },
    }
    if formatter:
        value["formatter"] = formatter
    c = {
        "id": cid,
        "type": ctype,
        "name": name,
        "color": color,
        "bounds": bounds,
        "pageId": 1,
        "controlSetId": 1,
        "visible": True,
        "values": [value],
    }
    if variant:
        c["variant"] = variant
    if potId:
        c["inputs"] = [{"potId": potId, "valueId": "value"}]
    controls.append(c)

PC_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

def step_x(i):
    return 4 + (i - 1) * 49

for i in range(1, 17):
    ctrl(i, "fader", "S%d" % i, [step_x(i), 76, 46, 118], 0, 127, "4FC3F7", formatter="formatNote")

for i in range(1, 17):
    ctrl(100 + i, "button", "G%d" % i, [step_x(i), 198, 46, 18], 0, 1, "9E9E9E")

for i in range(1, 17):
    ctrl(200 + i, "fader", "A%d" % i, [step_x(i), 222, 46, 112], 0, 127, "FFB300", variant="thin")

for pc in range(12):
    ctrl(301 + pc, "fader", PC_NAMES[pc], [6 + pc * 64, 340, 58, 64], 0, 127, "69F0AE", variant="thin")

for octv in range(11):
    ctrl(401 + octv, "fader", "O%d" % octv, [6 + octv * 68, 410, 62, 64], 0, 127, "B388FF", variant="thin")

ctrl(501, "fader", "ACT", [8, 8, 150, 60], 0, 127, "FF5252", potId=1)
ctrl(502, "fader", "LEN", [166, 8, 70, 60], 1, 16, "FFD740", potId=2)
ctrl(503, "fader", "CH", [244, 8, 70, 60], 0, 15, "EEEEEE", potId=3)
ctrl(504, "fader", "BPM", [634, 8, 70, 60], 30, 300, "FF9100", potId=4)
ctrl(601, "button", "PLAY", [322, 8, 60, 60], 0, 1, "76FF03")
ctrl(602, "button", "STOP", [390, 8, 60, 60], 0, 1, "FF5252")
ctrl(603, "button", "DIR", [458, 8, 70, 60], 0, 1, "40C4FF")
ctrl(604, "button", "MODE", [536, 8, 90, 60], 0, 1, "E040FB")
ctrl(605, "button", "CLK", [712, 8, 80, 60], 0, 1, "00E5FF")

preset = {
    "version": 3,
    "name": "Activity Sequencer",
    "projectId": "ACTSEQE1",
    "devices": [
        {
            "id": 1,
            "name": "Seq Out",
            "port": 1,
            "channel": 1,
        }
    ],
    "pages": [{"id": 1, "name": "Activity Seq"}],
    "overlays": [],
    "groups": [],
    "controls": controls,
}

with open("electra/preset.json", "w") as f:
    json.dump(preset, f, separators=(",", ":"))

print("controls:", len(controls))
