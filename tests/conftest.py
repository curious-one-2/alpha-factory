import pytest
from pyspark.sql import SparkSession

@pytest.fixture(scope="session")
def spark():
    """Provides a local PySpark session for unit testing."""
    session = (
        SparkSession.builder
        .master("local[2]")
        .appName("AlphaFactory_Local_Testing")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.default.parallelism", "2")
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    )
    yield session
    session.stop()