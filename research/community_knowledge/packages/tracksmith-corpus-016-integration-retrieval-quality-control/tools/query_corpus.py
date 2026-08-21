#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re, sqlite3, uuid
from datetime import datetime, timezone
from pathlib import Path

def norm(t):return ' '.join(re.sub(r'[^\w]+',' ',t.casefold()).split())
def fts_query(t):
    vals=[x for x in norm(t).split() if len(x)>1]
    return ' OR '.join('"'+x.replace('"','')+'"' for x in vals[:24]) or '"__none__"'
def main():
    ap=argparse.ArgumentParser();ap.add_argument('query');ap.add_argument('--database',required=True);ap.add_argument('--top-k',type=int,default=4);ap.add_argument('--show-diagnostics',action='store_true');ap.add_argument('--write-receipt',action='store_true');args=ap.parse_args()
    db=Path(args.database);c=sqlite3.connect(db);c.row_factory=sqlite3.Row;cur=c.cursor();qnorm=norm(args.query)
    exact=cur.execute('SELECT canonical_qa_id FROM exact_fixture_aliases WHERE normalized_alias=?',(qnorm,)).fetchone()
    if exact:
        rows=cur.execute('SELECT * FROM canonical_qa WHERE id=?',(exact['canonical_qa_id'],)).fetchall();mode='test_exact_identity'
    else:
        try:rows=cur.execute('SELECT c.*,bm25(canonical_qa_fts) AS rank FROM canonical_qa_fts f JOIN canonical_qa c ON c.id=f.id WHERE canonical_qa_fts MATCH ? ORDER BY rank LIMIT 80',(fts_query(args.query),)).fetchall()
        except sqlite3.OperationalError:rows=[]
        mode='hybrid_bounded'
    # Strict diversity budget.
    out=[]; per_pkg={};per_dom={}
    for r in rows:
        if len(out)>=min(max(args.top_k,1),4):break
        pkg=r['package_id'];dom=r['domain']
        if per_pkg.get(pkg,0)>=2 or per_dom.get(dom,0)>=2:continue
        out.append({k:r[k] for k in ['id','package_id','domain','subdomain','title','canonical_question','direct_answer','experiment','review_state','evidence_class'] if k in r.keys()})
        per_pkg[pkg]=per_pkg.get(pkg,0)+1;per_dom[dom]=per_dom.get(dom,0)+1
    diagnostics=[]
    if args.show_diagnostics:
        col=cur.execute('SELECT * FROM alias_collisions WHERE normalized_alias=?',(qnorm,)).fetchone()
        if col:diagnostics.append({'classification':'diagnostic_cross_domain_collision','canonical_ids':json.loads(col['canonical_ids_json']),'packages':json.loads(col['packages_json'])})
    result={'mode':mode,'query':args.query,'budget':{'canonical_max':4,'per_package_max':2,'per_domain_max':2},'results':out,'diagnostics':diagnostics}
    if args.write_receipt:
        rid=str(uuid.uuid4());cur.execute('INSERT INTO retrieval_receipts VALUES (?,?,?,?,?)',(rid,datetime.now(timezone.utc).isoformat(),hashlib.sha256(args.query.encode()).hexdigest(),json.dumps([x['id'] for x in out]),json.dumps(result['budget'])));c.commit();result['receipt_id']=rid
    c.close();print(json.dumps(result,indent=2,ensure_ascii=False))
if __name__=='__main__':main()
