SELECT count() FROM (SELECT Goals.ID FROM test.visits ARRAY JOIN Goals WHERE CounterID = 101500 LIMIT 10 UNION ALL SELECT Goals.ID FROM test.visits ARRAY JOIN Goals WHERE CounterID = 101500 LIMIT 10);
