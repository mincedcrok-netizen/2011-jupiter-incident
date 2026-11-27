#!/usr/bin/env python3
"""Authoring tool: writes scenes/ship/deck_a.tscn (the Phase 3 vertical slice).

The output is an ordinary Godot scene; after generation, edit it in the editor if you like
(regenerating overwrites it). Layout, in metres (x east, z south, y up; rooms are placed by the
centre of their floor):

                       N (-z)
        [ COMMAND BRIDGE  16x14 ]   z -34..-20
                  |door
  [QUARTERS]--[ MAIN CORRIDOR 5x40 ]--[SUPPLY ROOM]     corridor z -20..20
                  |door (locked until released at the bridge terminal)
        [ SECTION B (damaged) 5x14 ]   z 20..34
                  |door
        [ ENGINEERING ACCESS 4x16 ]    z 34..50  -> sealed ENGINE CORE door
"""
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "scenes", "ship", "deck_a.tscn")
ext, nodes, _ids = [], [], {}


def res(kind, path):
    if path not in _ids:
        _ids[path] = "r%d" % (len(_ids) + 1)
        ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (kind, path, _ids[path]))
    return 'ExtResource("%s")' % _ids[path]


def v3(t): return "Vector3(%s, %s, %s)" % tuple(("%g" % x) for x in t)
def col(c): return "Color(%g, %g, %g, 1)" % c
def q(s): return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def node(name, ntype, parent, props=None, script=None, instance=None):
    head = '[node name="%s"' % name
    if instance:
        head += ' parent="%s" instance=%s]' % (parent, res("PackedScene", instance))
    else:
        head += ' type="%s"' % ntype + (' parent="%s"' % parent if parent is not None else "") + "]"
    lines = [head]
    if script:
        lines.append("script = %s" % res("Script", script))
    for k, val in (props or {}).items():
        lines.append("%s = %s" % (k, val))
    nodes.append("\n".join(lines) + "\n")


S = "res://ship/"
def prop(name, parent, kind, pos, rot=0.0, **kw):
    p = {"position": v3(pos), "kind": q(kind)}
    if rot: p["rotation_degrees"] = v3((0, rot, 0))
    if "text" in kw: p["text"] = q(kw["text"])
    if "length" in kw: p["length"] = "%g" % kw["length"]
    if "color" in kw: p["color"] = col(kw["color"])
    if "seed" in kw: p["seed_value"] = str(kw["seed"])
    node(name, "Node3D", parent, p, S + "ship_prop.gd")


def interactable(name, parent, kind, iid, prompt, pos, rot=0.0, one_shot=False):
    p = {"position": v3(pos), "kind": q(kind), "interaction_id": '&"%s"' % iid, "prompt_text": q(prompt)}
    if rot: p["rotation_degrees"] = v3((0, rot, 0))
    if one_shot: p["one_shot"] = "true"
    node(name, "StaticBody3D", parent, p, S + "ship_interactable.gd")


def light(name, parent, pos, color, energy, rng, mode="steady", shadow=False, dist=30.0, phase=0.0):
    p = {"position": v3(pos), "light_color": col(color), "light_energy": "%g" % energy, "omni_range": "%g" % rng,
         "base_energy": "%g" % energy, "mode": q(mode), "active_distance": "%g" % dist, "phase": "%g" % phase}
    if shadow: p["shadow_enabled"] = "true"
    node(name, "OmniLight3D", parent, p, S + "flicker_light.gd")


def emitter(name, parent, pos, sound, db=-8.0, rng=12.0):
    node(name, "AudioStreamPlayer3D", parent, {"position": v3(pos), "sound": '&"%s"' % sound, "emitter_volume_db": "%g" % db, "range_m": "%g" % rng}, S + "spatial_emitter.gd")


def room(name, rid, title, zone, pos, size, openings):
    ops = "[" + ", ".join("{%s}" % ", ".join('"%s": %s' % (k, q(v) if isinstance(v, str) else repr(float(v))) for k, v in o.items()) for o in openings) + "]"
    node(name, "Node3D", "Rooms", {"position": v3(pos), "room_id": '&"%s"' % rid, "display_name": q(title), "zone": '&"%s"' % zone,
                                      "size": v3(size), "openings": ops}, S + "room_shell.gd")
    return "Rooms/" + name


def door(name, did, label, pos, rot, locked=False, sealed=False, reason="", size=(2.4, 2.7)):
    p = {"position": v3(pos), "door_id": '&"%s"' % did, "destination_label": q(label), "opening_size": "Vector2(%g, %g)" % size}
    if rot: p["rotation_degrees"] = v3((0, rot, 0))
    if locked: p["locked_by_default"] = "true"
    if sealed: p["sealed"] = "true"
    if reason: p["lock_reason"] = q(reason)
    node(name, "StaticBody3D", "Doors", p, S + "ship_door.gd")


