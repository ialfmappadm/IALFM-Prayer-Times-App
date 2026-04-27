# URL & Slug Preservation Policy (IALFM)

## Goal
Preserve WordPress page URLs by preserving WordPress `post_name` as the canonical legacy slug list.

## Evidence
- Pages found: 106
- Duplicate slugs: 0
- Legacy slugs exported to: migration/wordpress/transforms/legacy-slugs.txt

## Directus fields (Pages collection)
- slug (string, unique, required): public route path
- legacy_slug (string, unique, read-only/hidden): original WordPress slug
- legacy_wp_id (int, read-only): original WordPress post_id
- publish_status (publish/draft/private/...): based on wp:status

## Rules
1. Migrated pages:
    - legacy_slug MUST match WordPress post_name exactly.
    - slug SHOULD match legacy_slug initially to preserve URLs.
2. New admin-created pages:
    - slug must be unique
    - slug must NOT match any legacy_slug
3. Prevent conflicts:
    - Make legacy_slug read-only and hidden from non-technical roles
    - Unique constraints on slug and legacy_slug

## Empty slug items
Two items had empty slugs and published-empty-slugs=0 (exclude them from migration).