#!/usr/bin/env python3
"""Extract Ember Grove's world out of a Roblox .rbxlx into engine-neutral JSON.

Emits:
  data/world.json    every renderable/collidable part, with tags + attributes
  data/scripts/*.lua every Lua source in the place (design reference)
  data/report.md     a human summary of what came across

The .rbxlx is a nested <Item class=...><Properties>...</Properties><Item/>...</Item>
tree. Tags live in <SharedString name="Tags"> which point into a <SharedStrings>
table keyed by md5; attributes live in a binary blob under AttributesSerialize.
"""
import base64
import json
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "~/Documents/Penguin Firefighter Adventure.rbxlx")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")

# Roblox Material enum -> readable name (only the ones this place uses).
MATERIALS = {
    256: "Plastic", 272: "SmoothPlastic", 288: "Neon", 512: "Wood", 528: "WoodPlanks",
    784: "Marble", 788: "Basalt", 800: "Slate", 804: "CrackedLava", 816: "Concrete",
    832: "Granite", 848: "Brick", 864: "Pebble", 880: "Cobblestone", 896: "Rock",
    912: "Sandstone", 1040: "CorrodedMetal", 1056: "DiamondPlate", 1072: "Foil",
    1088: "Metal", 1280: "Grass", 1284: "LeafyGrass", 1296: "Sand", 1312: "Fabric",
    1328: "Snow", 1344: "Mud", 1360: "Ground", 1376: "Asphalt", 1392: "Salt",
    1408: "Limestone", 1424: "Pavement", 1536: "Ice", 1552: "Glacier",
    1584: "ForceField", 2048: "Water", 2304: "Cardboard", 2307: "Carpet",
    2308: "CeramicTiles", 2311: "ClayRoofTiles", 2320: "Leather", 2322: "Plaster",
}
SHAPES = {0: "Ball", 1: "Block", 2: "Cylinder", 3: "Wedge", 4: "CornerWedge"}


def load_shared_strings(text):
    """md5 key -> decoded utf-8 payload (tag names)."""
    table = {}
    for m in re.finditer(
            r'<SharedString md5="([^"]+)">([^<]*)</SharedString>', text):
        try:
            table[m.group(1)] = base64.b64decode(m.group(2)).decode(
                "utf-8", "replace")
        except Exception:
            pass
    return table


def decode_attributes(blob):
    """Roblox AttributesSerialize: u32 count, then (u32 len, name, u8 type, value)*."""
    if not blob:
        return {}
    try:
        raw = base64.b64decode(blob)
    except Exception:
        return {}
    out, pos = {}, 0
    if len(raw) < 4:
        return {}
    (count,), pos = struct.unpack_from("<I", raw, 0), 4
    for _ in range(count):
        if pos + 4 > len(raw):
            break
        (nlen,) = struct.unpack_from("<I", raw, pos)
        pos += 4
        name = raw[pos:pos + nlen].decode("utf-8", "replace")
        pos += nlen
        if pos >= len(raw):
            break
        typ = raw[pos]
        pos += 1
        try:
            if typ == 0x02:  # string
                (slen,) = struct.unpack_from("<I", raw, pos)
                pos += 4
                out[name] = raw[pos:pos + slen].decode("utf-8", "replace")
                pos += slen
            elif typ == 0x03:  # bool
                out[name] = raw[pos] != 0
                pos += 1
            elif typ == 0x05:  # float32
                (out[name],) = struct.unpack_from("<f", raw, pos)
                pos += 4
            elif typ == 0x06:  # float64 (what Studio writes for plain numbers)
                (v,) = struct.unpack_from("<d", raw, pos)
                out[name] = round(v, 6)
                pos += 8
            elif typ == 0x09:  # UDim
                pos += 8
            elif typ == 0x0A:  # UDim2
                pos += 16
            elif typ == 0x0E:  # BrickColor
                pos += 4
            elif typ == 0x0F:  # Color3
                r, g, b = struct.unpack_from("<fff", raw, pos)
                out[name] = [round(r * 255), round(g * 255), round(b * 255)]
                pos += 12
            elif typ == 0x10:  # Vector2
                pos += 8
            elif typ == 0x11:  # Vector3
                x, y, z = struct.unpack_from("<fff", raw, pos)
                out[name] = [x, y, z]
                pos += 12
            else:
                break  # unknown type: stop rather than misparse
        except struct.error:
            break
    return out


def prop_text(props, name):
    el = props.get(name)
    return el.text if el is not None and el.text is not None else None


