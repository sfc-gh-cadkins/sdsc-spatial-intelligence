-- =============================================================================
-- 99 · Cleanup
-- =============================================================================
-- Removes ONLY the objects this workshop created. It does not touch the
-- Marketplace listing or anything else in your account.
-- To also remove the listing database, drop it from Snowsight > Data Products
-- > Private Sharing / Marketplace, after confirming nothing else uses it.
-- =============================================================================

DROP DATABASE IF EXISTS SDSC_WORKSHOP;    -- created by 04 and go-further, if you ran them
DROP WAREHOUSE IF EXISTS SDSC_WORKSHOP_WH;