def D(side, offset, label, width=2.4, height=2.7, **kw):
    d = {"side": side, "offset": offset, "width": width, "height": height, "kind": "door", "label": label}
    d.update(kw)
    return d


WHITE = (0.75, 0.9, 1.0); RED = (1.0, 0.18, 0.12)

# ---------------------------------------------------------------- root + globals
node("DeckA", "Node3D", None, {}, "res://scenes/core/gameplay_scene.gd")
node("Backdrop", "Node3D", ".", {}, S + "space_backdrop.gd")
node("Ambience", "Node", ".", {}, S + "ship_ambience.gd")
node("Announcer", "Node", ".", {"messages": 'PackedStringArray("Attention all crew: structural monitoring reports irregular pressure in Section B.", "Reminder: emergency evacuation procedures are posted in the crew quarters.", "Warning: unidentified interference on all communication channels.", "Attention: engine core access remains sealed.")'}, S + "ship_announcer.gd")
node("Rooms", "Node3D", ".")
node("Doors", "Node3D", ".")
node("Nav", "Node3D", ".")

# ---------------------------------------------------------------- rooms
R_COR = room("MainCorridor", "corridor", "Deck A: Main Corridor", "corridor", (0, 0, 0), (5, 3.4, 40), [
    D("north", 0, "COMMAND BRIDGE"), D("south", 0, "SECTION B  >  ENGINEERING"),
    D("west", -8, "CREW QUARTERS"), D("east", 4, "SUPPLY ROOM")])
R_BRI = room("CommandBridge", "bridge", "Command Bridge", "bridge", (0, 0, -27), (16, 4.4, 14), [
    D("south", 0, "MAIN CORRIDOR"),
    {"side": "north", "offset": 0, "width": 8.0, "height": 3.6, "sill": 0.9, "kind": "window"}])
R_QUA = room("CrewQuarters", "quarters", "Crew Quarters", "quarters", (-7.5, 0, -8), (10, 3.4, 12), [D("east", 0, "MAIN CORRIDOR")])
R_STO = room("SupplyRoom", "storage", "Supply Room", "storage", (7.5, 0, 4), (10, 3.4, 12), [D("west", 0, "MAIN CORRIDOR")])
R_DAM = room("SectionB", "damaged", "Section B (Damaged)", "damaged", (0, 0, 27), (5, 3.4, 14), [
    D("north", 0, "MAIN CORRIDOR"), D("south", 0, "ENGINEERING ACCESS")])
R_ENG = room("EngineeringAccess", "engineering", "Engineering Access Corridor", "engineering", (0, 0, 42), (4, 3.4, 16), [
    D("north", 0, "SECTION B"), D("south", 0, "ENGINE CORE  [SEALED]", width=3.0, height=3.0)])

# ---------------------------------------------------------------- doors (on shared wall planes)
door("DoorBridge", "bridge", "Command Bridge", (0, 0, -20), 0)
door("DoorQuarters", "quarters", "Crew Quarters", (-2.5, 0, -8), 90)
door("DoorSupply", "supply", "Supply Room", (2.5, 0, 4), 90)
door("DoorSectionB", "section_b", "Section B", (0, 0, 20), 0, locked=True, reason="LOCKED: Section B emergency lock engaged. Release it at the bridge status terminal.")
door("DoorEngineering", "engineering", "Engineering Access", (0, 0, 34), 0)
door("DoorEngineCore", "engine_core", "Engine Core", (0, 0, 49.8), 0, sealed=True, size=(3.0, 3.0),
     reason="ACCESS DENIED: engine core sealed under emergency protocol. Override credentials required.")
prop("EngineCoreBacking", "Doors", "blast_backing", (0, 0, 50.0))

# ---------------------------------------------------------------- main corridor
for i, (z, mode, ph) in enumerate([(-15, "steady", 0), (-5, "flicker", 0.0), (5, "steady", 0), (15, "dying", 1.7)]):
    light("Light%d" % i, R_COR, (0, 3.0, z), WHITE, 1.0, 9.5, mode, phase=ph)
