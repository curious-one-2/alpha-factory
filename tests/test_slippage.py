import pytest

def calculate_slippage(side, execution_price, submission_price, quantity):
    """Core slippage calculation matching our Spark/SQL pipeline."""
    if side.upper() == 'BUY':
        return (execution_price - submission_price) * quantity
    else:
        return (submission_price - execution_price) * quantity

def test_buy_slippage_unfavorable():
    # Buying higher than submission price is unfavorable (positive slippage)
    slippage = calculate_slippage('BUY', execution_price=225.55, submission_price=225.50, quantity=1000)
    assert pytest.approx(slippage, 0.0001) == 50.00

def test_sell_slippage_favorable():
    # Selling higher than submission price is favorable (negative or cost-saving)
    slippage = calculate_slippage('SELL', execution_price=226.00, submission_price=225.50, quantity=1000)
    assert pytest.approx(slippage, 0.0001) == -500.00