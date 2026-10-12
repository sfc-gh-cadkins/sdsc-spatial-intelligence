# =============================================================================
# Lab A (Python) · Where did Sandy hit Manhattan?          (pillar 1 · 3 min)
# =============================================================================
# Same question as 01_locations_and_types.sql, written with Snowpark Python:
# Which Manhattan ZIP codes filed the most Hurricane Sandy flood claims, and
# how far is each one from the southern tip, where the surge came ashore?
#
# Data: real FEMA NFIP claims and real ZIP code boundaries, both from the free
# "Snowflake Public Data (Free)" Marketplace listing. Nothing is made up.
#
# What you'll see:
#   TO_GEOGRAPHY turns a ZIP boundary stored as text into a real shape.
#   ST_AREA, ST_CENTROID and ST_DISTANCE measure it on the Earth's surface,
#   in metres, with no GIS tool and no export. In Python they are called via
#   snowflake.snowpark.functions, and all the work still runs in Snowflake.
#
# Privacy note: FEMA rounds public claim coordinates, so we count claims by
# the ZIP code FEMA assigns. We never place an individual claim on the map.
# =============================================================================

from snowflake.snowpark.context import get_active_session
from snowflake.snowpark import functions as F

session = get_active_session()
session.use_warehouse("SDSC_WORKSHOP_WH")
# session.use_warehouse("SDSC_WORKSHOP_WH_LARGE")   # <-- scaling: 16x compute, one line

LISTING_DB = "SNOWFLAKE_PUBLIC_DATA_FREE"   # <-- change if you renamed it
CLAIMS_TBL = f"{LISTING_DB}.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX"
GEO_CHARS = f"{LISTING_DB}.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS"
WITHIN_M = 3000                             # <-- TRY: change to 6000

# Sandy claims in Manhattan (New York County), counted by ZIP code.
manhattan_claims = (
    session.table(CLAIMS_TBL)
    .filter((F.col("FLOOD_EVENT") == "Hurricane Sandy")
            & (F.col("COUNTY_GEO_ID") == "geoId/36061"))
    .group_by("ZIP_GEO_ID")
    .agg(F.count(F.lit(1)).alias("CLAIMS"),
         F.round(F.avg("AMOUNT_PAID_ON_BUILDING_CLAIM")).alias("MEAN_BLDG_PAID"))
)

# Real ZIP boundaries, stored as WKT text, turned into GEOGRAPHY.
zip_shapes = (
    session.table(GEO_CHARS)
    .filter(F.col("RELATIONSHIP_TYPE") == "coordinates_wkt")
    .join(manhattan_claims.select("ZIP_GEO_ID"),
          F.col("GEO_ID") == F.col("ZIP_GEO_ID"), how="leftsemi")
    .select("GEO_ID", F.call_function("TO_GEOGRAPHY", F.col("VALUE")).alias("GEOG"))
)

# ZIP 10004 is the southern tip of Manhattan: Battery Park and the Financial District.
southern_tip = (
    zip_shapes.filter(F.col("GEO_ID") == "zip/10004")
    .select(F.call_function("ST_CENTROID", F.col("GEOG")).alias("PT"))
)

centroid = F.call_function("ST_CENTROID", F.col("GEOG"))
result = (
    manhattan_claims
    .join(zip_shapes, F.col("GEO_ID") == F.col("ZIP_GEO_ID"))
    .cross_join(southern_tip)
    .select(
        F.replace(F.col("ZIP_GEO_ID"), "zip/", "").alias("ZIP"),
        "CLAIMS",
        "MEAN_BLDG_PAID",
        F.round(F.call_function("ST_AREA", F.col("GEOG")) / 1e6, 2).alias("AREA_KM2"),
        F.round(F.call_function("ST_DISTANCE", centroid, F.col("PT")) / 1000, 1)
            .alias("KM_FROM_SOUTHERN_TIP"),
        F.call_function("ST_DWITHIN", centroid, F.col("PT"), F.lit(WITHIN_M))
            .alias("NEAR_SOUTHERN_TIP"),
    )
    .sort(F.col("CLAIMS").desc())
    .limit(10)
)

result.show()

# Expected (snapshot 2026-10-11; the listing refreshes, so expect small drift):
#   ZIP   | CLAIMS | KM_FROM_SOUTHERN_TIP | NEAR_SOUTHERN_TIP (3 km)
#   10009 |   94   |  4.9                 | FALSE   East Village
#   10013 |   80   |  3.1                 | FALSE   Tribeca / SoHo
#   10038 |   74   |  2.1                 | TRUE    Seaport
#   10011 |   62   |  5.5                 | FALSE   Chelsea
#   10029 |   58   | 12.5                 | FALSE   East Harlem
#   ... 10 rows. Only 10038 and 10004 are TRUE at 3 km.
#
# Interpret: the ZIP with the most claims is not at the tip. 10009 is the
# East Village, on the East River, and East Harlem, 12.5 km north, is fifth.
# The surge pushed up both rivers, not just into the Financial District.
#
# Your change: set WITHIN_M to 6000 and rerun. Five more ZIPs turn TRUE
# (10009, 10013, 10011, 10014, 10010). East Harlem (10029), 10128 and 10035
# stay FALSE: distance from the tip
# does not explain where Manhattan flooded.
