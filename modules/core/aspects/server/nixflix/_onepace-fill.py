#!/usr/bin/env python3
"""
onepace-fill -- bridge the Wano gap in the One Pace library with Onigashima Paced.

One Pace's Wano arc is still `wip`: it currently adapts manga chapters 909-1012
(S35E01-E61), while Wano itself runs to chapter 1057. The Onigashima Paced
project adapts chapters 977-1057 in the same recut style, so its later episodes
cover exactly the tail One Pace has not reached yet.

This script hardlinks those tail episodes into the One Pace Season 35 folder at a
high episode offset (E101+), and -- the point of running it on a timer -- deletes
each fill-in again as soon as One Pace releases its own episodes covering the
same chapters. The library converges on pure One Pace without manual pruning.

Why E101+ and not E62+
    One Pace will keep releasing Wano episodes into E62, E63, ... If the fill-ins
    sat there, OnePacerr would download a real E62 on top of a fill-in E62 and
    the two would fight over the slot. Offsetting past any plausible One Pace
    episode number keeps the namespaces disjoint, and Jellyfin still sorts E101
    directly after E61, so playback flows straight on from where One Pace stops.

Why OnePacerr leaves these alone
    OnePacerr iterates *its own* episode metadata and looks for a matching file
    for each known One Pace episode. It has no logic that walks the season folder
    looking for strays, so files it does not recognise are never verified,
    renamed, moved, or deleted -- independent of the PIPELINE_SKIP_* settings.

Independence from the torrent
    Imports are hardlinks, so once an episode is in the library its data survives
    the torrent being removed *and* its files deleted -- the library entry is a
    second name for the same inode, not a copy.

    Retirement is likewise driven entirely by the library: each fill-in's .nfo
    records the manga chapters it covers, so the reconcile pass needs neither the
    source files nor qBittorrent. Deleting the torrent after watching therefore
    costs nothing. The source directory is consulted only to import episodes not
    yet in the library, and qBittorrent only to tell whether a source file has
    finished downloading.

    For the same reason episode numbers are computed from the source *filename*
    alone rather than from position in a directory listing: a listing shrinks as
    files are pruned, which would silently renumber every remaining episode.
"""

import json
import os
import re
import sys
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape

SOURCE_DIR = Path(os.environ.get("SOURCE_DIR", "/storage/Torrents/one-pace-fill/Onigashima Paced"))
SEASON_DIR = Path(os.environ.get("SEASON_DIR", "/storage/media/library/one-pace/One Pace/Season 35"))
METADATA_URL = os.environ.get("METADATA_URL", "https://onepacerr.com/api/v1")
QBIT_URL = os.environ.get("QBIT_URL", "http://localhost:8080")
TORRENT_HASH = os.environ.get("TORRENT_HASH", "4d04775faae4513ad07eb10774e1335c64a6d810")
JELLYFIN_URL = os.environ.get("JELLYFIN_URL", "http://localhost:8096")
JELLYFIN_API_KEY_FILE = os.environ.get("JELLYFIN_API_KEY_FILE", "")
STATE_FILE = Path(os.environ.get("STATE_FILE", "/var/lib/onepace-fill/state.json"))

SHOW = "One Pace"
SEASON = 35
ARC = "Wano"
# Episode-number offset for fill-ins. E101 is the first, leaving E62-E100 free
# for One Pace's own remaining Wano releases (it plans ~88 episodes for the arc).
OFFSET = 100
# The batch ships one anime-only episode, "[1056 Filler] End of Wano 03.5".
# Excluded by default to match the library's existing no-filler stance
# (OnePacerr runs with PIPELINE_PREFER_ALTERNATE=false, which likewise drops the
# optional G-8 filler cut). Set INCLUDE_FILLER=1 to pull it in.
INCLUDE_FILLER = os.environ.get("INCLUDE_FILLER", "0") == "1"
DRY_RUN = os.environ.get("DRY_RUN", "0") == "1"

# "[1012-1013] Onigashima 28 - Anarchy in the BM.mp4"
# "[1056 Filler] End of Wano 03.5 - Farewell.mp4"
NAME_RE = re.compile(
    r"^\[(?P<chapters>[^\]]+)\] (?P<subarc>Onigashima|End of Wano) (?P<num>\d+(?:\.\d+)?) - (?P<title>.+)\.(?P<ext>mp4|mkv)$"
)
# Marks a fill-in in the library so retirement only ever touches our own files.
TAG = "Onigashima Paced"
LIB_RE = re.compile(
    rf"^{re.escape(SHOW)} - S{SEASON:02d}E(?P<ep>\d+) - (?P<title>.+) \({re.escape(TAG)}\)\.(?P<ext>mp4|mkv|nfo)$"
)
# Machine-readable chapter range parked in each fill-in's .nfo. Jellyfin ignores
# elements it does not know, and this is what lets retirement run with the source
# files and the torrent both long gone.
CH_TAG = "onepacefillchapters"
CH_RE = re.compile(rf"<{CH_TAG}>([^<]+)</{CH_TAG}>")

