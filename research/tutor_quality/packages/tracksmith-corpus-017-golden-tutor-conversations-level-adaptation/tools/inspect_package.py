#!/usr/bin/env python3
import json,sqlite3
from pathlib import Path
R=Path(__file__).resolve().parents[1];m=json.loads((R/'package_manifest.json').read_text());print(json.dumps(m,indent=2,ensure_ascii=False));c=sqlite3.connect(R/'database/corpus.sqlite');print('\nIntegrity:',c.execute('PRAGMA integrity_check').fetchone()[0]);
for t in ['canonical_qa','user_utterances','multiturn_scenarios','retrieval_evaluations','contradictions','myths_and_antipatterns','claim_candidates','strategy_candidates','logic_procedure_candidates','sources','provenance','exact_aliases']:
 print(f'{t}: {c.execute(f"SELECT count(*) FROM {t}").fetchone()[0]}')
c.close()
