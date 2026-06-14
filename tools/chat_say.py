#!/usr/bin/env python3
"""Append an assistant reply to the web chat log.

Usage: python3 tools/chat_say.py "回复内容"
       echo "多行回复" | python3 tools/chat_say.py
"""
from __future__ import annotations

import json
import sys
import time
from pathlib import Path

LOG = Path(__file__).resolve().parents[1] / "build" / "chat_log.jsonl"


def main() -> None:
    text = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()
    text = text.strip()
    if not text:
        raise SystemExit("empty reply")
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps({"role": "assistant", "text": text, "ts": time.strftime("%H:%M:%S")}, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
