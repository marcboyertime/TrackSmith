# Example Queries

```bash
python3 tools/query_corpus.py --database /path/to/unified_corpus.sqlite "vocal clearer but thin"
python3 tools/query_corpus.py --database /path/to/unified_corpus.sqlite "why does low latency mode disable plugins"
python3 tools/query_corpus.py --database /path/to/unified_corpus.sqlite "make it tighter" --show-diagnostics
```

The first two should return a bounded cross-package set. The final query should display ambiguity rather than pretending one top result is definitive.
