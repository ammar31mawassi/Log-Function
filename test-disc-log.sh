#!/usr/bin/env bash

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

make --no-print-directory >/dev/null || exit 1

program=./disc-log
epsilon=1e-17
# awk uses double precision, so comparisons need a looser tolerance than x87.
comparison_tolerance=1e-15

error_file="$(mktemp)"
trap 'rm -f "$error_file"' EXIT

integer_power() {
	local base_value=$1
	local exponent=$2
	local result=1
	local i

	for ((i = 0; i < exponent; i++)); do
		result=$((result * base_value))
	done

	printf '%d' "$result"
}

# Each case uses base=c^q and number=c^p, so the exact answer is p/q.
roots=(2 3 4 5 6 7 8 9 10 11)
exponent_pairs=(
	"1 1"
	"2 1"
	"3 1"
	"4 1"
	"1 2"
	"1 3"
	"1 4"
	"3 2"
	"2 3"
	"3 4"
)

total=0
passed=0
failed=0
output_pattern='^log_\{[^}]+\}\([^)]+\) = [-+0-9.eE]+$'

for root in "${roots[@]}"; do
	for pair in "${exponent_pairs[@]}"; do
		read -r p q <<<"$pair"
		base_value="$(integer_power "$root" "$q")"
		number_value="$(integer_power "$root" "$p")"
		expected="$(awk -v p="$p" -v q="$q" 'BEGIN { printf "%.18g", p / q }')"

		: >"$error_file"
		output="$($program "$base_value" "$number_value" "$epsilon" 2>"$error_file")"
		status=$?
		stderr_output="$(<"$error_file")"
		actual="${output##*= }"
		absolute_error="$(awk -v actual="$actual" -v expected="$expected" '
			BEGIN {
				difference = actual - expected
				if (difference < 0) difference = -difference
				printf "%.3g", difference
			}')"
		within_tolerance="$(awk \
			-v actual="$actual" \
			-v expected="$expected" \
			-v tolerance="$comparison_tolerance" '
			BEGIN {
				difference = actual - expected
				if (difference < 0) difference = -difference
				print difference <= tolerance ? 1 : 0
			}')"

		total=$((total + 1))
		if ((status == 0)) \
			&& [[ -z "$stderr_output" ]] \
			&& [[ "$output" =~ $output_pattern ]] \
			&& [[ "$within_tolerance" == 1 ]]; then
			passed=$((passed + 1))
			printf 'PASS %03d: log_{%s}(%s), expected=%-20s actual=%s\n' \
				"$total" "$base_value" "$number_value" "$expected" "$actual"
		else
			failed=$((failed + 1))
			printf 'FAIL %03d: log_{%s}(%s), expected=%s actual=%s error=%s status=%s stderr=%q\n' \
				"$total" "$base_value" "$number_value" "$expected" "$actual" \
				"$absolute_error" "$status" "$stderr_output"
		fi
	done
done

printf '\nSummary: %d/%d passed, %d failed\n' "$passed" "$total" "$failed"

if ((total != 100 || failed != 0)); then
	exit 1
fi
