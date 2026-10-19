#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

# A `.json` file is auto-detected as the `JSON` format. Without metadata it is parsed as `JSONEachRow`,
# and it has to use parallel parsing, as `JSONEachRow` does. With metadata it is parsed sequentially.

DATA="${CLICKHOUSE_TMP}/${CLICKHOUSE_TEST_UNIQUE_NAME}"
SETTINGS="input_format_parallel_parsing = 1, max_threads = 1, max_parsing_threads = 4, min_chunk_bytes_for_parallel_parsing = 1000"

$CLICKHOUSE_LOCAL -q "SELECT number AS a, toString(number) AS b FROM numbers(100000) INTO OUTFILE '${DATA}_each_row.json' TRUNCATE FORMAT JSONEachRow"
$CLICKHOUSE_LOCAL -q "SELECT number AS a, toString(number) AS b FROM numbers(100000) INTO OUTFILE '${DATA}_meta.json' TRUNCATE FORMAT JSON"
printf '[{"a":1,"b":"x"},\n{"a":2,"b":"yy"}]\n' > "${DATA}_array.json"

for kind in each_row meta array; do
    $CLICKHOUSE_LOCAL -q "SELECT '${kind}', count(), sum(a), sum(length(b)) FROM file('${DATA}_${kind}.json') SETTINGS ${SETTINGS}"
done

# A parse error is attributed to the format node that raised it, so the name of the processor tells
# whether `ParallelParsingInputFormat` was constructed.
printf '{"x":1}\n{"x":2}\n{"x":"NOTANUMBER"}\n' > "${DATA}_bad_each_row.json"
printf '{"meta":[{"name":"x","type":"UInt64"}],"data":[{"x":1},{"x":"NOTANUMBER"}]}\n' > "${DATA}_bad_meta.json"

for kind in bad_each_row bad_meta; do
    $CLICKHOUSE_LOCAL -q "SELECT sum(x) FROM file('${DATA}_${kind}.json', auto, 'x UInt64') SETTINGS ${SETTINGS}" 2>&1 \
        | grep -q "ParallelParsingBlockInputFormat" && echo "${kind}: PARALLEL" || echo "${kind}: NOT PARALLEL"
done

rm "${DATA}"_*.json