light("EmergencyNorth", R_COR, (0, 2.9, -17.5), RED, 1.4, 6.0, "pulse")
light("EmergencySouth", R_COR, (0, 2.9, 11.0), RED, 1.4, 6.0, "pulse", phase=1.4)
prop("LineBlue", R_COR, "floor_line", (-0.8, 0, -10), length=18, color=(0.3, 0.6, 1.0))
prop("LineOrange", R_COR, "floor_line", (0.8, 0, 10.5), length=18, color=(1.0, 0.5, 0.1))
prop("StubAmber", R_COR, "floor_line", (-1.55, 0, -8), rot=90, length=1.5, color=(1.0, 0.62, 0.2))
prop("StubGreen", R_COR, "floor_line", (1.55, 0, 4), rot=90, length=1.5, color=(0.3, 1.0, 0.5))
prop("SignDeck", R_COR, "sign", (-2.08, 2.1, -16), rot=90, text="DECK A\nMAIN CORRIDOR", color=(0.2, 0.85, 1.0))
prop("SignOnAir", R_COR, "sign", (2.08, 2.1, -13), rot=-90, text="ON AIR\nAPOLLO-MEME LIVE", color=(1.0, 0.25, 0.2))
prop("SignDrill", R_COR, "sign", (-2.08, 2.0, 1.0), rot=90, text="EVACUATION DRILL\n1 SUIT UP\n2 GRAB GO-BAG\n3 PROCEED TO PODS", color=(1.0, 0.85, 0.2))
prop("GoBags", R_COR, "duffel_bags", (-1.55, 0, -12.2), rot=90, seed=3)
prop("VentEast", R_COR, "vent_grille", (2.07, 0.9, 14), rot=-90)
prop("ScorchSouth", R_COR, "scorch", (-2.08, 1.6, 17.5), rot=90, length=1.0, seed=4)
emitter("VentSound", R_COR, (2.0, 1.2, 14), "vent_loop", -7, 12)
emitter("WireCrackle", R_COR, (0, 3.0, -5), "electrical_crackle", -14, 9)

# ---------------------------------------------------------------- bridge
light("BridgeMain", R_BRI, (0, 4.0, 0), (0.7, 0.8, 1.0), 1.3, 14.0, "steady", shadow=True, dist=18)
light("PlanetGlowL", R_BRI, (-5, 3.6, -4), (1.0, 0.55, 0.25), 0.7, 8.0)
light("PlanetGlowR", R_BRI, (5, 3.6, -4), (1.0, 0.55, 0.25), 0.7, 8.0)
light("BridgeEmergency", R_BRI, (0, 4.1, 5.0), RED, 1.0, 6.0, "pulse", phase=0.6)
light("BridgeDying", R_BRI, (-6, 3.6, 3), (0.8, 0.9, 1.0), 0.8, 5.0, "dying", phase=2.3)
prop("ChairCommand", R_BRI, "command_chair", (0, 0, 1.0))
prop("BankNW", R_BRI, "console_bank", (-6.0, 0, -6.1), length=3.0, seed=1)
prop("BankNE", R_BRI, "console_bank", (6.0, 0, -6.1), length=3.0, seed=2)
prop("BankWest", R_BRI, "console_bank", (-7.05, 0, 0.5), rot=90, length=6.0, seed=3)
prop("BankEast", R_BRI, "console_bank", (7.05, 0, -0.5), rot=-90, length=6.0, seed=4)
prop("SignFlight", R_BRI, "sign", (-3.0, 2.7, -4.6), text="FLIGHT DECK\nHELM STATION", color=(0.55, 0.8, 1.0))
prop("SignSponsor", R_BRI, "sign", (-7.55, 2.8, -3.0), rot=90, text="SPONSORED FLIGHT\nTHANKS FOR WATCHING", color=(1.0, 0.8, 0.3))
prop("CameraRig", R_BRI, "camera_rig", (-1.8, 0, 3.8))
prop("ScorchBank", R_BRI, "scorch", (-7.58, 1.5, 3.2), rot=90, length=1.2, seed=7)
prop("SparksBank", R_BRI, "sparks", (-7.0, 1.4, 3.2))
interactable("StatusTerminal", R_BRI, "terminal", "bridge_status_terminal", "Use bridge status terminal", (3.2, 0, -5.4))
interactable("FlightConsole", R_BRI, "terminal", "bridge_flight_console", "Read flight deck log", (-3.0, 0, -5.4))
interactable("BlackBox", R_BRI, "black_box", "bridge_black_box", "Examine black-box recorder", (6.5, 0.95, 1.9), rot=-90)
emitter("ConsoleCrackle", R_BRI, (-7.0, 1.4, 3.2), "electrical_crackle", -9, 10)

