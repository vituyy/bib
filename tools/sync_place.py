"""Copy the scripts in src/ into the place file, so the place always has the latest code.

Usage: python3 tools/sync_place.py [place/SpookyStealV3.2.rbxl]
Needs: pip install lz4 zstandard

Only the Source of the scripts that src/ covers is replaced; every other byte of the place is kept.
"""
import os, struct, sys
import lz4.block, zstandard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Studio location of each src/ folder (same as default.project.json).
FOLDERS = {
    ("ServerScriptService", "Server"): "src/server",
    ("ReplicatedStorage", "Shared"): "src/shared",
    ("StarterPlayer", "StarterPlayerScripts", "Client"): "src/client",
}
SUFFIX = {"ModuleScript": ".luau", "Script": ".server.luau", "LocalScript": ".client.luau"}


def read_chunks(data):
    assert data[:8] == b"<roblox!", "not a binary place file"
    pos, chunks = 32, []
    while pos < len(data):
        name = data[pos:pos + 4]
        clen, ulen, _ = struct.unpack_from("<III", data, pos + 4)
        size = clen or ulen
        raw = data[pos:pos + 16 + size]
        body = data[pos + 16:pos + 16 + size]
        if clen:
            if body[:4] == b"\x28\xb5\x2f\xfd":
                body = zstandard.ZstdDecompressor().decompress(body, max_output_size=ulen)
            else:
                body = lz4.block.decompress(body, uncompressed_size=ulen)
        chunks.append([name, body, raw])
        pos += 16 + size
        if name == b"END\x00":
            break
    return data[:32], chunks


def refs(body, pos, n):
    raw = body[pos:pos + 4 * n]
    out, acc = [], 0
    for i in range(n):
        v = (raw[i] << 24) | (raw[n + i] << 16) | (raw[2 * n + i] << 8) | raw[3 * n + i]
        acc += (v >> 1) ^ -(v & 1)
        out.append(acc)
    return out, pos + 4 * n


def string(body, pos):
    n = struct.unpack_from("<I", body, pos)[0]
    return body[pos + 4:pos + 4 + n], pos + 4 + n


def main():
    path = os.path.join(ROOT, sys.argv[1] if len(sys.argv) > 1 else "place/SpookyStealV3.2.rbxl")
    header, chunks = read_chunks(open(path, "rb").read())

    classes, inst = {}, {}
    for name, body, _ in chunks:
        if name == b"INST":
            cid = struct.unpack_from("<i", body)[0]
            cname, pos = string(body, 4)
            n = struct.unpack_from("<I", body, pos + 1)[0]
            ids, _ = refs(body, pos + 5, n)
            classes[cid] = (cname.decode(), ids)
            for r in ids:
                inst[r] = {"class": cname.decode(), "name": "", "parent": None}
        elif name == b"PROP":
            cid = struct.unpack_from("<i", body)[0]
            pname, pos = string(body, 4)
            if pname == b"Name" and body[pos] == 1:
                pos += 1
                for r in classes[cid][1]:
                    s, pos = string(body, pos)
                    inst[r]["name"] = s.decode("utf-8", "replace")
        elif name == b"PRNT":
            n = struct.unpack_from("<I", body, 1)[0]
            kids, pos = refs(body, 5, n)
            parents, _ = refs(body, pos, n)
            for c, p in zip(kids, parents):
                inst[c]["parent"] = None if p == -1 else p

    def path_of(r):
        parts = []
        while r is not None:
            parts.append(inst[r]["name"])
            r = inst[r]["parent"]
        return tuple(reversed(parts))

    # New source for every script under a synced folder.
    new_source, seen = {}, set()
    for r, i in inst.items():
        if i["class"] not in SUFFIX:
            continue
        p = path_of(r)
        for studio, folder in FOLDERS.items():
            if p[:len(studio)] == studio:
                file = os.path.join(ROOT, folder, *p[len(studio):-1], p[-1] + SUFFIX[i["class"]])
                if not os.path.exists(file):
                    sys.exit(f"missing {os.path.relpath(file, ROOT)} for {'.'.join(p)}")
                new_source[r] = open(file, "rb").read()
                seen.add(os.path.normpath(file))
    for folder in FOLDERS.values():
        for d, _, files in os.walk(os.path.join(ROOT, folder)):
            for f in files:
                if os.path.normpath(os.path.join(d, f)) not in seen:
                    sys.exit(f"{os.path.relpath(os.path.join(d, f), ROOT)} has no script in the place yet; add it in Studio first")

    changed = []
    for chunk in chunks:
        name, body, _ = chunk
        if name != b"PROP":
            continue
        cid = struct.unpack_from("<i", body)[0]
        pname, pos = string(body, 4)
        if pname != b"Source" or classes[cid][0] not in SUFFIX or body[pos] != 1:
            continue
        out, pos = bytearray(body[:pos + 1]), pos + 1
        dirty = False
        for r in classes[cid][1]:
            old, pos = string(body, pos)
            src = new_source.get(r, old)
            if src != old:
                dirty = True
                changed.append(".".join(path_of(r)))
            out += struct.pack("<I", len(src)) + src
        if dirty:
            chunk[1] = bytes(out)
            comp = lz4.block.compress(chunk[1], store_size=False)
            chunk[2] = name + struct.pack("<III", len(comp), len(chunk[1]), 0) + comp

    if not changed:
        print("Place already has the latest scripts.")
        return
    with open(path, "wb") as f:
        f.write(header + b"".join(c[2] for c in chunks))
    print("Updated in the place:\n  " + "\n  ".join(sorted(changed)))


if __name__ == "__main__":
    main()
