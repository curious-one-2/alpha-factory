from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType, DateType, IntegerType

def get_bronze_schema_for_stream_source() -> StructType:
    return StructType([
        StructField("trade_id", StringType(), True),
        StructField("order_id", IntegerType(), True),
        StructField("symbol", StringType(), True),
        StructField("side", StringType(), True),
        StructField("order_quantity", IntegerType(), True),
        StructField("order_submission_price", DoubleType(), True),
        StructField("order_submission_timestamp", TimestampType(), True),
        StructField("execution_price", DoubleType(), True),
        StructField("execution_timestamp", TimestampType(), True),
        StructField("venue_id", StringType(), True),
        StructField("alpha_signal_value", DoubleType(), True),
        StructField("portfolio_id", StringType(), True)
    ])
    