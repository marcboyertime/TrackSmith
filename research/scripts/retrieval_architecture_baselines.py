#!/usr/bin/env python3
"""Distinct float-only observed-regression retrieval diagnostics; never release selection."""
import argparse, collections, json, math, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; PROJECTION=ROOT/'research/community_knowledge/runtime_projection/p16'; SUITE=ROOT/'research/tutor_quality/package019_evaluation_suite.json'; OUT=ROOT/'docs/evidence/RETRIEVAL_ARCHITECTURE_OBSERVED_ABLATION.json'
GROUPS={"primary_identity":["domain","category","title","question"],"user_language":["title","question","tags","clarificationQuestions"],"intent_facets":["category","tags","roleFacets","sectionFacets","userIntent"],"diagnostic_context":["competingHypotheses","keyDistinction","evidenceNeeded"],"listening_experiment_context":["recommendedFirstExperiment","firstExperiment","listenFor","listeningCues","stopOrUndo"]}
SEMANTIC_FIELDS=tuple(dict.fromkeys(field for fields in GROUPS.values() for field in fields))
def w(x): return re.findall(r'[a-z0-9]+',str(x).lower())
def flat(x): return ' '.join(x) if isinstance(x,list) else str(x or '')
def text(c,fields=None): return ' '.join(flat(c.get(field,'')) for field in (fields or ['domain','category','title','question','tags']))
def load():
 cards=[]
 for p in sorted(PROJECTION.glob('*.json')): cards.extend(json.loads(p.read_text())['canonicalCards'])
 return cards
def corpus_stats(docs):
 df=collections.Counter(); tokens=[]
 for doc in docs: value=w(doc); tokens.append(value); df.update(set(value))
 return df,len(docs),sum(map(len,tokens))/max(1,len(tokens))
def vector(tokens,df,n): return collections.Counter({t:(1+math.log(v))*math.log((1+n)/(1+df.get(t,0))) for t,v in collections.Counter(tokens).items() if t in df})
def cosine(a,b): return sum(a[k]*b.get(k,0.0) for k in a)/(math.sqrt(sum(v*v for v in a.values()))*math.sqrt(sum(v*v for v in b.values())) or 1.0)
def bm25(query,document,df,n,average):
 counts=document if isinstance(document,collections.Counter) else collections.Counter(w(document)); length=sum(counts.values()); return sum(math.log((n-df[t]+.5)/(df[t]+.5)+1)*((counts[t]*2)/(counts[t]+1.2*(.25+.75*length/(average or 1)))) for t in w(query) if t in counts)
def family(card): return card['domain']+'/'+card['category']
def label_for_domain(domain,cards,labels):
 if domain in labels: return domain
 source=set(w(domain+' '+' '.join(cards[i]['category'] for i in range(len(cards)) if cards[i]['domain']==domain)))
 return max(labels,key=lambda label:(len(source&set(w(label))),label))
def mean_vectors(vectors):
 out=collections.Counter()
 for vector_ in vectors: out.update(vector_)
 return collections.Counter({key:value/len(vectors) for key,value in out.items()}) if vectors else collections.Counter()
