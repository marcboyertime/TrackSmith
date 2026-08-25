#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
from plan_work import plan

def main() -> None:
    data = json.loads((Path(__file__).resolve().parents[2] / "ci/semantic_dependencies.json").read_text())
    assert plan(["tools/TutorConversationTests/x.swift"], data)["mode"] == "targeted-local"
    assert plan(["ci/new.json"], data)["mode"] == "full"
    assert plan(["unexpected/path"], data)["mode"] == "full"
    assert plan([], data)["mode"] == "full"
    assert plan(["tools/TutorConversationTests/x.swift"], data, True)["mode"] == "full"
    print("test-change-planner: targeted, shared, unknown, and empty/full fallback cases passed")
if __name__ == "__main__": main()
