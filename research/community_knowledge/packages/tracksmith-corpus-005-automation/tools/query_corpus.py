#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "database" / "corpus.sqlite"


def fts_query(text: str, require_all: bool) -> str:
    tokens = re.findall(r"[\w]+", text, flags=re.UNICODE)
    if not tokens:
        raise SystemExit("Query contained no searchable words.")
    quoted = ['"' + token.replace('"', '""') + '"' for token in tokens[:32]]
    return (" AND " if require_all else " OR ").join(quoted)


def main() -> None:
    parser = argparse.ArgumentParser(description="Query the package-local automation FTS database.")
    parser.add_argument("query")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--subdomain")
    parser.add_argument("--all-terms", action="store_true", help="Require every token instead of ranked OR retrieval")
    args = parser.parse_args()

    connection = sqlite3.connect(DB)
    sql = """
        SELECT c.id, c.subdomain, c.title, c.canonical_question, c.direct_answer,
               bm25(canonical_qa_fts) AS score
        FROM canonical_qa_fts f
        JOIN canonical_qa c ON c.id=f.id
        WHERE canonical_qa_fts MATCH ?
    """
    parameters: list[object] = [fts_query(args.query, args.all_terms)]
    if args.subdomain:
        sql += " AND c.subdomain=?"
        parameters.append(args.subdomain)
    sql += " ORDER BY score LIMIT ?"
    parameters.append(max(1, min(args.limit, 50)))
    rows = connection.execute(sql, parameters).fetchall()
    for index, row in enumerate(rows, 1):
        print(f"\n{index}. {row[0]} [{row[1]}] score={row[5]:.3f}\n{row[2]}\nQ: {row[3]}\nA: {row[4]}")
    if not rows:
        print("No matches.")
    connection.close()


if __name__ == "__main__":
    main()
