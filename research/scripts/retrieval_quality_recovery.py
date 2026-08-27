#!/usr/bin/env python3
"""Deterministic, standard-library-only pre-human retrieval recovery audit."""
import argparse, collections, hashlib, json, math, re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]; PROJ=ROOT/'research/community_knowledge/runtime_projection/p16'; SUITE=ROOT/'research/tutor_quality/package019_evaluation_suite.json'
OUT=ROOT/'docs/evidence/RETRIEVAL_CORPUS_AUDIT.json'; MD=ROOT/'docs/evidence/RETRIEVAL_CORPUS_AUDIT.md'; PILOT=ROOT/'research/tutor_quality/retrieval_quality_recovery/pilot_selection.json'; STATUS=ROOT/'docs/evidence/RETRIEVAL_QUALITY_RECOVERY_STATUS.json'
GROUPS={"primary_identity":["id","packageID","domain","category","title","question"],"user_language":["question","title","tags","clarificationQuestions"],"intent_facets":["category","tags","roleFacets","sectionFacets","userIntent"],"diagnostic_context":["competingHypotheses","keyDistinction","evidenceNeeded"],"listening_experiment_context":["recommendedFirstExperiment","firstExperiment","listenFor","listeningCues","stopOrUndo"],"authority_provenance":["originalReviewStatus","authoritativeSupportingSourceIDs","primaryResearchSourceIDs","professionalPracticeSourceIDs","discoveryLanguageSourceIDs","standardsSourceIDs"]}
CHANNELS=(('title',('title',)),('question',('question',)),('combined_card',('title','question','rationale','recommendedFirstExperiment')))
HEURISTICS={"ordinary":r"\bwhy|how|what\b","expert":r"\bms|hz|lufs|db\b","colloquial":r"\bsounds|feels|weird\b","abbreviation":r"\b(eq|fx|bpm|midi)\b","misspelling":r"\bteh|wut|cant\b","follow_up":r"\bthat|it|this\b","multi_turn":r"\bagain|after|now\b","object":r"\bvocal|guitar|drum|mix\b","symptom":r"\bmuddy|harsh|thin|late\b","action":r"\btry|change|adjust|test\b","signal_stage":r"\binput|bus|send|master\b","musical_reference":r"\bverse|chorus|groove|tempo\b","near_neighbor":r"\bvs|versus|instead\b"}
def w(s): return re.findall(r'[a-z0-9]+',str(s).lower())
def norm(s): return ' '.join(w(s))
def flat(v): return ' '.join(v) if isinstance(v,list) else str(v or '')
def sha(s): return hashlib.sha256(s.encode()).hexdigest()
def digest(v): return hashlib.sha256(json.dumps(v,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
def read():
 cards=[]; utterances=[]; hashes={}
 for path in sorted(PROJ.glob('*.json')):
  raw=path.read_bytes(); hashes[path.name]=hashlib.sha256(raw).hexdigest(); data=json.loads(raw); cards.extend(data['canonicalCards']); utterances.extend(data['utterances'])
 hashes['package019_evaluation_suite.json']=hashlib.sha256(SUITE.read_bytes()).hexdigest(); return cards,utterances,hashes
def ref(d): return {k:d[k] for k in ('kind','id','package','domain','category','channel')}
def sim(a,b):
 A,B=set(w(a)),set(w(b)); token=len(A&B)/max(1,len(A|B)); a,b=norm(a),norm(b); ca={a[i:i+3] for i in range(max(0,len(a)-2))}; cb={b[i:i+3] for i in range(max(0,len(b)-2))}; return token,len(ca&cb)/max(1,len(ca|cb))
def signature(s):
 values=[int(hashlib.sha256(token.encode()).hexdigest()[:16],16) for token in set(w(s))]; return [min(((x^(0x9e3779b97f4a7c15*(seed+1)))&((1<<63)-1) for x in values),default=0) for seed in range(6)]
def duplicate_maps(docs):
 out={}
 for channel in ('title','question','combined_card','utterance'):
  exact=collections.defaultdict(list); normalized=collections.defaultdict(list)
  for d in (x for x in docs if x['channel']==channel): exact[sha(d['text'].strip())].append(ref(d)); normalized[sha(norm(d['text']))].append(ref(d))
  def rows(source,kind): return [{'content_sha256':k,'documents':sorted(v,key=lambda x:(x['id'],x['domain'])),'scope':'cross_domain' if len({x['domain'] for x in v})>1 else 'same_domain','channel':channel,'duplicate_kind':kind,'classification':'pending_human_review'} for k,v in sorted(source.items()) if len(v)>1]
  out[channel]={'exact':rows(exact,'exact'),'normalized':rows(normalized,'normalized')}
 return out
def near(docs,cap=8,limit=512):
 buckets=collections.defaultdict(list)
 for i,d in enumerate(docs):
  if norm(d['text']):
   for band,value in enumerate(signature(d['text'])): buckets[(band,value)].append(i)
 positions={key:{item:position for position,item in enumerate(items)} for key,items in buckets.items()}
 seen=set(); queue=[]; collisions=collections.Counter(); offered=[]; accepted=0
 for i,d in enumerate(docs):
  neighbors=[]; known=set()
  if norm(d['text']):
   for band,value in enumerate(signature(d['text'])):
    key=(band,value); values=buckets[key]; position=positions[key][i]
    # Every record is visited.  Large LSH buckets use a deterministic cyclic
    # neighbor window instead of an unbounded all-pairs scan.
    for offset in range(1,min(len(values),cap)+1):
     other=values[(position+offset)%len(values)]
     if other!=i and other not in known: known.add(other); neighbors.append(other)
  neighbors.sort(key=lambda x:(docs[x]['id'],docs[x]['channel'],x)); offered.append(len(neighbors))
  for other in neighbors[:cap]:
   pair=(min(i,other),max(i,other))
   if pair in seen: continue
   seen.add(pair); left,right=docs[pair[0]],docs[pair[1]]; token,char=sim(left['text'],right['text'])
   if token<.58 and char<.62: continue
   accepted+=1; score=round(.6*token+.4*char,6); row={'left':ref(left),'right':ref(right),'token_jaccard':round(token,6),'character_ngram_similarity':round(char,6),'similarity':score,'similarity_channel':'token_jaccard' if token>=char else 'character_ngram','content_channels':sorted({left['channel'],right['channel']}),'scope':'same_domain' if left['domain']==right['domain'] else 'cross_domain','classification':'pending_human_review'}; queue.append(row); collisions[left['domain']]+=1; collisions[right['domain']]+=1
   if len(queue)>limit*2: queue=sorted(queue,key=lambda x:(-x['similarity'],x['left']['id'],x['right']['id']))[:limit]
 queue=sorted(queue,key=lambda x:(-x['similarity'],x['left']['id'],x['right']['id']))[:limit]
 return queue,collisions,{'documents_total':len(docs),'documents_processed':len(docs),'documents_with_lsh_neighbors':sum(bool(v) for v in offered),'per_document_neighbor_cap':cap,'documents_capped':sum(v>cap for v in offered),'candidate_pairs_examined':len(seen),'accepted_near_pairs':accepted,'silent_skips':0,'large_bucket_policy':'every document is processed; deterministic per-document neighbor caps are reported rather than skipping large buckets'}
def lexical(items):
 tokens=collections.Counter(t for item in items for t in w(item)); total=sum(tokens.values()); text=' '.join(items)
 return {'vocabulary_size':len(tokens),'singleton_rate':sum(v==1 for v in tokens.values())/max(1,len(tokens)),'token_entropy_bits':-sum((v/total)*math.log2(v/total) for v in tokens.values()) if total else 0.0,'top_20_token_concentration':sum(v for _,v in tokens.most_common(20))/max(1,total),'ascii_utterance_count':sum(all(ord(c)<128 for c in item) for item in items),'non_ascii_utterance_count':sum(any(ord(c)>=128 for c in item) for item in items),'heuristic_query_language_counts':{n:len(re.findall(p,text,re.I)) for n,p in HEURISTICS.items()}}
def audit():
 cards,utterances,hashes=read(); byid={c['id']:c for c in cards}; docs=[]
 for c in cards:
  for channel,fields in CHANNELS: docs.append({'kind':'card','channel':channel,'id':c['id'],'package':c['packageID'],'domain':c['domain'],'category':c['category'],'text':' '.join(flat(c.get(f,'')) for f in fields)})
 for u in utterances:
  c=byid[u['canonicalID']]; docs.append({'kind':'utterance','channel':'utterance','id':u['id'],'package':c['packageID'],'domain':c['domain'],'category':c['category'],'text':u['text']})
 duplicates=duplicate_maps(docs); queue,collision,generation=near(docs)
 # Exact and normalized cross-domain collisions are guaranteed candidates even
 # when bounded near-neighbor windows do not retain their LSH pair.
 duplicate_collision=collections.Counter()
 for channel in duplicates.values():
  for kind in ('exact','normalized'):
   for row in channel[kind]:
    if row['scope']=='cross_domain':
     for document in row['documents']: duplicate_collision[document['domain']]+=1
 collision.update(duplicate_collision)
 required_question_hash=sha(norm('Should EQ go before or after compression?'))
 required_question_duplicate=any(row['content_sha256']==required_question_hash and row['scope']=='cross_domain' for row in duplicates['question']['normalized'])
 uttered=collections.Counter(u['canonicalID'] for u in utterances); grouped={'per_package':collections.defaultdict(list),'per_domain':collections.defaultdict(list)}
 # Coverage includes every source card group, including intentionally empty
 # utterance populations, before individual utterances are accumulated.
 for card in cards:
  grouped['per_package'][card['packageID']]
  grouped['per_domain'][card['domain']]
 for u in utterances: c=byid[u['canonicalID']]; grouped['per_package'][c['packageID']].append(u['text']); grouped['per_domain'][c['domain']].append(u['text'])
 def cover(kind,key):
  field='packageID' if kind=='per_package' else 'domain'; selected=[c for c in cards if c[field]==key]; texts=grouped[kind][key]
  return {'cards':len(selected),'questions':len(selected),'retained_utterances':len(texts),'unique_utterances':len(set(texts)),'zero_utterance_cards':sum(not uttered[c['id']] for c in selected),'low_utterance_cards':sum(uttered[c['id']]<3 for c in selected),'lexical_language':lexical(texts)}
 coverage={kind:{key:cover(kind,key) for key in sorted(values)} for kind,values in grouped.items()}
 title_question=collections.defaultdict(list)
 for c in cards: title_question[norm(flat(c.get('title'))+' '+flat(c.get('question')))].append(c)
 structured=[]; conflicts=[]
 for values in title_question.values():
  for left,right in zip(values,values[1:]):
   semantic=lambda c:digest({group:{f:c.get(f) for f in fs} for group,fs in GROUPS.items() if group not in {'primary_identity','user_language','authority_provenance'}}); changed=[f for f in ('domain','category','topic','keyDistinction','userIntent') if left.get(f)!=right.get(f)]; row={'left_id':left['id'],'right_id':right['id'],'primary_user_language_equal':True,'different_assignments':changed,'classification':'pending_human_review'}
   if semantic(left)!=semantic(right): structured.append(row)
   if changed: conflicts.append(row)
 structured.sort(key=lambda x:(x['left_id'],x['right_id'])); conflicts.sort(key=lambda x:(x['left_id'],x['right_id']))
 presence={group:{field:{'present_card_count':sum(c.get(field) not in (None,[], '') for c in cards),'card_ratio':sum(c.get(field) not in (None,[], '') for c in cards)/len(cards)} for field in fields} for group,fields in GROUPS.items()}
 tokens=collections.Counter(t for u in utterances for t in w(u['text'])); dev=[x.get('query','') for x in json.loads(SUITE.read_text()) if x.get('partition')=='development']; qtokens=[t for q in dev for t in w(q)]
 boiler=[{'phrase':' '.join(p),'count':n,'classification':'pending_human_review'} for p,n in collections.Counter(tuple(w(u['text'])[:4]) for u in utterances if len(w(u['text']))>=4).most_common(128) if n>=8]
 required_lexical={'vocabulary_size','singleton_rate','token_entropy_bits','top_20_token_concentration','ascii_utterance_count','non_ascii_utterance_count','heuristic_query_language_counts'}
 coverage_complete=all(required_lexical.issubset(value['lexical_language']) for kind in coverage.values() for value in kind.values())
 complete=len(cards)==6212 and len(coverage['per_domain'])==40 and generation['documents_processed']==generation['documents_total'] and generation['silent_skips']==0 and set(duplicates)=={'title','question','combined_card','utterance'} and bool(presence) and coverage_complete and required_question_duplicate
 return {'schema_version':'retrieval-quality-recovery-audit/3','execution_authority':False,'source_input_hashes':hashes,'audit_logical_sha256':digest({'cards':cards,'utterances':utterances}),'card_count':len(cards),'domain_count':len(coverage['per_domain']),'utterance_count':len(utterances),'structured_field_groups':GROUPS,'field_presence_per_card_per_field':presence,'authority_provenance':'filter_eligibility_only_never_semantic_weight','duplicate_content_maps_by_channel':duplicates,'near_duplicate_candidates':{'generation':'six deterministic MinHash/LSH views, token Jaccard plus character 3-gram similarity',**generation,'ranked_collision_queue':queue,'same_domain':sum(x['scope']=='same_domain' for x in queue),'cross_domain':sum(x['scope']=='cross_domain' for x in queue)},'structured_field_only_distinctions':{'count':len(structured),'examples':structured[:128]},'broad_fine_sibling_collision_candidates':[x for x in queue if x['left']['domain']==x['right']['domain'] and x['left']['category']!=x['right']['category']][:128],'assignment_conflicts':{'normalized_identical_title_question_different_assignment':conflicts[:128],'canonical_cards_without_utterances':sorted(c['id'] for c in cards if not uttered[c['id']]),'utterances_with_missing_card':sorted(u['id'] for u in utterances if u['canonicalID'] not in byid)},'boilerplate_template_phrases':boiler,'coverage':{**coverage,'corpus_lexical_language':lexical([u['text'] for u in utterances]),'development_query_oov':{'suite_input_sha256':hashes['package019_evaluation_suite.json'],'query_count':len(dev),'token_count':len(qtokens),'oov_token_count':sum(t not in tokens for t in qtokens),'no_calibration_or_sealed_labels_used':True},'separately_weighted_field_coverage':{group:sum(v['card_ratio'] for v in fields.values())/max(1,len(fields)) for group,fields in presence.items()},'locale_language_limitation':'ASCII/non-ASCII is not locale identification or language-quality evidence.','english_only_boundary':'English-oriented source audit; no multilingual coverage claim.'},'completion':{'phase_0_full_audit_complete':complete,'all_documents_processed':generation['documents_processed']==generation['documents_total'],'zero_silent_skips':generation['silent_skips']==0,'required_cross_domain_question_duplicate':required_question_duplicate,'coverage_sections_complete':coverage_complete,'human_release_authority':False},'domain_collision_counts':dict(collision),'duplicate_collision_counts':dict(duplicate_collision)}
def pilot(a):
 cov=a['coverage']['per_domain']; collision=a['domain_collision_counts']; ranked=sorted(cov,key=lambda d:(-(collision.get(d,0)+cov[d]['zero_utterance_cards']*2+cov[d]['low_utterance_cards']*.1),d))[:8]
 return {'schema_version':'retrieval-quality-recovery-pilot/3','execution_authority':False,'selection':'eight highest frozen collision-plus-low-coverage scores','domains':[{'domain':d,'collision_plus_coverage_score':round(collision.get(d,0)+cov[d]['zero_utterance_cards']*2+cov[d]['low_utterance_cards']*.1,6),'rationale':'near-collision count plus zero/low utterance coverage'} for d in ranked],'slots':[{'slot_id':f'pilot-{d}-{n:02d}','domain':d,'review_status':'candidate_not_yet_human_reviewed','approval_status':'unapproved'} for d in ranked for n in range(1,11)],'remaining_720_approvals':'hard_stop_pending_all_80_human_pilot_approvals'}
def status(a): return {'schema_version':'retrieval-quality-recovery-status/3','execution_authority':False,'phase_0':{'full_audit':'complete' if a['completion']['phase_0_full_audit_complete'] else 'failed'},'pending_human_or_separate_authorship_gates':{'new_600_case_benchmark':True,'human_gold_adjudication':True,'xhigh_fresh_authorship_receipt':True,'sealed_blind_archive_hash':True,'pilot_80_approvals':True,'remaining_720_approvals':True,'release_architecture_selection':True,'blind_evaluation':True},'not_run':{'quantization':True,'installed_app':True,'Logic':True,'audio':True,'listening':True,'owner_usefulness':True,'release_acceptance':True}}
def synthetic_identity_test():
 a={'id':'a','packageID':'p','title':'same','question':'same'}; b={**a,'id':'b','packageID':'q'}; c={**a,'id':'c','title':'different'}; content=lambda x:sha(x['title']+'|'+x['question']); return content(a)==content(b) and content(a)!=content(c)
def main():
 parser=argparse.ArgumentParser(); [parser.add_argument(flag,action='store_true') for flag in ('--write','--check','--self-test')]; args=parser.parse_args(); value=audit(); selection=pilot(value); raw=json.dumps(value,indent=2,sort_keys=True)+'\n'; pilot_raw=json.dumps(selection,indent=2,sort_keys=True)+'\n'; status_raw=json.dumps(status(value),indent=2,sort_keys=True)+'\n'; markdown=f"# Retrieval corpus audit\n\nPre-human deterministic audit only; excluded from runtime and model context.\n\n- Cards: {value['card_count']}\n- Domains: {value['domain_count']}\n- Utterances: {value['utterance_count']}\n- Phase 0 full audit: {str(value['completion']['phase_0_full_audit_complete']).lower()}\n- Human/release gates: pending\n"
 if args.self_test:
  lexical_keys={'vocabulary_size','singleton_rate','token_entropy_bits','top_20_token_concentration','ascii_utterance_count','non_ascii_utterance_count','heuristic_query_language_counts'}
  packages={card['packageID'] for card in read()[0]}
  assert synthetic_identity_test() and value['card_count']==6212 and value['domain_count']==40 and len(value['coverage']['per_domain'])==40 and set(value['coverage']['per_package'])==packages and any(item['zero_utterance_cards'] or item['low_utterance_cards'] for item in value['coverage']['per_domain'].values()) and value['near_duplicate_candidates']['silent_skips']==0 and set(value['duplicate_content_maps_by_channel'])=={'title','question','combined_card','utterance'} and value['completion']['required_cross_domain_question_duplicate'] and value['completion']['coverage_sections_complete'] and all(lexical_keys.issubset(item['lexical_language']) for bucket in (value['coverage']['per_package'],value['coverage']['per_domain']) for item in bucket.values()) and len(selection['domains'])==8 and len(selection['slots'])==80 and len({slot['domain'] for slot in selection['slots']})==8; print('RETRIEVAL_QUALITY_RECOVERY_SELF_TEST_OK')
 if args.write: OUT.write_text(raw); MD.write_text(markdown); PILOT.write_text(pilot_raw); STATUS.write_text(status_raw)
 if args.check:
  if not OUT.exists() or OUT.read_text()!=raw or not MD.exists() or MD.read_text()!=markdown or not PILOT.exists() or PILOT.read_text()!=pilot_raw or not STATUS.exists() or STATUS.read_text()!=status_raw: raise SystemExit('recovery audit evidence is missing or stale; run --write')
  print('RETRIEVAL_CORPUS_AUDIT_OK cards=6212 domains=40 human_gates=pending')
if __name__=='__main__': main()
