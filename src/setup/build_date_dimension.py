from pyspark.sql import SparkSession, functions as F, DataFrame
import datetime
#from utils.spark_session import get_spark_session
#from core.config  import settings

# get access to the src folder
#import sys
#from pathlib import Path
#sys.path.append(str(Path.cwd().parent))

#gold_layer_path = settings["storage_paths"]["gold"]

def generate_date_dim(spark: SparkSession, catalog: str, schema: str, start_date: str='2026-10-01', end_date: str='2030-10-31'):
    """
    Generates a date dimension DataFrame with various date attributes.

    Args:
        spark (SparkSession): The SparkSession instance.
        start_date (str): The start date in 'YYYY-MM-DD' format.
        end_date (str): The end date in 'YYYY-MM-DD' format.

    """
   
    start_date1 =datetime.date.fromisoformat(start_date)
    end_date1 = datetime.date.fromisoformat(end_date)
    num_days = (end_date1 - start_date1).days + 1

    date_df = spark.createDataFrame(
        [(start_date1 + datetime.timedelta(days=i),) for i in range(num_days)],
        ['full_date']
    )

    # 2. Derive dimensional attributes
    dim_date_df = date_df.select(
        F.date_format("full_date", "yyyyMMdd").cast("integer").alias("date_key"),
        F.col("full_date"),
        F.year("full_date").alias("year"),
        F.quarter("full_date").alias("quarter"),
        F.month("full_date").alias("month"),
        F.date_format("full_date", "MMMM").alias("month_name"),
        F.dayofmonth("full_date").alias("day_of_month"),
        F.dayofweek("full_date").alias("day_of_week"),
        F.date_format("full_date","EEEE").alias("day_name"),
        F.weekofyear("full_date").alias("week_of_year"),
        F.when(F.dayofweek("full_date").isin(1,7), True).otherwise(False).alias("is_weekend")
    )

        # 3. Create dummy row for UNKNOWN /NULL timestaps
    schema_for_unknown = dim_date_df.schema
    unknown_row = spark.createDataFrame([( -1
                                          , datetime.date(1900, 1, 1)
                                          , 1900
                                          , 0
                                          , 0
                                          , "UNKNOWN"
                                          , 0 
                                          ,0
                                          , "UNKNOWN"
                                          ,0
                                          , False)]
                                          , schema_for_unknown)

    # 4. Union and save to Gold layer storage
    final_dim_date = unknown_row.union(dim_date_df)
   
   
    (
        final_dim_date
        .write
        .format("delta")
        .mode("overwrite")
        .saveAsTable(f"{catalog}.{schema}.gold_date_dimension")
       # .save(f"{gold_layer_path}/date_dimension")
    )

    print(f"Date_dimension successfully generated and saved. Total records: {final_dim_date.count()}")
    #return None

#if __name__ == "__main__":
#    spark = get_spark_session()
   # spark = SparkSession.builder.appName("BuildDimDate").getOrCreate()
 #   generate_date_dim(spark)