print("DEBUG: Script execution has started!")
import os
import json
import random
from datetime import datetime, timedelta
from pathlib import Path
import yaml
import time
from kafka import KafkaProducer

# 1. Define asset classes and realistic price ranges
SYMBOL_CONFIG = {
    # Top 5 Technology
    "AAPL": (180.0, 350.0),
    "MSFT": (400.0, 530.0),
    "GOOGL": (150.0, 330.0),
    "AMZN": (180.0, 260.0),
    "META": (450.0, 660.0),
    
    # Top 5 Canadian Banks (CAD)
    "RY.TO": (140.0, 185.0),
    "TD.TO": (80.0, 130.0),
    "BMO.TO": (120.0, 160.0),
    "BNS.TO": (65.0, 95.0),
    "CM.TO": (60.0, 85.0),
    
    # Top 4 Oil Companies
    "XOM": (110.0, 180.0),
    "CVX": (140.0, 230.0),
    "SHEL": (60.0, 110.0),
    "COP": (100.0, 150.0),
    
    # Top 5 Commodity Companies
    "FCX": (35.0, 60.0),
    "VALE": (10.0, 20.0),
    "BHP": (50.0, 75.0),
    "GOLD": (15.0, 30.0),
    "AA": (30.0, 55.0)
}

VENUES = ["XNYS", "XNAS", "ARCX", "BATS", "IEXG"]
PORTFOLIOS = ["PORT_ALPHA_01", "PORT_ALPHA_02", "PORT_QUANT_01"]



def get_kafka_producer():
    """Initializes the Kafka producer connected to Azure Event Hubs."""
    # Read connection string from environment variable (set securely)
    conn_str = os.getenv("EVENTHUB_CONNECTION_STRING")
    if not conn_str:
        raise ValueError("EVENTHUB_CONNECTION_STRING environment variable is missing!")
        
    bootstrap_server = os.getenv("EVENTHUB_BOOTSTRAP_SERVER", "eh-alpha-factory-namespace-dev.servicebus.windows.net:9093")
    
    return KafkaProducer(
        bootstrap_servers=bootstrap_server,
        security_protocol='SASL_SSL',
        sasl_mechanism='PLAIN',
        sasl_plain_username='$ConnectionString',
        sasl_plain_password=conn_str,
        value_serializer=lambda v: json.dumps(v).encode('utf-8')
    )


def generate_trade_batch(batch_size=100):
    """Generates a list of synthetic trade event dictionaries."""
    trades = []
    base_time = datetime.utcnow() - timedelta(minutes=5)
    
    for i in range(batch_size):
        sym = random.choice(list(SYMBOL_CONFIG.keys()))
        min_p, max_p = SYMBOL_CONFIG[sym]
        
        # Realistic pricing and execution slippage
        sub_price = round(random.uniform(min_p, max_p), 2)
        slippage_pct = random.gauss(0, 0.0015) # tight spread model
        exec_price = round(sub_price * (1 + slippage_pct), 2)
        
        sub_time = base_time + timedelta(milliseconds=random.randint(0, 250000))
        exec_time = sub_time + timedelta(milliseconds=random.randint(20, 1200))
        
        trade_record = {
                    "trade_id": f"TRD-{random.randint(100000000, 999999999)}",  # Added trade_id
                    "order_id": random.randint(10000000, 99999999),
                    "symbol": sym,
                    "side": random.choice(["BUY", "SELL"]),
                    "order_quantity": random.randint(100, 5000),
                    "order_submission_price": sub_price,
                    "order_submission_timestamp": sub_time.isoformat(),
                    "execution_price": exec_price,
                    "execution_timestamp": exec_time.isoformat(),
                    "venue_id": random.choice(VENUES),                    # Renamed from execution_venue to venue_id
                    "alpha_signal_value": round(random.uniform(-1.0, 1.0), 4),
                    "portfolio_id": random.choice(PORTFOLIOS)             
                }
        trades.append(trade_record)
        
    return trades

if __name__ == "__main__":
    print("DEBUG: Alpha Factory 30-Minute Mock Data Stream has started!")
    producer = get_kafka_producer()
    topic_name = "alpha-factory-market-ticks"
    
    # Run for exactly 30 minutes
    start_time = time.time()
    duration_seconds = 30 * 60  # 30 minutes
    
    try:
        while time.time() - start_time < duration_seconds:
            batch_data = generate_trade_batch(batch_size=50)
            
            for record in batch_data:
                producer.send(topic_name, value=record)
                
            producer.flush()
            print(f"Successfully published batch of {len(batch_data)} records to Event Hubs at {datetime.utcnow().isoformat()}")
            
            # Wait 5 seconds between batches so it doesn't flood the queue instantly
            time.sleep(5)
            
    except KeyboardInterrupt:
        print("INFO: Stream interrupted by user.")
    finally:
        producer.close()
        print("INFO: Stream finished. Script exiting.")