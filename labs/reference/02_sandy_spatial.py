# =============================================================================
# The Lab, in Python · Same script as 01_sandy_spatial.sql, with Snowpark
# =============================================================================
# Same three steps, same answers. Every spatial function still runs inside
# Snowflake; Python just builds the query. Run it in a Workspace as a Python
# file, or ask CoCo: "Convert 01_sandy_spatial.sql to Snowpark Python."
#
#   Step 1  Types      Manhattan ZIP codes as real shapes (GEOGRAPHY).
#   Step 2  Functions  Counties near Manhattan, ranked by COUNT and by MEAN.
#   Step 3  Surprise   Were these properties even in the flood zone?
# =============================================================================

from snowflake.snowpark.context import get_active_session
from snowflake.snowpark import functions as F
from snowflake.snowpark.window import Window

session = get_active_session()
session.use_warehouse("SDSC_WORKSHOP_WH")
# session.use_warehouse("SDSC_WORKSHOP_WH_LARGE")   # <-- scaling: 16x compute, one line

LISTING_DB = "SNOWFLAKE_PUBLIC_DATA_FREE"   # <-- change if you renamed it
CLAIMS_TBL = f"{LISTING_DB}.PUBLIC_DATA_FREE.FEMA_NATIONAL_FLOOD_INSURANCE_PROGRAM_CLAIM_INDEX"
GEO_CHARS = f"{LISTING_DB}.PUBLIC_DATA_FREE.GEOGRAPHY_CHARACTERISTICS"
GEO_INDEX = f"{LISTING_DB}.PUBLIC_DATA_FREE.GEOGRAPHY_INDEX"

# The three knobs. Each one changes the story.
WITHIN_M = 3000      # Step 1 <-- TRY: 6000
DISTANCE_M = 25000   # Step 2 <-- TRY: 75000
MIN_CLAIMS = 500     # Step 2 <-- TRY: 5000

geo = lambda fn, *args: F.call_function(fn, *args)   # shorthand for ST_* calls

claims = session.table(CLAIMS_TBL).filter(F.col("FLOOD_EVENT") == "Hurricane Sandy")
wkt = session.table(GEO_CHARS).filter(F.col("RELATIONSHIP_TYPE") == "coordinates_wkt")

# =============================================================================
# Step 1 · Types: which Manhattan ZIP codes filed the most Sandy claims?
# =============================================================================
manhattan_claims = (
    claims.filter(F.col("COUNTY_GEO_ID") == "geoId/36061")
    .group_by("ZIP_GEO_ID")
    .agg(F.count(F.lit(1)).alias("CLAIMS"),
         F.round(F.avg("AMOUNT_PAID_ON_BUILDING_CLAIM")).alias("MEAN_BLDG_PAID"))
)
zip_shapes = (
    wkt.join(manhattan_claims.select("ZIP_GEO_ID"),
             F.col("GEO_ID") == F.col("ZIP_GEO_ID"), how="leftsemi")
    .select("GEO_ID", geo("TO_GEOGRAPHY", F.col("VALUE")).alias("GEOG"))
)
southern_tip = (   # ZIP 10004: Battery Park, where the surge came ashore.
    zip_shapes.filter(F.col("GEO_ID") == "zip/10004")
    .select(geo("ST_CENTROID", F.col("GEOG")).alias("PT"))
)
centroid = geo("ST_CENTROID", F.col("GEOG"))

step1 = (
    manhattan_claims
    .join(zip_shapes, F.col("GEO_ID") == F.col("ZIP_GEO_ID"))
    .cross_join(southern_tip)
    .select(
        F.replace(F.col("ZIP_GEO_ID"), "zip/", "").alias("ZIP"),
        "CLAIMS",
        "MEAN_BLDG_PAID",
        F.round(geo("ST_AREA", F.col("GEOG")) / 1e6, 2).alias("AREA_KM2"),
        F.round(geo("ST_DISTANCE", centroid, F.col("PT")) / 1000, 1).alias("KM_FROM_SOUTHERN_TIP"),
        geo("ST_DWITHIN", centroid, F.col("PT"), F.lit(WITHIN_M)).alias("NEAR_SOUTHERN_TIP"),
    )
    .sort(F.col("CLAIMS").desc())
    .limit(10)
)
step1.show()
# Expected: 10009 East Village is #1 (94 claims, 4.9 km from the tip).
# Only 10038 and 10004 are TRUE at 3 km. Same as the SQL.

