#!/bin/bash

set -e

source test_cases.bash


cat <<'EOF'
CREATE OR REPLACE FUNCTION public.test_deb_version_cmp()
 RETURNS TABLE(version1 text, version2 text, result integer, expected integer, status text)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH test_cases (version1, version2, expected) AS (
        VALUES
EOF

first=true
for test_case in "${test_cases[@]}"; do
  if [[ $first = true ]]; then
    first=false
  else
    echo ","
  fi
  read -r version1 version2 expected <<<"${test_case}"
  printf "('%s', '%s', %d)" "${version1}" "${version2}" "${expected}"
done

echo

cat <<'EOF'
    )
    SELECT
        results.version1,
        results.version2,
        results.result,
        results.expected,   -- Specify the source of expected
        CASE WHEN results.result = results.expected THEN 'PASS' ELSE 'FAIL' END AS status
    FROM (
        SELECT
            t.version1,
            t.version2,
            t.expected,
            deb_version_cmp(t.version1, t.version2) AS result
        FROM test_cases t
    ) AS results;
END;
$function$
EOF

