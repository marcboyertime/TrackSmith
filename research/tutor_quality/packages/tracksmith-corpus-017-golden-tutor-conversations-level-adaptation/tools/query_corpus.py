#!/usr/bin/env python3
import argparse,json,re,sqlite3,unicodedata
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];DB=ROOT/'database/corpus.sqlite'
def norm(s):
 s=unicodedata.normalize('NFKC',s).casefold().replace('’',"'")
 return ' '.join(re.sub(r'[^a-z0-9]+',' ',s).split())
def main():
 ap=argparse.ArgumentParser(description='Query Package 017 evaluation cases. This package is test-only and must not be used as live Tutor knowledge.');ap.add_argument('query');ap.add_argument('--limit',type=int,default=8);args=ap.parse_args()
 con=sqlite3.connect(DB);n=norm(args.query);exact=con.execute('SELECT canonical_qa_id FROM exact_aliases WHERE normalized_alias=?',(n,)).fetchone()
 if exact:
  rows=con.execute('SELECT id,subdomain,title,canonical_question,direct_answer FROM canonical_qa WHERE id=?',(exact[0],)).fetchall()
 else:
  toks=re.findall(r'[a-z0-9]+',n)[:24];expr=' OR '.join('"'+x+'"' for x in toks) or 'tracksmith'
  rows=con.execute('SELECT c.id,c.subdomain,c.title,c.canonical_question,c.direct_answer FROM canonical_qa_fts f JOIN canonical_qa c ON c.id=f.id WHERE canonical_qa_fts MATCH ? ORDER BY bm25(canonical_qa_fts) LIMIT 100',(expr,)).fetchall()
 for i,r in enumerate(rows[:max(1,min(args.limit,30))],1):print(f'\n{i}. {r[0]} [{r[1]}]\n{r[2]}\nQ: {r[3]}\nEvaluation intent: {r[4]}')
 if not rows:print('No matches.')
 con.close()
if __name__=='__main__':main()
