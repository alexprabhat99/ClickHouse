#!/usr/bin/env bash

CUR_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../shell_config.sh
. "$CUR_DIR"/../shell_config.sh

DATA_FILE="${CLICKHOUSE_TMP}/${CLICKHOUSE_TEST_UNIQUE_NAME}"

# Reading only "b": the default of the tuple "a", on which the default of "b" depends, is computed: 8.
echo '{"z":[4],"a":[null],"b":[null]}' > "${DATA_FILE}_tuple.json"
$CLICKHOUSE_LOCAL -q "SELECT b FROM file('${DATA_FILE}_tuple.json', JSONColumns, 'z UInt32, a Tuple(x UInt32) DEFAULT tuple(z * 2), b UInt32 DEFAULT a.x')"

# The default of "d" is not computed, because "c" is read: 14.
echo '{"a":["oops"],"c":[7],"b":[null]}' > "${DATA_FILE}_present.json"
$CLICKHOUSE_LOCAL -q "SELECT b FROM file('${DATA_FILE}_present.json', JSONColumns, 'a String, d UInt32 DEFAULT toUInt32(a), c UInt32 DEFAULT d, b UInt32 DEFAULT c * 2')"

# INSERT (a18) FROM INFILE: the defaults of the not inserted columns are not expanded at every use, 42 and 2^18.
columns="a0 UInt64 DEFAULT 1"
for i in $(seq 1 18); do columns="$columns, a$i UInt64 DEFAULT a$((i - 1)) + a$((i - 1))"; done
$CLICKHOUSE_CLIENT --max_expanded_ast_elements 10000000 -q "CREATE TABLE t_chain ($columns) ENGINE = Memory"
printf '{"a18":42}\n{}\n' > "${DATA_FILE}_chain.jsonl" "${DATA_FILE}_lambda.jsonl"
$CLICKHOUSE_CLIENT --max_expanded_ast_elements 10000000 --max_memory_usage_in_client 500M -q "INSERT INTO t_chain (a18) FROM INFILE '${DATA_FILE}_chain.jsonl' FORMAT JSONEachRow"
$CLICKHOUSE_CLIENT -q "SELECT a18 FROM t_chain ORDER BY a18"
$CLICKHOUSE_CLIENT -q "DROP TABLE t_chain"

# "a" is used first in a lambda, whose aliases are not visible outside of it: 5, 18.
$CLICKHOUSE_CLIENT -q "CREATE TABLE t_lambda (a UInt32 DEFAULT 5, b UInt32 DEFAULT arraySum(arrayMap(z -> a + z, [1, 2])) + a) ENGINE = Memory"
echo '{"b":null}' > "${DATA_FILE}_lambda.jsonl"
$CLICKHOUSE_CLIENT --input_format_null_as_default 1 -q "INSERT INTO t_lambda (b) FROM INFILE '${DATA_FILE}_lambda.jsonl' FORMAT JSONEachRow"
$CLICKHOUSE_CLIENT -q "SELECT a, b FROM t_lambda"
$CLICKHOUSE_CLIENT -q "DROP TABLE t_lambda"

rm -f "${DATA_FILE}_tuple.json" "${DATA_FILE}_present.json" "${DATA_FILE}_chain.jsonl" "${DATA_FILE}_lambda.jsonl"