# The Onigashima sub-arc is 48 episodes, so "Onigashima NN" -> OFFSET+NN gives
# E101-E148. "End of Wano" then continues from E149. Both projects are finished
# (Wano ends at chapter 1057), so these are fixed, not a guess about future
# releases -- which is what makes a number derivable from one filename.
ONIGASHIMA_COUNT = 48
END_OF_WANO_ORDER = [1.0, 2.0, 3.0, 3.5, 4.0]


def log(msg):
    print(msg, flush=True)


def fetch_json(url, timeout=30):
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.load(r)


def episode_number(subarc, num):
    """Library episode number for a source episode, from its name alone."""
    if subarc == "Onigashima":
        return OFFSET + int(num)
    return OFFSET + ONIGASHIMA_COUNT + 1 + END_OF_WANO_ORDER.index(num)


def parse_source_name(name):
    m = NAME_RE.match(name)
    if not m:
        return None
    chapters = m.group("chapters")
    nums = [int(n) for n in re.findall(r"\d+", chapters)]
    if not nums:
        return None
    try:
        ep = episode_number(m.group("subarc"), float(m.group("num")))
    except ValueError:  # unexpected "End of Wano" numbering -- skip, don't guess
        log(f"  ! unrecognised episode number in {name!r}; skipping")
        return None
    return {
        "episode": ep,
        "title": m.group("title"),
        "ext": m.group("ext"),
        "chapters": chapters,
        "end": max(nums),
        "filler": "filler" in chapters.lower(),
    }


def onepace_max_chapter():
    """Highest manga chapter covered by a *released* One Pace Wano episode."""
    data = fetch_json(f"{METADATA_URL}/metadata")
    arcs = data if isinstance(data, list) else (data.get("arcs") or next(iter(data.values())))
    for arc in arcs:
        if str(arc.get("title", "")).strip().lower() != ARC.lower():
            continue
        best = 0
        for ep in arc.get("episodes", []):
            # An episode with no release date is announced but not out yet, so it
            # must not count as covering its chapters.
            if not ep.get("released"):
                continue
            nums = [int(n) for n in re.findall(r"\d+", str(ep.get("mangaChapters", "")))]
            if nums:
                best = max(best, max(nums))
        return best
    raise SystemExit(f"arc {ARC!r} not found in One Pace metadata")


def completed_sources():
    """Source episodes ready to import, keyed by library episode number.

    qBittorrent's per-file progress is the gate: hardlinking on filesystem
    presence alone would publish a half-written file that looks complete. Once
    the torrent is gone the API 404s and anything still on disk is finished by
    definition, so on-disk presence becomes the right answer.
    """
    if not SOURCE_DIR.is_dir():
        return {}
    try:
        raw = fetch_json(f"{QBIT_URL}/api/v2/torrents/files?hash={TORRENT_HASH}", timeout=15)
        ready = {Path(f["name"]).name for f in raw if f.get("progress", 0) >= 1.0}
    except Exception:
        ready = None  # torrent removed or qBittorrent down

    out = {}
    for path in SOURCE_DIR.iterdir():
        info = parse_source_name(path.name)
        if not info:
            continue
        if ready is not None and path.name not in ready:
            continue
        info["path"] = path
        out[info["episode"]] = info
    return out


def scan_library():
    """Fill-ins currently in the season folder, keyed by episode number."""
    found = {}
    for p in sorted(SEASON_DIR.iterdir()):
        m = LIB_RE.match(p.name)
        if not m:
            continue
        ep = int(m.group("ep"))
        rec = found.setdefault(ep, {"episode": ep, "title": m.group("title"), "paths": [], "chapters": None})
        rec["paths"].append(p)
        if p.suffix == ".nfo":
            rec["nfo"] = p
            hit = CH_RE.search(p.read_text(encoding="utf-8", errors="replace"))
            if hit:
                rec["chapters"] = hit.group(1)
        else:
            rec["video"] = p
    return found


