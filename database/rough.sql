SELECT status, COUNT(*)
FROM trading_accounts
GROUP BY status
ORDER BY status;

SELECT status, COUNT(*)
FROM orders
GROUP BY status
ORDER BY status;

SELECT i.ticker,
       i.asset_class,
       i.is_tradable,
       h.quantity,
       h.average_buy_price
FROM holdings h
JOIN instruments i ON i.instrument_id = h.instrument_id
ORDER BY i.ticker;