def rankers(cards):
 # All semantic groups share one frozen vocabulary/DF.  This keeps terms found
 # only in diagnostic/listening fields available to their field centroids.
 all_docs=[text(card,SEMANTIC_FIELDS) for card in cards]; all_counts=[collections.Counter(w(doc)) for doc in all_docs]; df,n,avg=corpus_stats(all_docs); card_vectors=[vector(w(doc),df,n) for doc in all_docs]
 domains=collections.defaultdict(list); families=collections.defaultdict(list)
 for i,card in enumerate(cards): domains[card['domain']].append(i); families[family(card)].append(i)
 def synth(groups,fields=None):
  keys=sorted(groups); docs=[' '.join(text(cards[i],fields or SEMANTIC_FIELDS) for i in groups[key]) for key in keys]; sdf,sn,savg=corpus_stats(docs); return keys,dict(zip(keys,docs)),sdf,sn,savg
 def card_bm25(query):
  scores={key:sorted((bm25(query,all_counts[i],df,n,avg),i) for i in ids)[-2:] for key,ids in domains.items()}; return sorted(domains,key=lambda key:(-sum(score for score,_ in scores[key]),key))
 dk,dd,ddf,dn,davg=synth(domains); fk,fd,fdf,fn,favg=synth(families)
 def domain_bm25(query): return sorted(dk,key=lambda key:(-bm25(query,dd[key],ddf,dn,davg),key))
 def family_bm25(query): return sorted(fk,key=lambda key:(-bm25(query,fd[key],fdf,fn,favg),key))
 def centroids(groups,fields=None):
  keys=sorted(groups); per_card=card_vectors if fields is None else [vector(w(text(card,fields)),df,n) for card in cards]; values={key:mean_vectors([per_card[i] for i in groups[key]]) for key in keys}
  def run(query):
   q=vector(w(query),df,n); return sorted(keys,key=lambda key:(-cosine(q,values[key]),key))
  return run,values
 domain_tfidf,domain_vectors=centroids(domains); family_tfidf,family_vectors=centroids(families)
 structured_vectors={group:centroids(domains,fields)[1] for group,fields in GROUPS.items()}
 def weighted_factory(excluded_groups=()):
  excluded=set(excluded_groups)
  def weighted(query):
   total=collections.Counter(); q=vector(w(query),df,n)
   for group,weight in [('primary_identity',2.0),('user_language',1.5),('intent_facets',1.25),('diagnostic_context',1.0),('listening_experiment_context',.75)]:
    if group not in excluded:
     for key,value in structured_vectors[group].items(): total[key]+=weight*cosine(q,value)
   return sorted(domains,key=lambda key:(-total[key],key))
  return weighted
 weighted=weighted_factory()
 vocab=set(df); total=collections.Counter(t for doc in all_docs for t in w(doc)); family_counts={key:collections.Counter(t for i in ids for t in w(all_docs[i])) for key,ids in families.items()}
 def cnb(query):
  scores={}
  for key,count in family_counts.items():
   complement=total-count; denominator=sum(complement.values())+len(vocab); scores[key]=sum(-math.log((complement[t]+1.0)/denominator) for t in w(query))
  return sorted(families,key=lambda key:(-scores[key],key))
 structured_cells=sum(len(value) for vectors in structured_vectors.values() for value in vectors.values()); cnb_cells=sum(len(value) for value in family_counts.values())+len(family_counts)
 cells=sum(len(value) for value in card_vectors)+sum(len(value) for value in domain_vectors.values())+sum(len(value) for value in family_vectors.values())+structured_cells+cnb_cells
 return {'card_bm25_domain_aggregation':(card_bm25,domains),'domain_bm25_synthesized':(domain_bm25,domains),'candidate_family_bm25':(family_bm25,families),'domain_tfidf_centroid_equal_prior':(domain_tfidf,domains),'candidate_family_tfidf_centroid_equal_prior':(family_tfidf,families),'weighted_structured_field_centroid':(weighted,domains),'equal_prior_complement_nb_float':(cnb,families)}, {'semantic_card_text_utf8':sum(len(doc.encode()) for doc in all_docs),'sparse_float_parameter_cells':cells,'estimated_float_parameter_bytes':cells*8,'size_observation':'non-serialized logical float64 estimate; not an index artifact byte measurement','centroid_construction':'arithmetic mean of each representation\'s per-card vectors under one frozen semantic vocabulary and IDF'}, weighted_factory
def labels_for(order,domain_labels):
 output=[]
 for group in order:
  domain=group.split('/')[0] if '/' in group else group; label=domain_labels[domain]
  if label not in output: output.append(label)
  if len(output)==4: break
 return output
def evaluate(rank,groups,cards,cases,labels):
 top1=top4=eligible=0; per=collections.defaultdict(collections.Counter)
 domain_members=collections.defaultdict(list)
 for i,card in enumerate(cards): domain_members[card['domain']].append(i)
 domain_labels={domain:label_for_domain(domain,[cards[i] for i in ids],labels) for domain,ids in domain_members.items()}
 for case in cases:
  wanted=set(case.get('acceptable_diagnosis_families',[])); query=case.get('query','')
  if not wanted or not query: continue
  eligible+=1; predicted=labels_for(rank(query),domain_labels); one=bool(predicted and predicted[0] in wanted); four=bool(set(predicted)&wanted); top1+=one; top4+=four
  for label in wanted: per[label].update(eligible=1,top4=int(four))
 return {'observed_cases':eligible,'top1_diagnosis_family_matches':top1,'top4_diagnosis_family_matches':top4,'top1_rate':top1/max(1,eligible),'top4_rate':top4/max(1,eligible),'worst_diagnosis_family_top4_rate':min((x['top4']/x['eligible'] for x in per.values()),default=0.0),'top_four_distinct_diagnosis_groups':True,'deterministic_operation_count':eligible*len(cards),'latency_measurement_status':'excluded_from_reproducible_evidence','float_only':True,'quantization_or_pruning':'not_run'}, {key:{'eligible':x['eligible'],'top4':x['top4']} for key,x in sorted(per.items())}
