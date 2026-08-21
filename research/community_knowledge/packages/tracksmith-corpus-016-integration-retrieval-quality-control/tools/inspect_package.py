#!/usr/bin/env python3
import json, sqlite3
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
m=json.loads((ROOT/'package_manifest.json').read_text());i=json.loads((ROOT/'integration/integration_manifest.json').read_text());a=json.loads((ROOT/'sources/source_access_manifest.json').read_text())
print(json.dumps({'package_id':m['package_id'],'package_type':m['package_type'],'prerequisites':len(m['depends_on']),'prior_aggregate_counts':m['prior_package_aggregate_counts'],'own_counts':m['record_counts'],'audio_profiles':{k:v['dataset_ids'] for k,v in a['profiles'].items()},'retrieval_budget':i['retrieval_policy'],'runtime_projection':i['runtime_projection']},indent=2,sort_keys=True))
