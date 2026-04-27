# WordPress Export Info (WXR)

**Export file:** migration/wordpress/export/xml/ialfm.WordPress.2026-04-24.xml  
**Export date:** 2026-04-24  
**Source site:** https://www.ialfm.org  
**Export method:** WordPress Admin → Tools → Export → All Content

## Validation (repo-local)
- Pages found (post_type=page): **106**  (see: migration/wordpress/transforms/audit-summary.txt)
- Duplicate slugs: **0**
- Empty slugs: **2**
- Published empty slugs: **0**

## Known exceptions
- Two pages have empty slugs and are not published, so they will be excluded from migration:
    - post_id=2236 (blank title)
    - post_id=2780 (“Ramadan 2025-1446”)

## WordPress settings snapshot (fill from WP)
- WordPress version: [Dashboard → Updates]
- Active theme: [Appearance → Themes]
- Permalink structure: [Settings → Permalinks] (expect /%postname%/)
- Front page displays: [Settings → Reading]
- Notes: Some legacy pages include demo/system slugs (WooCommerce and theme demo content).