#!/usr/bin/env python3
import json, sqlite3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/"package_manifest.json").read_text())
print(json.dumps(m,indent=2,ensure_ascii=False))
db=sqlite3.connect(ROOT/"database/corpus.sqlite")
print("\nDatabase integrity:",db.execute("PRAGMA integrity_check").fetchone()[0])
for t in ["canonical_qa","user_utterances","multiturn_scenarios","retrieval_evaluations","contradictions","myths_and_antipatterns","claim_candidates","strategy_candidates","logic_procedure_candidates","sources"]:
    print(f"{t}: {db.execute(f'SELECT count(*) FROM {t}').fetchone()[0]}")
db.close()
