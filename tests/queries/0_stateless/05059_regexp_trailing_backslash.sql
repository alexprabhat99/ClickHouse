-- Regression for #117853.
-- A trailing unescaped backslash is an invalid RE2 regexp and must not
-- be treated as a trivial substring.
SELECT match('abcd', 'abc\\'); -- { serverError CANNOT_COMPILE_REGEXP }
SELECT match('abcd', '\\'); -- { serverError CANNOT_COMPILE_REGEXP }
SELECT extractAll('abcd', 'abc\\'); -- { serverError CANNOT_COMPILE_REGEXP }
SELECT countMatches('abcabc', 'abc\\'); -- { serverError CANNOT_COMPILE_REGEXP }
SELECT splitByRegexp('abc\\', 'xabcy'); -- { serverError CANNOT_COMPILE_REGEXP }

-- Valid escaped backslashes must continue working.
SELECT match('abc\\', 'abc\\\\');
SELECT extractAll('abc\\', 'abc\\\\');
SELECT countMatches('abc\\abc\\', 'abc\\\\');
SELECT splitByRegexp('abc\\\\', 'xabc\\y');

-- Invalid regexp must not be hidden by a skip index.
DROP TABLE IF EXISTS regexp_skip_idx;

CREATE TABLE regexp_skip_idx
(
    s String,
    INDEX idx s TYPE ngrambf_v1(3, 512, 2, 0)
)
ENGINE = MergeTree
ORDER BY tuple()
SETTINGS index_granularity = 1;

INSERT INTO regexp_skip_idx VALUES ('nothing here');

SELECT count()
FROM regexp_skip_idx
WHERE match(s, 'abc\\')
SETTINGS force_data_skipping_indices = 'idx'; -- { serverError CANNOT_COMPILE_REGEXP }

DROP TABLE regexp_skip_idx;