# ---------------------------------------------------------------- crew quarters (local x -5..5, z -6..6; door east)
light("QuartersMain", R_QUA, (0, 3.0, 0), (1.0, 0.7, 0.4), 0.9, 10.0)
light("QuartersLamp", R_QUA, (-3.3, 1.9, 0), (1.0, 0.8, 0.5), 0.6, 4.5, "flicker", phase=3.0)
prop("BunkA", R_QUA, "bunk", (-4.0, 0, -2.8), rot=90)
prop("BunkB", R_QUA, "bunk", (-4.0, 0, 2.8), rot=90)
prop("Table", R_QUA, "table", (0.8, 0, 2.6), seed=5)
prop("LockersEast", R_QUA, "locker_row", (4.55, 0, -3.5), rot=-90)
prop("GoBagsQ", R_QUA, "duffel_bags", (3.8, 0, 3.8), rot=0, seed=6)
prop("SignEvac", R_QUA, "sign", (4.58, 1.9, 1.0), rot=-90, text="EVACUATION DRILL CHECKLIST\n1 SUIT UP\n2 GRAB GO-BAG\n3 PROCEED TO PODS", color=(1.0, 0.85, 0.2))
for i, (cid, x) in enumerate([("commander", -3.6), ("scout", -1.2), ("pilot", 1.2), ("quartermaster", 3.6)]):
    interactable("Locker_" + cid, R_QUA, "footlocker", "quarters_locker_" + cid, "Open footlocker", (x, 0, -5.3), one_shot=False)
    prop("Plate_" + cid, R_QUA, "sign", (x, 1.0, -5.57), text="{callsign:%s}" % cid, color=(1.0, 0.7, 0.3))
interactable("CassetteRadio", R_QUA, "radio", "quarters_radio", "Play cassette", (0.8, 0.78, 2.6))
emitter("QuartersVent", R_QUA, (0, 3.0, -5), "vent_loop", -14, 9)

# ---------------------------------------------------------------- supply room (door west)
light("SupplyMain", R_STO, (0, 3.0, -2), (0.8, 1.0, 0.85), 0.9, 9.0)
light("SupplyFlicker", R_STO, (0, 3.0, 3.5), (0.8, 1.0, 0.85), 0.9, 9.0, "flicker", phase=5.0)
for i, z in enumerate([-4.2, -2.1, 0.0]):
    prop("ShelfE%d" % i, R_STO, "shelving", (4.3, 0, z + 0.2), rot=-90, seed=10 + i)
prop("Shelf_N", R_STO, "shelving", (-1.5, 0, -5.3), seed=20)
prop("CratesA", R_STO, "crate_stack", (-3.2, 0, 3.6), seed=31)
prop("CratesB", R_STO, "crate_stack", (0.8, 0, 4.4), rot=90, seed=32)
prop("CratesC", R_STO, "crate_stack", (2.0, 0, -3.2), seed=33)
prop("SignPods", R_STO, "sign", (-4.58, 2.1, 3.5), rot=90, text="ESCAPE POD STAGING\nGO-BAGS COLLECT HERE", color=(0.3, 1.0, 0.5))
interactable("ManifestTerminal", R_STO, "terminal", "storage_manifest_terminal", "Read supply manifest", (4.1, 0, 3.2), rot=-90)
interactable("PodChecklist", R_STO, "pad", "storage_pod_checklist", "Read pod checklist", (-4.3, 0, -3.2), rot=90)
interactable("BatteryCrate", R_STO, "crate_open", "storage_battery_crate", "Check supply crate", (-2.2, 0, 1.2), one_shot=True)
emitter("SupplyVent", R_STO, (2, 3.0, 0), "vent_loop", -14, 9)

# ---------------------------------------------------------------- section B (damaged; z -7..7 local)
light("DamagedRed", R_DAM, (0, 3.0, -2.0), RED, 1.5, 8.0, "pulse", phase=0.3)
light("DamagedDying", R_DAM, (0, 3.0, 3.0), (0.9, 0.45, 0.3), 0.8, 8.0, "dying", phase=2.0)
light("DamagedStrobe", R_DAM, (0, 3.1, 6.0), RED, 1.0, 6.0, "strobe")
for i, (x, y, z, sd) in enumerate([(0.8, 3.15, -3.0, 1), (-0.5, 3.25, 2.0, 2), (0.3, 3.2, 5.0, 3)]):
    prop("Panel%d" % i, R_DAM, "hanging_panel", (x, y, z), seed=sd)
for i, (x, z) in enumerate([(-1.4, -4.0), (1.4, 0.0), (-1.4, 4.0)]):
    prop("Debris%d" % i, R_DAM, "debris_pile", (x, 0, z), seed=40 + i)
