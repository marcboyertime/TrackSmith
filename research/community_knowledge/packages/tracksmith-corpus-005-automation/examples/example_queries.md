# Example Queries

```bash
python3 tools/query_corpus.py "why does my fader snap back"
python3 tools/query_corpus.py "Touch or Latch for a vocal ride"
python3 tools/query_corpus.py "track automation versus region automation"
python3 tools/query_corpus.py "automate one word into a delay throw"
python3 tools/query_corpus.py "why is my automation playing late"
python3 tools/query_corpus.py "volume automation before or after compression"
python3 tools/query_corpus.py "send automation or return automation"
python3 tools/query_corpus.py "mod wheel recorded into MIDI region"
python3 tools/query_corpus.py "VCA versus bus automation"
python3 tools/query_corpus.py "automation sounds right live but wrong in bounce"
```

Filter by subdomain:

```bash
python3 tools/query_corpus.py "fader snaps back" --subdomain troubleshooting
python3 tools/query_corpus.py "delay throw" --subdomain sends_effects
python3 tools/query_corpus.py "Touch Latch Write" --subdomain automation_modes
```

The command queries the package-local FTS5 database for inspection. TrackSmith production integration should preserve hybrid retrieval, metadata filtering, source diversity, and candidate evidence labels.