def nfo_xml(episode, title, chapters):
    plot = (
        f"Onigashima Paced fill-in covering manga chapter(s) {chapters}. "
        f"Stands in until One Pace's own Wano episodes reach this point, at which "
        f"point onepace-fill removes it automatically."
    )
    return f"""<?xml version='1.0' encoding='utf-8'?>
<episodedetails>
  <title>{escape(title)} ({TAG})</title>
  <showtitle>{SHOW}</showtitle>
  <season>{SEASON}</season>
  <displayseason>{SEASON}</displayseason>
  <episode>{episode}</episode>
  <displayepisode>{episode}</displayepisode>
  <plot>{escape(plot)}</plot>
  <mpaa>TV-14</mpaa>
  <customrating>TV-14</customrating>
  <lockdata>false</lockdata>
  <{CH_TAG}>{escape(chapters)}</{CH_TAG}>
</episodedetails>
"""


def library_name(episode, title, ext):
    return f"{SHOW} - S{SEASON:02d}E{episode:02d} - {title} ({TAG}).{ext}"


def load_state_chapters():
    """episode -> chapters recorded by an earlier run, for backfilling .nfos."""
    try:
        data = json.loads(STATE_FILE.read_text())
        return {int(k): v["chapters"] for k, v in data.get("fill_ins", {}).items() if "chapters" in v}
    except Exception:
        return {}


def refresh_jellyfin():
    if not JELLYFIN_API_KEY_FILE or not Path(JELLYFIN_API_KEY_FILE).exists():
        return
    key = Path(JELLYFIN_API_KEY_FILE).read_text().strip()
    req = urllib.request.Request(f"{JELLYFIN_URL}/Library/Refresh", method="POST")
    req.add_header("X-Emby-Token", key)
    req.add_header("Content-Length", "0")
    try:
        urllib.request.urlopen(req, timeout=30).read()
        log("  Jellyfin library refresh triggered")
    except Exception as e:
        log(f"  ! Jellyfin refresh failed: {e}")


def main():
    if not SEASON_DIR.is_dir():
        raise SystemExit(f"season dir missing: {SEASON_DIR}")

    op_max = onepace_max_chapter()
    sources = completed_sources()
    library = scan_library()
    state_chapters = load_state_chapters()
    log(f"One Pace {ARC}: released through manga chapter {op_max}")
    log(f"source episodes ready: {len(sources)}   fill-ins in library: {len(library)}")

    imported = retired = backfilled = 0

    # -- Backfill: teach pre-existing .nfos their chapter range, so retirement
    #    keeps working once the source files are gone.
    for ep, rec in library.items():
        if rec["chapters"] or "nfo" not in rec:
            continue
        chapters = state_chapters.get(ep) or (sources[ep]["chapters"] if ep in sources else None)
        if not chapters:
            log(f"  ! E{ep} has no recorded chapters and no source; leaving in place")
            continue
        log(f"  ~ E{ep} backfilled chapter range {chapters}")
        if not DRY_RUN:
            rec["nfo"].write_text(nfo_xml(ep, rec["title"], chapters), encoding="utf-8")
        rec["chapters"] = chapters
        backfilled += 1

    # -- Import: source episodes covering chapters One Pace has not reached.
    for ep, src in sorted(sources.items()):
        if ep in library:
            continue
        if src["end"] <= op_max:
            continue
        if src["filler"] and not INCLUDE_FILLER:
            continue
        dest = SEASON_DIR / library_name(ep, src["title"], src["ext"])
        log(f"  + E{ep} ch{src['chapters']:<10} {src['title']}")
        if not DRY_RUN:
            # Hardlink: costs no extra space, the torrent keeps seeding from the
            # same inode, and the episode outlives the torrent's removal.
            os.link(src["path"], dest)
            (SEASON_DIR / library_name(ep, src["title"], "nfo")).write_text(
                nfo_xml(ep, src["title"], src["chapters"]), encoding="utf-8"
            )
        imported += 1

    # -- Retire: fill-ins One Pace has now caught up to. Driven purely by what is
    #    in the library, so this works with the torrent and sources long gone.
    for ep, rec in sorted(library.items()):
        if not rec["chapters"]:
            continue
        nums = [int(n) for n in re.findall(r"\d+", rec["chapters"])]
        if not nums or max(nums) > op_max:
            continue
        log(f"  - E{ep} retired: One Pace now covers ch{rec['chapters']}")
        if not DRY_RUN:
            for p in rec["paths"]:
                p.unlink()
        retired += 1

    log(f"summary: {imported} imported, {retired} retired, {backfilled} backfilled")

    if (imported or retired or backfilled) and not DRY_RUN:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        final = scan_library()
        STATE_FILE.write_text(
            json.dumps(
                {
                    "onepace_max_chapter": op_max,
                    "fill_ins": {
                        str(ep): {"chapters": rec["chapters"], "title": rec["title"]}
                        for ep, rec in sorted(final.items())
                    },
                },
                indent=2,
            )
        )
        refresh_jellyfin()
    return 0


if __name__ == "__main__":
    sys.exit(main())