def report():
 cards=load(); cases=json.loads(SUITE.read_text()); labels=sorted({label for case in cases for label in case.get('acceptable_diagnosis_families',[]) }); methods,size_observation,weighted_factory=rankers(cards); values={}; details={}
 for name,(rank,groups) in methods.items(): values[name],details[name]=evaluate(rank,groups,cards,cases,labels)
 ablations={}
 for removed in GROUPS:
  rank=weighted_factory((removed,)); result,_=evaluate(rank,methods['weighted_structured_field_centroid'][1],cards,cases,labels); full=values['weighted_structured_field_centroid']; ablations[removed]={'removed_group':removed,**result,'top1_delta_from_full':result['top1_rate']-full['top1_rate'],'top4_delta_from_full':result['top4_rate']-full['top4_rate']}
 base=values['card_bm25_domain_aggregation']['top4_rate']
 return {'schema_version':'retrieval-architecture-observed-ablation/4','execution_authority':False,'evidence_class':'Package 019 240-case observed regression only; not blind, held-out, or release authority','label_source':'direct card.domain is used when available; otherwise a deterministic diagnostic lexical fallback maps candidate domain/category to observed labels, never card gold labels','candidate_domain_category_families':'candidate_not_yet_human_reviewed diagnostic only','float_only':True,'quantization_or_pruning':'not_run','methods':values,'per_method_diagnosis_family_counts':details,'per_method_top4_difference_from_card_bm25':{key:value['top4_rate']-base for key,value in values.items()},'structured_field_ablation':{'full_weighted':values['weighted_structured_field_centroid'],'remove_one_group':ablations,'groups':GROUPS,'authority_provenance':'filter_only_never_semantic_weight'},'index_model_size_observation':size_observation,'conclusion':'No architecture is selected; observed scores cannot authorize release selection.'}
def main():
 parser=argparse.ArgumentParser(); [parser.add_argument(flag,action='store_true') for flag in ('--write','--check','--self-test')]; args=parser.parse_args(); value=report(); raw=json.dumps(value,indent=2,sort_keys=True)+'\n'
 if args.self_test:
  cards=[{'id':'a','domain':'vocal','category':'tone','title':'muddy vocal','question':'muddy vocal','tags':['muddy']},{'id':'b','domain':'timing','category':'grid','title':'late groove','question':'late groove','tags':['late']},{'id':'c','domain':'vocal','category':'level','title':'vocal level','question':'vocal level','tags':['level']}]
  assert mean_vectors([collections.Counter({'a':2.0,'b':4.0}),collections.Counter({'a':4.0})]) == collections.Counter({'a':3.0,'b':2.0})
  methods,_,weighted_factory=rankers(cards); rank,_=methods['domain_bm25_synthesized']; order=rank('muddy vocal'); assert order[0]=='vocal' and len(order)==len(set(order))
  rank,_=methods['domain_tfidf_centroid_equal_prior']; assert rank('muddy vocal')[0]=='vocal'
  assert all(len(rank('muddy vocal'))==len(set(rank('muddy vocal'))) for rank,_ in methods.values()) and all(len(weighted_factory((group,))('muddy vocal'))==len(set(weighted_factory((group,))('muddy vocal'))) for group in GROUPS) and 'latency_ms' not in raw and all(value['methods'][name]['top_four_distinct_diagnosis_groups'] for name in value['methods'])
  print('RETRIEVAL_ARCHITECTURE_BASELINES_SELF_TEST_OK')
 if args.write: OUT.write_text(raw)
 if args.check:
  if not OUT.exists() or OUT.read_text()!=raw: raise SystemExit('architecture observed evidence is missing or stale; run --write')
  print('RETRIEVAL_ARCHITECTURE_OBSERVED_ABLATION_OK authority=false release_selection=pending')
if __name__=='__main__': main()
