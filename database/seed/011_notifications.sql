-- 011_notifications.sql
INSERT INTO notifications (notification_id, user_id, price_alert_id, message, status, created_at)
VALUES
    ('d3000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 'Price alert set for AAPL above $200.00',                          'PENDING', '2026-01-20 09:01:00+00'),
    ('d3000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', NULL,                                     'Your BUY order for 10 AAPL shares was filled at $150.00',         'SENT',    '2026-01-15 10:06:00+00'),
    ('d3000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000004', NULL,                                     'Your BUY order for 5 AAPL shares was rejected: insufficient funds', 'FAILED',  '2026-03-03 09:16:00+00');
