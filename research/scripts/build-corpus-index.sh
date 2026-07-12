#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
research_root="$repo_root/research"
analysis_root="$research_root/analysis"
text_root="$analysis_root/text"
html_text_root="$analysis_root/html-text"
work_root="${TMPDIR:-/tmp}/logic-audio-assistant-research-index"

command -v shasum >/dev/null
command -v pdfinfo >/dev/null
command -v pdftotext >/dev/null
command -v textutil >/dev/null

mkdir -p "$analysis_root" "$text_root" "$html_text_root"
rm -rf "$work_root"
mkdir -p "$work_root"

pdf_paths="$work_root/pdf-paths.tsv"
html_paths="$work_root/html-paths.tsv"
: > "$pdf_paths"
: > "$html_paths"

while IFS= read -r -d '' path; do
    hash="$(shasum -a 256 "$path" | awk '{print $1}')"
    relative="${path#"$repo_root/"}"
    printf '%s\t%s\n' "$hash" "$relative" >> "$pdf_paths"
done < <(find "$research_root" -type f -iname '*.pdf' -print0)

sort -o "$pdf_paths" "$pdf_paths"
printf 'sha256\tpages\tbytes\ttitle\tcanonical_path\tcopy_count\tall_paths\n' > "$analysis_root/corpus-index.tsv"

cut -f1 "$pdf_paths" | uniq | while IFS= read -r hash; do
    canonical_relative="$(awk -F '\t' -v h="$hash" '$1 == h { print $2; exit }' "$pdf_paths")"
    canonical="$repo_root/$canonical_relative"
    pages="$(pdfinfo "$canonical" 2>/dev/null | awk -F ':' '/^Pages:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }')"
    title="$(pdfinfo "$canonical" 2>/dev/null | awk -F ':' '/^Title:/ { sub(/^[^:]*:[[:space:]]*/, ""); print; exit }')"
    bytes="$(stat -f '%z' "$canonical")"
    copy_count="$(awk -F '\t' -v h="$hash" '$1 == h { count++ } END { print count + 0 }' "$pdf_paths")"
    all_paths="$(awk -F '\t' -v h="$hash" '$1 == h { if (paths != "") paths = paths " | "; paths = paths $2 } END { print paths }' "$pdf_paths")"
    title="$(printf '%s' "$title" | tr '\t\r\n' '   ')"
    all_paths="$(printf '%s' "$all_paths" | tr '\t\r\n' '   ')"
    pdftotext -layout -enc UTF-8 "$canonical" "$text_root/$hash.txt"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$hash" "${pages:-unknown}" "$bytes" "$title" "$canonical_relative" "$copy_count" "$all_paths" \
        >> "$analysis_root/corpus-index.tsv"
done

while IFS= read -r -d '' path; do
    hash="$(shasum -a 256 "$path" | awk '{print $1}')"
    relative="${path#"$repo_root/"}"
    printf '%s\t%s\n' "$hash" "$relative" >> "$html_paths"
done < <(find "$research_root" -type f \( -iname '*.html' -o -iname '*.htm' \) -print0)

sort -o "$html_paths" "$html_paths"
printf 'sha256\tbytes\tcanonical_path\tcopy_count\tall_paths\n' > "$analysis_root/html-index.tsv"

if [[ -s "$html_paths" ]]; then
    cut -f1 "$html_paths" | uniq | while IFS= read -r hash; do
        canonical_relative="$(awk -F '\t' -v h="$hash" '$1 == h { print $2; exit }' "$html_paths")"
        canonical="$repo_root/$canonical_relative"
        bytes="$(stat -f '%z' "$canonical")"
        copy_count="$(awk -F '\t' -v h="$hash" '$1 == h { count++ } END { print count + 0 }' "$html_paths")"
        all_paths="$(awk -F '\t' -v h="$hash" '$1 == h { if (paths != "") paths = paths " | "; paths = paths $2 } END { print paths }' "$html_paths")"
        textutil -convert txt -stdout "$canonical" > "$html_text_root/$hash.txt" 2>/dev/null || true
        printf '%s\t%s\t%s\t%s\t%s\n' "$hash" "$bytes" "$canonical_relative" "$copy_count" "$all_paths" \
            >> "$analysis_root/html-index.tsv"
    done
fi

pdf_unique="$(($(wc -l < "$analysis_root/corpus-index.tsv") - 1))"
pdf_total="$(wc -l < "$pdf_paths" | tr -d ' ')"
html_unique="$(($(wc -l < "$analysis_root/html-index.tsv") - 1))"
html_total="$(wc -l < "$html_paths" | tr -d ' ')"

printf 'Indexed %s PDF files (%s unique) and %s HTML files (%s unique).\n' \
    "$pdf_total" "$pdf_unique" "$html_total" "$html_unique"