def parse():
    text = open(SRC, encoding="utf-8").read()
    shared = load_shared_strings(text)
    print(f"  shared strings: {len(shared)}")

    root = ET.fromstring(text)
    parts, scripts = [], []
    tag_counts, class_counts, material_counts = Counter(), Counter(), Counter()

    PART_CLASSES = {"Part", "WedgePart", "TrussPart", "MeshPart", "CornerWedgePart",
                    "SpawnLocation", "Seat", "VehicleSeat"}

    def walk(item, path):
        cls = item.get("class", "")
        props_el = item.find("Properties")
        props = {}
        if props_el is not None:
            for p in props_el:
                n = p.get("name")
                if n:
                    props[n] = p
        name = prop_text(props, "Name") or cls
        here = path + [name]
        class_counts[cls] += 1

        # ---- Lua sources ----
        if cls in ("Script", "LocalScript", "ModuleScript"):
            src = prop_text(props, "Source")
            if src:
                scripts.append({"path": "/".join(path[1:] + [name]),
                                "class": cls, "source": src})

        # ---- geometry ----
        if cls in PART_CLASSES:
            cf = props.get("CFrame")
            size = props.get("size") or props.get("Size")
            if cf is not None and size is not None:
                def f(parent, tag):
                    el = parent.find(tag)
                    return float(el.text) if el is not None and el.text else 0.0

                rec = {
                    "name": name,
                    "class": cls,
                    "path": "/".join(here[1:-1]),
                    "pos": [round(f(cf, "X"), 3), round(f(cf, "Y"), 3),
                            round(f(cf, "Z"), 3)],
                    "rot": [round(f(cf, t), 6) for t in
                            ("R00", "R01", "R02", "R10", "R11", "R12",
                             "R20", "R21", "R22")],
                    "size": [round(f(size, "X"), 3), round(f(size, "Y"), 3),
                             round(f(size, "Z"), 3)],
                }

                c8 = prop_text(props, "Color3uint8")
                if c8:
                    v = int(c8)
                    rec["color"] = [(v >> 16) & 255, (v >> 8) & 255, v & 255]

                mat = prop_text(props, "Material")
                if mat:
                    mname = MATERIALS.get(int(mat), f"Material{mat}")
                    rec["material"] = mname
                    material_counts[mname] += 1

                shape = prop_text(props, "shape")
                if shape and cls == "Part":
                    rec["shape"] = SHAPES.get(int(shape), "Block")

                tr = prop_text(props, "Transparency")
                if tr and float(tr) > 0.001:
                    rec["transparency"] = round(float(tr), 3)
                cc = prop_text(props, "CanCollide")
                if cc == "false":
                    rec["canCollide"] = False
                refl = prop_text(props, "Reflectance")
                if refl and float(refl) > 0.001:
                    rec["reflectance"] = round(float(refl), 3)

                tags_el = props.get("Tags")
                if tags_el is not None and tags_el.text:
                    payload = shared.get(tags_el.text.strip())
                    if payload is None:
                        try:
                            payload = base64.b64decode(
                                tags_el.text).decode("utf-8", "replace")
                        except Exception:
                            payload = None
                    if payload:
                        tags = [t for t in payload.split("\x00") if t]
                        if tags:
                            rec["tags"] = tags
                            for t in tags:
                                tag_counts[t] += 1

                attrs = decode_attributes(prop_text(props, "AttributesSerialize"))
                if attrs:
                    rec["attrs"] = attrs

                parts.append(rec)

        for child in item.findall("Item"):
            walk(child, here)

    for item in root.findall("Item"):
        walk(item, [])

    return parts, scripts, tag_counts, class_counts, material_counts


def main():
    print(f"reading {SRC}")
    parts, scripts, tags, classes, materials = parse()

    os.makedirs(os.path.join(OUT, "scripts"), exist_ok=True)

    # bounds + per-region breakdown
    regions = defaultdict(int)
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for p in parts:
        top = p["path"].split("/")[1] if "/" in p["path"] else p["path"]
        regions[top or "(root)"] += 1
        for i in range(3):
            lo[i] = min(lo[i], p["pos"][i])
            hi[i] = max(hi[i], p["pos"][i])

    world = {
        "source": os.path.basename(SRC),
        "partCount": len(parts),
        "bounds": {"min": [round(v, 1) for v in lo],
                   "max": [round(v, 1) for v in hi]},
        "tagCounts": dict(tags.most_common()),
        "parts": parts,
    }
    with open(os.path.join(OUT, "world.json"), "w") as fh:
        json.dump(world, fh, separators=(",", ":"))

    for s in scripts:
        safe = s["path"].replace("/", "__") + ".lua"
        with open(os.path.join(OUT, "scripts", safe), "w") as fh:
            fh.write(s["source"])

    lines = ["# World extraction report", "",
             f"- source: `{os.path.basename(SRC)}`",
             f"- parts: **{len(parts)}**",
             f"- scripts: **{len(scripts)}**",
             f"- bounds: min {[round(v,1) for v in lo]} max {[round(v,1) for v in hi]}",
             "", "## Regions (part counts)", ""]
    for r, n in sorted(regions.items(), key=lambda kv: -kv[1]):
        lines.append(f"- {r}: {n}")
    lines += ["", "## Gameplay tags", ""]
    for t, n in tags.most_common():
        lines.append(f"- `{t}`: {n}")
    lines += ["", "## Materials", ""]
    for m, n in materials.most_common():
        lines.append(f"- {m}: {n}")
    lines += ["", "## Scripts", ""]
    for s in sorted(scripts, key=lambda s: s["path"]):
        lines.append(f"- `{s['path']}` ({s['class']}, "
                     f"{len(s['source'].splitlines())} lines)")
    with open(os.path.join(OUT, "report.md"), "w") as fh:
        fh.write("\n".join(lines) + "\n")

    print(f"  parts:   {len(parts)}")
    print(f"  scripts: {len(scripts)}")
    print(f"  tags:    {len(tags)} kinds, {sum(tags.values())} tagged parts")
    print(f"  bounds:  {[round(v,1) for v in lo]} .. {[round(v,1) for v in hi]}")


if __name__ == "__main__":
    main()
