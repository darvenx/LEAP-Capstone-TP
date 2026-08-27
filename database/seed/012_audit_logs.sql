-- 012_audit_logs.sql
INSERT INTO audit_logs (audit_log_id, user_id, entity_type, entity_id, action, details, created_at)
VALUES
    ('e4000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'orders', 'd4000000-0000-0000-0000-000000000001', 'FILL',    'Order filled: 10 AAPL @ 150.00',                                   '2026-01-15 10:05:00+00'),
    ('e4000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000001', 'orders', 'd4000000-0000-0000-0000-000000000004', 'REJECT',  'Rejected: sell quantity 50 exceeds held quantity 7',               '2026-05-01 11:00:00+00'),
    ('e4000000-0000-0000-0000-000000000003', 'a1000000-0000-0000-0000-000000000001', 'orders', 'd4000000-0000-0000-0000-000000000006', 'CANCEL',  'Cancelled by customer before fill',                                '2026-06-12 15:00:00+00'),
    ('e4000000-0000-0000-0000-000000000004', 'a1000000-0000-0000-0000-000000000004', 'orders', 'd4000000-0000-0000-0000-000000000007', 'REJECT',  'Rejected: insufficient cash balance for order value 750.00',      '2026-03-03 09:15:00+00'),
    ('e4000000-0000-0000-0000-000000000005', NULL,                                    'users',  'a1000000-0000-0000-0000-000000000002', 'SUSPEND', 'Account suspended for compliance review',                          '2026-02-01 00:00:00+00');
