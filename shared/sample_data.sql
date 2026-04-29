-- ============================================================
-- shared/sample_data.sql
-- Reusable seed INSERT statements for DEALS table.
-- Used by both the SiS and Native App demos.
-- Run this AFTER creating the target table.
-- ============================================================

-- Sales reps, regions, and deals:
--   ALICE_WEST  → West region (2 deals)
--   BOB_EAST    → East region (2 deals)
--   CAROL_EAST  → East region (2 deals)

INSERT INTO deals (rep_name, region, deal_name, amount) VALUES
  ('ALICE_WEST',  'West', 'Acme Corp',        45000),
  ('ALICE_WEST',  'West', 'Widget Inc',        32000),
  ('BOB_EAST',    'East', 'Globex Corp',       78000),
  ('BOB_EAST',    'East', 'Initech',           55000),
  ('CAROL_EAST',  'East', 'Umbrella Corp',     91000),
  ('CAROL_EAST',  'East', 'Soylent Corp',      67000);
