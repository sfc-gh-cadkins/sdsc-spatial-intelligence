-- =============================================================================
-- 99 · Cleanup
-- =============================================================================
-- Removes ONLY the object this workshop created. It does not touch the
-- Marketplace listing or anything else in your account.
-- To also remove the listing database, drop it from Snowsight > Data Products
-- > Private Sharing / Marketplace, after confirming nothing else uses it.
-- =============================================================================

DROP WAREHOUSE IF EXISTS SDSC_WORKSHOP_WH;
