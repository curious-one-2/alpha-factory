import datetime

from pyspark.sql import DataFrame, SparkSession
import pyspark.sql.functions as F

def generate_time_dim(
    spark: SparkSession, catalog: str, schema: str, start_time: str = "00:00", end_time: str = "23:59"
):
  """Generates a minute-level time dimension DataFrame with derived attributes."""
  start_time2 = datetime.time.fromisoformat(start_time)
  end_time2 = datetime.time.fromisoformat(end_time)
  num_minutes = (
      end_time2.hour * 60
      + end_time2.minute
      - (start_time2.hour * 60 + start_time2.minute)
      + 1
  )

  # Datetime Combine Route: anchor time to a dummy date to perform timedelta math
  start_datetime = datetime.datetime.combine(datetime.date(2000, 1, 1), start_time2)

  time_data = [
      (start_datetime + datetime.timedelta(minutes=i),) for i in range(num_minutes)
  ]

  date_df = spark.createDataFrame(time_data, ["full_time"])


  # 2. Derive dimensional attributes with trading session buckets
  time_str = F.date_format("full_time", "HH:mm")
  
  # 2. Derive dimensional attributes with a unique daily time_key (0 to 1439)
  dim_time_df = date_df.select(
        (F.hour("full_time") * 60 + F.minute("full_time")).alias("time_key"),
        F.col("full_time"),
        F.hour("full_time").alias("hour"),
        F.minute("full_time").alias("minute"),
        F.when((time_str >= "04:00") & (time_str < "09:30"), "PRE_MARKET")
        .when((time_str >= "09:30") & (time_str < "10:00"), "MARKET_OPEN")
        .when((time_str >= "10:00") & (time_str < "15:00"), "MIDDAY")
        .when((time_str >= "15:00") & (time_str < "16:00"), "MARKET_CLOSE")
        .when((time_str >= "16:00") & (time_str <= "20:00"), "AFTER_HOURS")
        .otherwise("OVERNIGHT")
        .alias("trading_session"),
    )

  # 3. Create dummy row for UNKNOWN / NULL timestamps matching the exact schema
  schema_for_unknown = dim_time_df.schema
  unknown_data = [(-1, datetime.datetime(1900, 1, 1, 0, 0, 0), 0, 0, 'UNKNOWN')]
  unknown_row = spark.createDataFrame(unknown_data, schema=schema_for_unknown)

  # 4. Union and save to Gold layer storage in Delta format
  final_dim_time = unknown_row.union(dim_time_df)

  (
      final_dim_time.write.format("delta")
      .mode("overwrite")
      .saveAsTable(f"{catalog}.{schema}.gold_time_dimension")
  )

  print(
      "Time dimension successfully generated and saved. Total records:"
      f" {final_dim_time.count()}"
  )