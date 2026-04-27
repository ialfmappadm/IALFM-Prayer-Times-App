#!/usr/bin/env python3
import sys, re, csv, html, os
import xml.etree.ElementTree as ET
from collections import Counter

def normalize_text(s: str) -> str:
    if s is None:
        return ""
    s = s.strip()
    s = html.unescape(s).strip()
    # Strip literal CDATA wrapper if it appears as text (rare but seen)
    s = re.sub(r"^<!\[CDATA\[(.*)\]\]>$", r"\1", s, flags=re.DOTALL).strip()
    return s

def find_text(parent, tag_suffix):
    for child in parent:
        # Use suffix match to ignore namespaces: {uri}tag or wp:tag
        if child.tag.endswith(tag_suffix):
            return normalize_text(child.text or "")
    return ""

def main(xml_path: str):
    tree = ET.parse(xml_path)
    root = tree.getroot()

    # Find <channel>
    channel = None
    for child in root:
        if child.tag.endswith("channel"):
            channel = child
            break
    if channel is None:
        print("ERROR: Could not find <channel> in XML.")
        sys.exit(1)

    items = [c for c in channel if c.tag.endswith("item")]

    pages = []
    for item in items:
        post_type = find_text(item, "post_type")
        if post_type != "page":
            continue

        row = {
            "post_id": find_text(item, "post_id"),
            "title": find_text(item, "title"),
            "slug": find_text(item, "post_name"),
            "publish_status": find_text(item, "status"),          # publish/draft/private
            "comment_status": find_text(item, "comment_status"),  # open/closed
            "post_date": find_text(item, "post_date"),
            "post_parent": find_text(item, "post_parent"),
            "menu_order": find_text(item, "menu_order"),
            "link": find_text(item, "link"),
        }
        pages.append(row)

    os.makedirs("migration/wordpress/transforms", exist_ok=True)

    # Summaries
    slugs = [p["slug"] for p in pages]
    slug_counts = Counter([s for s in slugs if s])
    empty_slug_pages = [p for p in pages if p["slug"] == ""]
    dup_slugs = {s: c for s, c in slug_counts.items() if c > 1}

    published_empty = [p for p in empty_slug_pages if p["publish_status"] == "publish"]

    print(f"Pages found (post_type=page): {len(pages)}")
    print(f"Empty slugs: {len(empty_slug_pages)}")
    print(f"  Published with empty slug: {len(published_empty)}")
    print(f"Duplicate slugs: {len(dup_slugs)}")

    # Outputs
    out_csv = "migration/wordpress/transforms/pages-audit.csv"
    out_slugs = "migration/wordpress/transforms/legacy-slugs.txt"
    out_summary = "migration/wordpress/transforms/audit-summary.txt"

    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "post_id","publish_status","comment_status","slug","title",
            "post_date","post_parent","menu_order","link"
        ]
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        w.writerows(pages)

    with open(out_slugs, "w", encoding="utf-8") as f:
        for s in sorted(set([x for x in slugs if x])):
            f.write(s + "\n")

    with open(out_summary, "w", encoding="utf-8") as f:
        f.write(f"Pages found: {len(pages)}\n")
        f.write(f"Empty slugs: {len(empty_slug_pages)}\n")
        f.write(f"Published empty slugs: {len(published_empty)}\n")
        if empty_slug_pages:
            f.write("Empty slug pages (post_id → publish_status → title → link):\n")
            for p in empty_slug_pages:
                f.write(f"  {p['post_id']} → {p['publish_status']} → {p['title']} → {p['link']}\n")
        f.write(f"Duplicate slugs: {len(dup_slugs)}\n")
        if dup_slugs:
            f.write("Duplicate slugs (slug → count):\n")
            for s,c in sorted(dup_slugs.items(), key=lambda x: (-x[1], x[0])):
                f.write(f"  {s} → {c}\n")

    print(f"✅ Wrote:\n  - {out_csv}\n  - {out_slugs}\n  - {out_summary}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: audit-wp-export.py path/to/wordpress.xml")
        sys.exit(1)
    main(sys.argv[1])