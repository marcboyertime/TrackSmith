#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path
from plan_work import plan

def main() -> None:
    data = json.loads((Path(__file__).resolve().parents[2] / "ci/semantic_dependencies.json").read_text())
    assert plan(["tools/TutorConversationTests/x.swift"], data)["mode"] == "targeted-local"
    assert plan(["packages/TutorConversation/Sources/TutorConversation/TutorSystemPolicy.swift"], data)["required_lanes"] == ["macos_swift_core", "macos_tutor"]
    assert plan(["research/community_knowledge/packages/tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model/knowledge_candidates/strategies.jsonl"], data)["required_lanes"] == ["linux_integrity", "macos_tutor"]
    assert plan(["research/community_knowledge/runtime_projection/p16/tracksmith-corpus-015-midi-cc-piano-roll-bounce-freeze-pdc-object-model.json"], data)["required_lanes"] == ["linux_integrity", "macos_tutor"]
    assert plan(["research/scripts/build_candidate_retrieval_index.py"], data)["required_lanes"] == ["linux_integrity", "linux_retrieval"]
    assert plan(["research/scripts/package18_audit.py"], data)["required_lanes"] == ["linux_integrity", "linux_retrieval"]
    assert plan(["research/scripts/package19_quality_suite.py"], data)["required_lanes"] == ["linux_evaluation", "linux_integrity"]
    assert plan(["packages/ProductionTutor/Sources/ProductionTutor/ProductionTutor.swift"], data)["required_lanes"] == ["linux_retrieval", "macos_swift_core", "macos_tutor", "macos_xcode_au", "macos_xcode_companion"]
    assert plan(["apps/CompanionMacApp/TutorConversationView.swift"], data)["required_lanes"] == ["macos_tutor", "macos_xcode_companion"]
    assert plan(["apps/CompanionApp/Sources/obsolete.swift"], data)["mode"] == "full"
    assert plan(["plugins/AudioUnit/AudioUnitExtension/Info.plist"], data)["required_lanes"] == ["macos_tutor", "macos_xcode_au"]
    assert plan(["tools/TutorConversationTests/Resources/example.json"], data)["required_lanes"] == ["macos_tutor"]
    assert plan(["Package.swift"], data)["mode"] == "full"
    assert plan(["project.yml"], data)["mode"] == "full"
    assert plan(["ci/new.json"], data)["mode"] == "full"
    assert plan(["unexpected/path"], data)["mode"] == "full"
    assert plan([], data)["mode"] == "full"
    assert plan(["tools/TutorConversationTests/x.swift"], data, True)["mode"] == "full"
    print("test-change-planner: targeted, shared, unknown, and empty/full fallback cases passed")
if __name__ == "__main__": main()
