print("DEBUG: Script execution has started!")
import os
import json
import random
from datetime import datetime, timedelta
from pathlib import Path
#import yaml
from confluent_kafka import Producer

# 1. Define asset classes and realistic price ranges
SYMBOL_CONFIG = {
    "AAPL": (180.0, 350.0),
    "MSFT": (400.0, 530.0),
    "GOOGL": (150.0, 330.0),
    "AMZN": (180.0, 260.0),
    "META": (450.0, 660.0),
    "RY.TO": (140.0, 185.0),
    "TD.TO": (80.0, 130.0),
    "BMO.TO": (120.0, 160.0),
    "BNS.TO": (65.0, 95.0),
    "CM.TO": (60.0, 85.0),
    "XOM": (110.0, 180.0),
    "CVX": (140.0, 230.0),
    "SHEL": (60.0, 110.0),
    "COP": (100.0, 150.0),
    "FCX": (35.0, 60.0),
    "VALE": (10.0, 20.0),
    "BHP": (50.0, 75.0),
    "GOLD": (15.0, 30.0),
    "AA": (30.0, 55.0)
}

VENUES = ["XNYS", "XNAS", "ARCX", "BATS", "IEXG"]
PORTFOLIOS = ["PORT_ALPHA_01", "PORT_ALPHA_02", "PORT_QUANT_01"]

def get_kafka_producer():
    """Initializes the Confluent Kafka producer optimized for Azure Event Hubs."""
    conn_str = os.getenv("EVENTHUB_CONNECTION_STRING")
    if not conn_str:
        raise ValueError("EVENTHUB_CONNECTION_STRING environment variable is missing!")
        
    bootstrap_server = os.getenv("EVENTHUB_BOOTSTRAP_SERVER", "eh-alpha-factory-namespace-dev.servicebus.windows.net:9093")
    
    conf = {
        'bootstrap.servers': bootstrap_server,
        'security.protocol': 'SASL_SSL',
        'sasl.mechanisms': 'PLAIN',
        'sasl.username': '$ConnectionString',
        'sasl.password': conn_str,
    }
    return Producer(conf)

def generate_trade_batch(batch_size=10):
    """Generates a list of synthetic trade event dictionaries."""
    trades = []
    base_time = datetime.utcnow() - timedelta(minutes=5)
    
    for i in range(batch_size):
        sym = random.choice(list(SYMBOL_CONFIG.keys()))
        min_p, max_p = SYMBOL_CONFIG[sym]
        
        sub_price = round(random.uniform(min_p, max_p), 2)
        slippage_pct = random.gauss(0, 0.0015)
        exec_price = round(sub_price * (1 + slippage_pct), 2)
        
        sub_time = base_time + timedelta(milliseconds=random.randint(0, 250000))
        exec_time = sub_time + timedelta(milliseconds=random.randint(20, 1200))
        
        trade_record = {
            "order_id": random.randint(10000000, 99999999),
            "symbol": sym,
            "side": random.choice(["BUY", "SELL"]),
            "order_quantity": random.randint(100, 5000),
            "order_submission_price": sub_price,
            "order_submission_timestamp": sub_time.isoformat(),
            "execution_price": exec_price,
            "execution_timestamp": exec_time.isoformat(),
            "execution_venue": random.choice(VENUES),
            "alpha_signal_value": round(random.uniform(-1.0, 1.0), 4),
            "portfolio_id": random.choice(PORTFOLIOS)
        }
        trades.append(trade_record)
        
    return trades

def delivery_report(err, msg):
    if err is not None:
        print(f"Delivery failed: {err}")
    else:
        print(f"Record successfully produced to {msg.topic()} [partition {msg.partition()}]")

if __name__ == "__main__":
    print("DEBUG: Alpha Factory Mock Data Stream to Event Hub has started!")
    producer = get_kafka_producer()
    topic_name = "alpha-factory-market-ticks"
    
    # Stream batches
    for batch_idx in range(3):
        batch_data = generate_trade_batch(batch_size=10)
        for record in batch_data:
            producer.produce(
                topic_name,
                key=str(record['symbol']),
                value=json.dumps(record).encode('utf-8'),
                callback=delivery_report
            )
        producer.flush()
        print(f"Successfully flushed batch {batch_idx + 1} to Event Hub.")
    
    print("INFO: Stream finished. Script exiting.")