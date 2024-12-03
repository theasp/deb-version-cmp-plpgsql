#!/bin/bash

# Make sure the test cases in test_cases.bash are all correct

set -e

source test_cases.bash

RC=0

for test_case in "${test_cases[@]}"; do
  IFS=' ' read -r version1 version2 expected <<< "$test_case"

  case $expected in
    -1) expected=gt ;;
    0)  expected=eq ;;
    1)  expected=lt ;;
    *)  echo "ERROR: Dunno what is going on!" 1>&2 && exit 1 ;;
  esac

  result=''
  for cmp in lt eq gt; do
    if dpkg --compare-versions "$version1" "$cmp" "$version2"; then
      result=$cmp
      break
    fi
  done

  if [[ $result = "$expected" ]]; then
    echo "PASS: $version1 vs $version2 (Expected: $expected, Got: $result)"
  else
    echo "FAIL: $version1 vs $version2 (Expected: $expected, Got: $result)"
    RC=1
  fi
done

exit "${RC}"
