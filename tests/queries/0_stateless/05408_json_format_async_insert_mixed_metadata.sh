#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# Asynchronous inserts parse all entries of a flush with one `JSON` input format, calling `resetParser`
# between them. Whether an entry has metadata must not leak into the next entry.

META='{"meta":[{"name":"x","type":"UInt64"}],"data":[{"x":1},{"x":2}]}'
ROWS='{"x":10}
{"x":20}'

SETTINGS="async_insert=1&wait_for_async_insert=0&async_insert_busy_timeout_min_ms=600000&async_insert_busy_timeout_max_ms=600000&async_insert_use_adaptive_busy_timeout=0"

for order in meta_first rows_first; do
    $CLICKHOUSE_CLIENT -q "DROP TABLE IF EXISTS t_json_async_${order}; CREATE TABLE t_json_async_${order} (x UInt64) ENGINE = Memory"

    if [ "$order" = meta_first ]; then first="$META"; second="$ROWS"; else first="$ROWS"; second="$META"; fi
    for data in "$first" "$second"; do
        ${CLICKHOUSE_CURL} -sS "${CLICKHOUSE_URL}&${SETTINGS}" --data-binary @- <<< "INSERT INTO t_json_async_${order} FORMAT JSON
${data}"
    done

    $CLICKHOUSE_CLIENT -q "SYSTEM FLUSH ASYNC INSERT QUEUE t_json_async_${order}"
    $CLICKHOUSE_CLIENT -q "SELECT '${order}', count(), sum(x) FROM t_json_async_${order}"
    $CLICKHOUSE_CLIENT -q "DROP TABLE t_json_async_${order}"
done
