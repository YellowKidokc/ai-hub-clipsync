"""
BetterTTS ↔ Theophysics Normalizer Bridge
==========================================
Called by BetterTTS.ahk to normalize clipboard/OCR text before speaking.

Usage:
  python normalize_bridge.py <input_file> <output_file>
  python normalize_bridge.py --stdin  (reads stdin, writes stdout)

Exit codes: 0 = success, 1 = error (raw text preserved)
"""

import sys
import os

# Add this directory to path so imports work
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from theophysics_normalizer import TheophysicsNormalizer


def main():
    # Build normalizer with TTS-optimized defaults
    normalizer = TheophysicsNormalizer(options={
        "remove_frontmatter": True,
        "remove_code_blocks": True,
        "remove_images": True,
        "remove_structural_index_block": True,
        "remove_media_callout_block": True,
        "process_tables": True,
        "table_mode": "narrative",
        "process_latex_blocks": True,
        "math_label_enabled": True,
        "math_label_text": "Math translation:",
        "unknown_math_policy": "placeholder",
        "remove_markdown_links": True,
        "remove_wiki_links": True,
        "remove_raw_urls": True,
        "dedupe_link_text": True,
        "remove_hashtags": True,
        "remove_inline_code": True,
        "remove_callouts": True,
        "remove_highlights": True,
        "remove_footnotes": True,
        "remove_comments": True,
        "remove_html_tags": True,
        "replace_comparison_symbols": True,
        "remove_markdown": True,
        "normalize_symbols": True,
        "normalize_greek": True,
        "normalize_special_letters": True,
        "normalize_subscripts": True,
        "normalize_superscripts": True,
        "normalize_axiom_refs": True,
        "normalize_law_refs": True,
        "optimize_numbers": True,
        "dedupe_lines": True,
        "clean_whitespace": True,
    })

    if len(sys.argv) >= 3 and sys.argv[1] != "--stdin":
        # File mode: read input file, write output file
        input_path = sys.argv[1]
        output_path = sys.argv[2]

        with open(input_path, "r", encoding="utf-8") as f:
            raw_text = f.read()

        normalized = normalizer.normalize(raw_text)

        with open(output_path, "w", encoding="utf-8") as f:
            f.write(normalized)

    elif "--stdin" in sys.argv:
        # Stdin/stdout mode
        raw_text = sys.stdin.read()
        normalized = normalizer.normalize(raw_text)
        sys.stdout.write(normalized)

    else:
        print("Usage: normalize_bridge.py <input> <output> | --stdin", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[ERROR] Normalizer bridge failed: {e}", file=sys.stderr)
        sys.exit(1)