# =============================================================================
# Step 2 · Functions: counties near Manhattan, ranked two ways.
# =============================================================================
paid = F.col("AMOUNT_PAID_ON_BUILDING_CLAIM")
county_claims = (
    claims.filter(F.col("STATE_GEO_ID").isin("geoId/36", "geoId/34")
                  & F.col("COUNTY_GEO_ID").is_not_null())
    .group_by("COUNTY_GEO_ID")
    .agg(F.count(F.lit(1)).alias("CLAIM_RECORDS"),
         F.count(paid).alias("PAID_DENOMINATOR"),
         F.avg(paid).alias("MEAN_BLDG_PAID_USD"))
    .with_column("PAID_MISSING", F.col("CLAIM_RECORDS") - F.col("PAID_DENOMINATOR"))
    .filter(F.col("CLAIM_RECORDS") >= MIN_CLAIMS)
)
latest = Window.partition_by("GEO_ID").order_by(F.col("RELATIONSHIP_START_DATE").desc_nulls_last())
county_shapes = (
    wkt.filter(F.col("GEO_ID").like("geoId/%"))
    .with_column("RN", F.row_number().over(latest)).filter(F.col("RN") == 1)
    .select("GEO_ID", geo("TRY_TO_GEOGRAPHY", F.col("VALUE")).alias("BOUNDARY"))
)
manhattan = (county_shapes.filter(F.col("GEO_ID") == "geoId/36061")
             .select(F.col("BOUNDARY").alias("MANHATTAN")))

step2 = (
    county_claims
    .join(county_shapes, F.col("GEO_ID") == F.col("COUNTY_GEO_ID"))
    .cross_join(manhattan)
    .filter(geo("ST_DWITHIN", F.col("BOUNDARY"), F.col("MANHATTAN"), F.lit(DISTANCE_M)))
    .with_column("KM_FROM_MANHATTAN",
                 F.round(geo("ST_DISTANCE", F.col("BOUNDARY"), F.col("MANHATTAN")) / 1000, 1))
    .join(session.table(GEO_INDEX).select(F.col("GEO_ID").alias("GID"), F.col("GEO_NAME").alias("COUNTY")),
          F.col("GID") == F.col("COUNTY_GEO_ID"))
    .select(
        "COUNTY", "CLAIM_RECORDS", "PAID_MISSING",
        F.round("MEAN_BLDG_PAID_USD").alias("MEAN_BLDG_PAID_USD"),
        "KM_FROM_MANHATTAN",
        F.rank().over(Window.order_by(F.col("CLAIM_RECORDS").desc())).alias("RANK_BY_COUNT"),
        F.rank().over(Window.order_by(F.col("MEAN_BLDG_PAID_USD").desc())).alias("RANK_BY_MEAN_PAID"),
    )
    .sort("RANK_BY_COUNT")
)
step2.show(20)
# Expected (25 km): 10 counties. Nassau #1 by count. Manhattan #9 by count,
# #1 by mean paid ($236,483). Ocean County is missing (60.6 km away).
# Your change: DISTANCE_M = 75000. Ocean County appears at #1.

# =============================================================================
# Step 3 · The surprise: were these properties even in the flood zone?
# =============================================================================
outside = ~F.upper(F.col("POLICY_RATED_FLOOD_ZONE")).like("SPECIAL FLOOD%")
step3 = (
    claims.filter(F.col("COUNTY_GEO_ID") == "geoId/36061")
    .group_by("ZIP_GEO_ID")
    .agg(F.count(F.lit(1)).alias("CLAIMS"),
         F.sum(F.iff(outside, 1, 0)).alias("OUTSIDE_HIGH_RISK_ZONE"))
    .select(F.replace(F.col("ZIP_GEO_ID"), "zip/", "").alias("ZIP"),
            "CLAIMS", "OUTSIDE_HIGH_RISK_ZONE",
            F.round(100 * F.col("OUTSIDE_HIGH_RISK_ZONE") / F.col("CLAIMS")).alias("PCT_OUTSIDE"))
    .sort(F.col("CLAIMS").desc())
    .limit(10)
)
step3.show()
# Expected: East Harlem (10029) 50% outside, East Village (10009) 33%.
# The flood map said these places were lower risk. The water disagreed.
