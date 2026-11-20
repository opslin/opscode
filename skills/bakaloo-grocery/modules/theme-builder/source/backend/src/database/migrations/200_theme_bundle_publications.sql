-- Standalone bundle: keep drafts in the upstream tables, with a durable
-- pointer to the last published version for each storefront tab.
CREATE TABLE theme_bundle_publications (
  tab_id uuid PRIMARY KEY REFERENCES theme_tabs(id) ON DELETE CASCADE,
  version_id uuid NOT NULL REFERENCES section_manifest_versions(id) ON DELETE RESTRICT,
  published_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE theme_bundle_media (
  id char(64) PRIMARY KEY,
  content_type text NOT NULL CHECK (content_type IN ('image/png', 'image/jpeg', 'image/webp')),
  content bytea NOT NULL CHECK (octet_length(content) BETWEEN 1 AND 5242880)
);

INSERT INTO users(id, phone, name, role)
VALUES ('00000000-0000-4000-8000-000000000321', '00000000321', 'Local Theme Editor', 'ADMIN');

INSERT INTO theme_tabs(store_key, key, label, audience, is_default)
SELECT 'zepto', 'all', 'Home', 'B2C', true
WHERE NOT EXISTS (
  SELECT 1 FROM theme_tabs WHERE store_key = 'zepto' AND key = 'all' AND audience = 'B2C' AND status = 'active'
);

INSERT INTO section_manifests(tab_id, section_type, config, audience)
SELECT id, 'text_header', '{"text":"Fresh picks for today","font_size":24,"color":"#215C49","alignment":"left"}', 'B2C'
FROM theme_tabs WHERE store_key = 'zepto' AND key = 'all' AND audience = 'B2C' AND status = 'active';

WITH seeded AS (
  INSERT INTO section_manifest_versions(tab_id, audience, version, snapshot, created_by)
  SELECT tab_id, 'B2C', 1, jsonb_agg(to_jsonb(section) ORDER BY sort_order, id),
         '00000000-0000-4000-8000-000000000321'
  FROM section_manifests section
  WHERE tab_id IN (
    SELECT id FROM theme_tabs WHERE store_key = 'zepto' AND key = 'all' AND audience = 'B2C' AND status = 'active'
  )
  GROUP BY tab_id
  RETURNING tab_id, id
)
INSERT INTO theme_bundle_publications(tab_id, version_id) SELECT tab_id, id FROM seeded;
