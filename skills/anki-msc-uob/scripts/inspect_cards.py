#!/usr/bin/env python3
"""Scoped Anki MSc card summary — ids, decks, tags, truncated fronts. No full backs."""

from __future__ import annotations

import argparse
import html
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path

# Allow `python scripts/inspect_cards.py` from any cwd
sys.path.insert(0, str(Path(__file__).resolve().parent))
from device import require_collection_db, resolve  # noqa: E402


def clean_front(flds: str, n: int = 90) -> str:
    front = (flds or "").split("\x1f")[0]
    front = html.unescape(front)
    front = re.sub(r"<[^>]+>", " ", front)
    front = re.sub(r"\s+", " ", front).strip()
    return front[:n] + ("…" if len(front) > n else "")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=None, help="Override collection.anki2 path")
    ap.add_argument("--device", default=None, help="Device id from devices.json")
    ap.add_argument("--tag", action="append", default=[], help="Only notes with this tag")
    ap.add_argument("--deck-substr", default="", help="Filter deck name substring")
    args = ap.parse_args()

    info = resolve(args.device)
    db = args.db.expanduser() if args.db else require_collection_db(args.device)

    # immutable=1 avoids lock fights when Anki is open (reads the main file only)
    uri = f"file:{db}?mode=ro&immutable=1"
    try:
        conn = sqlite3.connect(uri, uri=True, timeout=5)
    except sqlite3.Error:
        uri = f"file:{db}?mode=ro"
        conn = sqlite3.connect(uri, uri=True, timeout=10)
    conn.create_collation(
        "unicase",
        lambda a, b: (a.casefold() > b.casefold()) - (a.casefold() < b.casefold()),
    )
    conn.row_factory = sqlite3.Row

    decks = {
        r["id"]: r["name"].replace("\x1f", " :: ")
        for r in conn.execute("SELECT id, name FROM decks")
    }

    print(f"device: {info.get('device_id')} ({info.get('label')})  host={info.get('hostname')}")
    print(f"DB: {db}")
    print(
        f"notes={conn.execute('SELECT COUNT(*) c FROM notes').fetchone()['c']}  "
        f"cards={conn.execute('SELECT COUNT(*) c FROM cards').fetchone()['c']}"
    )
    print()

    tag_counts: Counter[str] = Counter()
    shown = 0
    for n in conn.execute("SELECT id, tags, flds FROM notes ORDER BY id"):
        tags = (n["tags"] or "").split()
        for t in tags:
            tag_counts[t] += 1
        if args.tag and not all(t in tags for t in args.tag):
            continue
        cards = list(conn.execute("SELECT did, ord FROM cards WHERE nid=?", (n["id"],)))
        if not cards:
            continue
        deck = decks.get(cards[0]["did"], "?")
        if args.deck_substr and args.deck_substr not in deck:
            continue
        ords = [c["ord"] for c in cards]
        print(f"{n['id']}  ords={ords}  {deck}")
        print(f"  tags: {' '.join(tags)}")
        print(f"  Q: {clean_front(n['flds'])}")
        shown += 1

    print(f"\nShown notes: {shown}")
    print("\nTag counts (all notes):")
    for t, c in sorted(tag_counts.items()):
        print(f"  {c:4}  {t}")

    print("\nCards per deck:")
    for did, cnt in conn.execute(
        "SELECT did, COUNT(*) c FROM cards GROUP BY did ORDER BY c DESC"
    ):
        print(f"  {cnt:4}  {decks.get(did, did)}")

    conn.close()


if __name__ == "__main__":
    main()
