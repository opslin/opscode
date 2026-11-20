-- Banners and audit-log schema extracted from Bakaloo migration 015_admin_dashboard.sql.
CREATE TABLE IF NOT EXISTS banners (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title         VARCHAR(200),
  subtitle      VARCHAR(300),
  image_url     TEXT NOT NULL,
  cta_text      VARCHAR(100),
  cta_link      TEXT,
  banner_type   VARCHAR(50) DEFAULT 'hero'
                  CHECK (banner_type IN ('hero', 'offer', 'popup', 'announcement', 'category')),
  display_order INTEGER DEFAULT 0,
  start_date    TIMESTAMPTZ,
  end_date      TIMESTAMPTZ,
  is_active     BOOLEAN DEFAULT true,
  created_by    UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_banners_active ON banners(is_active, display_order)
  WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_banners_dates  ON banners(start_date, end_date);

-- ═══════════════════════════════════════════════════════════════
-- 9. ADMIN ACTIVITY LOG (audit trail)
-- ═══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS admin_activity_log (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  admin_id    UUID REFERENCES users(id) NOT NULL,
  action      VARCHAR(200) NOT NULL,
  entity_type VARCHAR(50) NOT NULL,
  entity_id   UUID,
  old_value   JSONB,
  new_value   JSONB,
  ip_address  VARCHAR(50),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_aal_admin  ON admin_activity_log(admin_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_aal_entity ON admin_activity_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_aal_date   ON admin_activity_log(created_at DESC);
