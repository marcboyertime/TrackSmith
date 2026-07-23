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
source_text_paths="$work_root/source-text-paths.tsv"
: > "$pdf_paths"
: > "$html_paths"
: > "$source_text_paths"

while IFS= read -r -d '' path; do
    hash="$(shasum -a 256 "$path" | awk '{print $1}')"
    relative="${path#"$repo_root/"}"
    printf '%s\t%s\n' "$hash" "$relative" >> "$pdf_paths"
done < <(find "$research_root" -type f -iname '*.pdf' \
    ! -path '*/quarantine/*' -print0)

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
done < <(find "$research_root" -type f \( -iname '*.html' -o -iname '*.htm' \) \
    ! -path '*/quarantine/*' -print0)

sort -o "$html_paths" "$html_paths"
printf 'sha256\tbytes\textracted_text_bytes\tcontent_status\tcanonical_path\tcopy_count\tall_paths\n' > "$analysis_root/html-index.tsv"

if [[ -s "$html_paths" ]]; then
    cut -f1 "$html_paths" | uniq | while IFS= read -r hash; do
        canonical_relative="$(awk -F '\t' -v h="$hash" '$1 == h { print $2; exit }' "$html_paths")"
        canonical="$repo_root/$canonical_relative"
        bytes="$(stat -f '%z' "$canonical")"
        copy_count="$(awk -F '\t' -v h="$hash" '$1 == h { count++ } END { print count + 0 }' "$html_paths")"
        all_paths="$(awk -F '\t' -v h="$hash" '$1 == h { if (paths != "") paths = paths " | "; paths = paths $2 } END { print paths }' "$html_paths")"
        extracted_text="$html_text_root/$hash.txt"
        extracted_text_bytes=0
        content_status=usable

        if [[ "$bytes" -eq 0 ]]; then
            : > "$extracted_text"
            content_status=empty
        elif textutil -convert txt -stdout "$canonical" > "$extracted_text" 2>/dev/null; then
            extracted_text_bytes="$(stat -f '%z' "$extracted_text")"
            non_whitespace_bytes="$(LC_ALL=C tr -d '[:space:]' < "$extracted_text" | wc -c | tr -d ' ')"
            if [[ "$non_whitespace_bytes" -eq 0 ]]; then
                content_status=unusable
            fi
        else
            : > "$extracted_text"
            content_status=unusable
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$hash" "$bytes" "$extracted_text_bytes" "$content_status" "$canonical_relative" "$copy_count" "$all_paths" \
            >> "$analysis_root/html-index.tsv"
    done
fi

# Preserve and account for supplied plain-text sources without mixing them with
# generated PDF/HTML extraction artifacts or archive README files. These files
# are source evidence in the TTA index, so omitting them would make a complete
# source-slot audit impossible.
while IFS= read -r -d '' path; do
    hash="$(shasum -a 256 "$path" | awk '{print $1}')"
    relative="${path#"$repo_root/"}"
    printf '%s\t%s\n' "$hash" "$relative" >> "$source_text_paths"
done < <(find "$research_root" -type f -iname '*.txt' \
    ! -path "$analysis_root/*" ! -path '*/quarantine/*' \
    ! -iname 'README.txt' -print0)

sort -o "$source_text_paths" "$source_text_paths"
printf 'sha256\tbytes\tcontent_status\tcanonical_path\tcopy_count\tall_paths\n' \
    > "$analysis_root/source-text-index.tsv"

if [[ -s "$source_text_paths" ]]; then
    cut -f1 "$source_text_paths" | uniq | while IFS= read -r hash; do
        canonical_relative="$(awk -F '\t' -v h="$hash" '$1 == h { print $2; exit }' "$source_text_paths")"
        canonical="$repo_root/$canonical_relative"
        bytes="$(stat -f '%z' "$canonical")"
        copy_count="$(awk -F '\t' -v h="$hash" '$1 == h { count++ } END { print count + 0 }' "$source_text_paths")"
        all_paths="$(awk -F '\t' -v h="$hash" '$1 == h { if (paths != "") paths = paths " | "; paths = paths $2 } END { print paths }' "$source_text_paths")"
        non_whitespace_bytes="$(LC_ALL=C tr -d '[:space:]' < "$canonical" | wc -c | tr -d ' ')"
        content_status=usable
        if [[ "$bytes" -eq 0 ]]; then
            content_status=empty
        elif [[ "$non_whitespace_bytes" -eq 0 ]]; then
            content_status=unusable
        fi

        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
            "$hash" "$bytes" "$content_status" "$canonical_relative" "$copy_count" "$all_paths" \
            >> "$analysis_root/source-text-index.tsv"
    done
fi

pdf_unique="$(($(wc -l < "$analysis_root/corpus-index.tsv") - 1))"
pdf_total="$(wc -l < "$pdf_paths" | tr -d ' ')"
html_unique="$(($(wc -l < "$analysis_root/html-index.tsv") - 1))"
html_total="$(wc -l < "$html_paths" | tr -d ' ')"
html_usable_unique="$(awk -F '\t' 'NR > 1 && $4 == "usable" { count++ } END { print count + 0 }' "$analysis_root/html-index.tsv")"
html_empty_unique="$(awk -F '\t' 'NR > 1 && $4 == "empty" { count++ } END { print count + 0 }' "$analysis_root/html-index.tsv")"
html_unusable_unique="$(awk -F '\t' 'NR > 1 && $4 == "unusable" { count++ } END { print count + 0 }' "$analysis_root/html-index.tsv")"
html_nonusable_files="$(awk -F '\t' 'NR > 1 && $4 != "usable" { count += $6 } END { print count + 0 }' "$analysis_root/html-index.tsv")"
source_text_unique="$(($(wc -l < "$analysis_root/source-text-index.tsv") - 1))"
source_text_total="$(wc -l < "$source_text_paths" | tr -d ' ')"
source_text_usable_unique="$(awk -F '\t' 'NR > 1 && $3 == "usable" { count++ } END { print count + 0 }' "$analysis_root/source-text-index.tsv")"

printf 'Indexed %s PDF files (%s unique), %s HTML files (%s unique hashes: %s usable, %s empty, %s unusable; %s non-usable files), and %s supplied TXT sources (%s unique: %s usable).\n' \
    "$pdf_total" "$pdf_unique" "$html_total" "$html_unique" "$html_usable_unique" \
    "$html_empty_unique" "$html_unusable_unique" "$html_nonusable_files" \
    "$source_text_total" "$source_text_unique" "$source_text_usable_unique"
