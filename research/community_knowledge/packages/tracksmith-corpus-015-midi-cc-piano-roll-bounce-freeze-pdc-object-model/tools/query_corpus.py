#!/usr/bin/env python3
from __future__ import annotations
import argparse
import re
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / "database" / "corpus.sqlite"
STOP = {
    "a", "an", "and", "are", "as", "at", "be", "between", "difference",
    "but", "by", "can", "could", "do", "does", "for", "from", "how", "i",
    "in", "is", "it", "my", "of", "on", "or", "should", "the", "this", "to",
    "versus", "vs", "what", "when", "why", "with",
}

def tokenize(text: str) -> list[str]:
    values = re.findall(r"[\w]+", text.casefold(), flags=re.UNICODE)
    values = [value for value in values if value not in STOP and len(value) > 1]
    if not values:
        raise SystemExit("Query contained no searchable terms.")
    return values[:32]

def expression(values: list[str], require_all: bool) -> str:
    quoted = ['"' + value.replace('"', '""') + '"' for value in values]
    return (" AND " if require_all else " OR ").join(quoted)

def lexical_score(values: list[str], title: str, question: str, answer: str) -> float:
    title_l, question_l, answer_l = title.casefold(), question.casefold(), answer.casefold()
    score = 0.0
    for value in values:
        if re.search(rf"\b{re.escape(value)}\b", title_l):
            score += 12.0
        elif re.search(rf"\b{re.escape(value)}\b", question_l):
            score += 7.0
        elif re.search(rf"\b{re.escape(value)}\b", answer_l):
            score += 2.0
    # Reward adjacent query concepts in title/question even when the user omitted stopwords.
    for left, right in zip(values, values[1:]):
        pair = re.compile(rf"\b{re.escape(left)}\b.{0,20}\b{re.escape(right)}\b")
        reverse = re.compile(rf"\b{re.escape(right)}\b.{0,20}\b{re.escape(left)}\b")
        if pair.search(title_l) or reverse.search(title_l): score += 10.0
        elif pair.search(question_l) or reverse.search(question_l): score += 5.0
    return score

def fetch(connection, values, subdomain, require_all):
    sql = """
        SELECT c.id, c.subdomain, c.title, c.canonical_question, c.direct_answer,
               bm25(canonical_qa_fts) AS bm25_score
        FROM canonical_qa_fts f
        JOIN canonical_qa c ON c.id=f.id
        WHERE canonical_qa_fts MATCH ?
    """
    parameters: list[object] = [expression(values, require_all)]
    if subdomain:
        sql += " AND c.subdomain=?"
        parameters.append(subdomain)
    sql += " ORDER BY bm25_score LIMIT 200"
    return connection.execute(sql, parameters).fetchall()

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Query the Package 015 MIDI CC, Piano Roll, bounce/export, freeze/CPU, PDC/Low Latency, and Logic object-model FTS database."
    )
    parser.add_argument("query")
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--subdomain")
    parser.add_argument(
        "--all-terms", action="store_true",
        help="Require all significant tokens and do not fall back to broader OR retrieval."
    )
    args = parser.parse_args()
    values = tokenize(args.query)
    connection = sqlite3.connect(DB)
    rows = fetch(connection, values, args.subdomain, True)
    if not rows and not args.all_terms:
        rows = fetch(connection, values, args.subdomain, False)
    ranked = sorted(
        rows,
        key=lambda row: (-lexical_score(values, row[2], row[3], row[4]), row[5], row[0]),
    )[: max(1, min(args.limit, 50))]
    for index, row in enumerate(ranked, 1):
        lex = lexical_score(values, row[2], row[3], row[4])
        print(
            f"\n{index}. {row[0]} [{row[1]}] lexical={lex:.1f} bm25={row[5]:.3f}\n"
            f"{row[2]}\nQ: {row[3]}\nA: {row[4]}"
        )
    if not ranked:
        print("No matches.")
    connection.close()

if __name__ == "__main__":
    main()