prop("BrokenVent", R_DAM, "vent_grille", (-2.07, 1.0, -1.0), rot=90, text="broken")
prop("ShardsVent", R_DAM, "shard_cluster", (-1.75, 0, -1.0), seed=51)
prop("ShardsFloorA", R_DAM, "shard_cluster", (1.7, 0, 3.0), seed=52)
prop("ShardsFloorB", R_DAM, "shard_cluster", (-1.8, 0, 5.6), seed=53)
prop("ScorchEast", R_DAM, "scorch", (2.09, 1.5, -3.0), rot=-90, length=1.4, seed=8)
prop("SignDamage", R_DAM, "sign", (2.08, 2.2, 3.0), rot=-90, text="SECTION B\nSTRUCTURAL FAILURE\nPRESSURE IRREGULAR", color=(1.0, 0.25, 0.2))
prop("SparksA", R_DAM, "sparks", (0.0, 3.2, 1.0))
prop("SparksB", R_DAM, "sparks", (1.9, 1.9, -3.0))
interactable("CorruptedTerminal", R_DAM, "terminal_damaged", "damaged_terminal", "Use terminal (corrupted)", (1.85, 0, -3.0), rot=-90)
interactable("KeyShard", R_DAM, "crystal", "damaged_shard", "Examine shard", (1.2, 0, 5.4), one_shot=True)
emitter("DamagedCrackle", R_DAM, (1.9, 2.0, -3.0), "electrical_crackle", -6, 12)
emitter("DamagedAlarm", R_DAM, (0, 3.0, 4.0), "alarm_loop", -22, 9)

# ---------------------------------------------------------------- engineering access (local x -2..2, z -8..8)
light("EngA", R_ENG, (0, 3.0, -4.0), (1.0, 0.55, 0.2), 1.1, 8.5, "steady")
light("EngB", R_ENG, (0, 3.0, 2.5), (1.0, 0.55, 0.2), 1.1, 8.5, "flicker", phase=4.0)
light("EngStrobe", R_ENG, (0, 3.0, 6.8), (1.0, 0.35, 0.1), 1.0, 6.0, "strobe", phase=0.5)
prop("PipeTopW", R_ENG, "pipe_run", (-1.45, 2.55, 0), length=14)
prop("PipeTopE", R_ENG, "pipe_run", (1.45, 2.55, 0), length=14)
prop("PipeLowW", R_ENG, "pipe_run", (-1.5, 0.45, 0), length=14)
prop("HazardW", R_ENG, "hazard_band", (-1.05, 0, 0), length=14)
prop("HazardE", R_ENG, "hazard_band", (1.05, 0, 0), length=14)
prop("SteamA", R_ENG, "steam_vent", (-1.3, 0.2, -3.0))
prop("SteamB", R_ENG, "steam_vent", (1.3, 0.2, 3.0))
prop("SignSteam", R_ENG, "sign", (1.58, 2.0, -5.0), rot=-90, text="CAUTION\nSTEAM / HIGH TEMPERATURE", color=(1.0, 0.6, 0.15))
interactable("MaintenanceTerminal", R_ENG, "terminal", "engineering_terminal", "Read maintenance log", (-1.5, 0, 1.0), rot=90)
emitter("SteamHiss", R_ENG, (-1.3, 0.8, -3.0), "vent_loop", -8, 10)

# ---------------------------------------------------------------- navigation targets (global space)
for tid, label, pos in [("nav_bridge", "COMMAND BRIDGE", (0, 1.6, -27)), ("nav_bridge_terminal", "STATUS TERMINAL", (3.2, 1.5, -32.4)),
                        ("nav_quarters", "CREW QUARTERS", (-7.5, 1.6, -8)), ("nav_storage", "SUPPLY ROOM", (7.5, 1.6, 4)),
                        ("nav_engineering", "ENGINEERING ACCESS", (0, 1.6, 42)), ("nav_engine_core", "ENGINE CORE DOOR", (0, 1.6, 49.5))]:
    node(tid, "Marker3D", "Nav", {"position": v3(pos), "target_id": '&"%s"' % tid, "display_name": q(label)}, S + "nav_target.gd")

# ---------------------------------------------------------------- player + hud
node("Player", None, ".", {"position": v3((0, 0.05, 13))}, instance="res://gameplay/player/player.tscn")
node("HUD", None, ".", {}, instance="res://ui/hud.tscn")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    f.write("[gd_scene format=3]\n\n" + "\n".join(ext) + "\n\n" + "\n".join(nodes))
print("wrote", os.path.relpath(OUT), "-", len(nodes), "nodes")
