# Persistence helpers for init.sh; expect DATA_FILE, STATE_FILE, and tracking globals to be set before sourcing.

state_log_line_count=0
state_log_size=0
state_log_mtime=0

# Helper to detect available stat format (GNU vs BSD)
_stat_size() {
    local file=$1
    if stat --version >/dev/null 2>&1; then
        stat -c %s "$file"
    else
        stat -f %z "$file"
    fi
}

_stat_mtime() {
    local file=$1
    if stat --version >/dev/null 2>&1; then
        stat -c %Y "$file"
    else
        stat -f %m "$file"
    fi
}

load_state_snapshot() {
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck source=/dev/null
        if source "$STATE_FILE" >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

write_state_json() {
    local json_file="${STATE_FILE%.sh}.json"
    local tmp_file="${json_file}.tmp"

    python - "$tmp_file" "$json_file" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

tmp_path, final_path = sys.argv[1:3]

def env(name, default=""):
    return os.environ.get(name, default)

payload = {
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "log": {
        "line_count": int(env("state_log_line_count", "0") or 0),
        "size_bytes": int(env("state_log_size", "0") or 0),
        "mtime": env("state_log_mtime", "")
    },
    "metrics": {
        "largest_prime": env("largest_prime", ""),
        "most_efficient": {
            "prime": env("efficient_prime", ""),
            "steps": env("least_steps", ""),
            "ratio": env("best_ratio", ""),
            "sequence": env("lowest_prime_steps", "")
        },
        "highest_value": {
            "max_value": env("max_value", ""),
            "prime": env("max_value_prime", ""),
            "steps": env("max_value_steps", ""),
            "ratio": env("max_value_ratio", ""),
            "sequence": env("max_value_sequence", "")
        },
        "latest_exec_time": env("exec_time", "")
    }
}

with open(tmp_path, "w", encoding="utf-8") as fh:
    json.dump(payload, fh, indent=2)

os.replace(tmp_path, final_path)
PY
}

persist_state_snapshot() {
    if [[ ! -f "$DATA_FILE" ]]; then
        return
    fi

    [[ -z "$state_log_line_count" || "$state_log_line_count" -lt 0 ]] && state_log_line_count=0

    state_log_size=$(_stat_size "$DATA_FILE")
    state_log_mtime=$(_stat_mtime "$DATA_FILE")

    local tmp_file="${STATE_FILE}.tmp"
    {
        printf '#!/bin/bash\n'
        printf '# Auto-generated state snapshot. Do not edit manually.\n'
        printf 'state_log_line_count=%q\n' "$state_log_line_count"
        printf 'state_log_size=%q\n' "$state_log_size"
        printf 'state_log_mtime=%q\n' "$state_log_mtime"
        printf 'largest_prime=%q\n' "$largest_prime"
        printf 'least_steps=%q\n' "$least_steps"
        printf 'lowest_prime=%q\n' "$lowest_prime"
        printf 'lowest_prime_steps=%q\n' "$lowest_prime_steps"
        printf 'max_value=%q\n' "$max_value"
        printf 'max_value_prime=%q\n' "$max_value_prime"
        printf 'max_value_steps=%q\n' "$max_value_steps"
        printf 'max_value_sequence=%q\n' "$max_value_sequence"
        printf 'max_value_ratio=%q\n' "$max_value_ratio"
        printf 'best_ratio=%q\n' "$best_ratio"
        printf 'efficient_prime=%q\n' "$efficient_prime"
        printf 'exec_time=%q\n' "$exec_time"
    } > "$tmp_file" 2>/dev/null || { rm -f "$tmp_file"; return; }

    if mv "$tmp_file" "$STATE_FILE" 2>/dev/null; then
        write_state_json
    else
        rm -f "$tmp_file"
    fi
}

append_efficient_log() {
    local prime=$1
    local steps=$2
    local sequence_max=$3
    local ratio=$4
    local exec=$5

    [[ -z "$prime" ]] && return

    local timestamp
    timestamp=$(date +%FT%T)
    printf '%s,%s,%s,%s,%s,%s\n' "$timestamp" "$prime" "$steps" "$sequence_max" "$ratio" "$exec" >> "$EFFICIENT_LOG"
}

previous_data_check() {
    if [[ ! -f "$DATA_FILE" ]]; then
        echo "No log file found. Starting fresh..."
        sleep 1
        state_log_line_count=0
        state_log_size=0
        state_log_mtime=0
        return
    fi

    restore_previous_data
}

restore_previous_data() {
    local total_lines current_line percent ratio exec_time_recorded
    local prime steps sequence_max
    local bar_width=30
    local snapshot_loaded=0
    local resume_line=1

    total_lines=$(wc -l < "$DATA_FILE")
    if (( total_lines == 0 )); then
        echo "Log file is empty. Starting fresh..."
        sleep 1
        state_log_line_count=0
        state_log_size=$(_stat_size "$DATA_FILE")
        state_log_mtime=$(_stat_mtime "$DATA_FILE")
        persist_state_snapshot
        return
    fi

    local current_size
    local current_mtime
    current_size=$(_stat_size "$DATA_FILE")
    current_mtime=$(_stat_mtime "$DATA_FILE")

    largest_prime=0
    least_steps=""
    lowest_prime=""
    max_value=0
    max_value_prime=""
    max_value_steps=""
    max_value_sequence=""
    max_value_ratio=""
    best_ratio=""
    efficient_prime=""
    lowest_prime_steps=""
    exec_time=""

    if load_state_snapshot; then
        snapshot_loaded=1
    fi

    if (( snapshot_loaded )); then
        local count_diff=$(( total_lines - state_log_line_count ))
        local size_diff=$(( current_size - state_log_size ))
        local has_max_metadata=0

        if [[ -n "$max_value_prime" && -n "$max_value_steps" && -n "$max_value_ratio" ]]; then
            has_max_metadata=1
        fi

        if (( count_diff <= 1 )) && (( size_diff >= 0 && size_diff <= 256 )) && (( has_max_metadata )); then
            state_log_line_count=$total_lines
            state_log_size=$current_size
            state_log_mtime=$current_mtime
            persist_state_snapshot
            echo "State snapshot is current. Skipping full log scan."
            return
        fi
    fi

    if (( snapshot_loaded )) && (( state_log_line_count == total_lines )) && (( state_log_size == current_size )) && [[ -n "$max_value_prime" && -n "$max_value_steps" && -n "$max_value_ratio" ]]; then
        echo "State snapshot is current. Skipping full log scan."
        state_log_size=$current_size
        state_log_mtime=$current_mtime
        persist_state_snapshot
        return
    fi

    if (( snapshot_loaded )) && (( state_log_line_count > 0 )) && (( state_log_line_count < total_lines )) && (( state_log_size <= current_size )); then
        resume_line=$(( state_log_line_count + 1 ))
        current_line=$state_log_line_count
        echo "Updating metrics from $(( total_lines - state_log_line_count )) new log entries."
    else
        snapshot_loaded=0
        resume_line=1
        current_line=0
        largest_prime=0
        least_steps=""
        lowest_prime=""
        max_value=0
        best_ratio=""
        efficient_prime=""
        lowest_prime_steps=""
        exec_time=""
        state_log_line_count=0
        echo "Restoring previous data from log. Please wait..."
    fi

    if (( resume_line > total_lines )); then
        state_log_line_count=$total_lines
        state_log_size=$current_size
        state_log_mtime=$current_mtime
        if [[ -z "$lowest_prime_steps" && -n "$lowest_prime" && -n "$least_steps" ]]; then
            lowest_prime_steps=$(collatz_sequence_string "$lowest_prime")
        fi
        persist_state_snapshot
        echo "No new log entries to process."
        return
    fi

    local start_byte=$(( state_log_size + 1 ))
    local use_bytes=0

    if (( resume_line == 1 )); then
        use_bytes=0
    else
        if (( state_log_size < current_size )) && (( start_byte > 0 )); then
            use_bytes=1
        fi
    fi

    if (( use_bytes )); then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            local prime steps sequence_max exec_time_recorded general_ratio
            if [[ "$line" == *,* ]]; then
                IFS=',' read -r prime steps sequence_max exec_time_recorded <<< "$line"
            else
                read -r prime steps sequence_max exec_time_recorded <<< "$line"
            fi
            [[ -z "$prime" ]] && continue

            ((current_line++))
            percent=$(( 100 * current_line / total_lines ))
            local filled=$(( bar_width * current_line / total_lines ))
            (( filled > bar_width )) && filled=$bar_width
            local empty=$(( bar_width - filled ))

            printf -v bar_fill '%*s' "$filled" ''
            bar_fill=${bar_fill// /#}
            printf -v bar_empty '%*s' "$empty" ''
            bar_empty=${bar_empty// /-}

            printf "\rRestoring log [%s%s] %3d%% (n=%s)" "$bar_fill" "$bar_empty" "$percent" "$prime"

            if is_prime "$prime"; then
                (( prime > largest_prime )) && largest_prime=$prime
            fi

            general_ratio=$(awk -v steps="$steps" -v prime="$prime" 'BEGIN { if (prime == 0) print 0; else printf "%.6f", steps/prime }')

            if (( sequence_max > max_value )); then
                max_value=$sequence_max
                max_value_prime=$prime
                max_value_steps=$steps
                max_value_ratio=$general_ratio
                max_value_sequence=""
            fi

            if (( steps > 1 )) && (( prime >= 7 )) && is_prime "$prime"; then
                ratio=$general_ratio

                if [[ -z "$best_ratio" ]]; then
                    best_ratio=$ratio
                    efficient_prime=$prime
                    least_steps=$steps
                    lowest_prime=$prime
                else
                    if (( $(awk -v r="$ratio" -v b="$best_ratio" 'BEGIN {print (r < b)}') )); then
                        best_ratio=$ratio
                        efficient_prime=$prime
                        least_steps=$steps
                        lowest_prime=$prime
                    elif (( $(awk -v r="$ratio" -v b="$best_ratio" 'BEGIN {print (r == b)}') )) && (( prime > ${efficient_prime:-0} )); then
                        best_ratio=$ratio
                        efficient_prime=$prime
                        least_steps=$steps
                        lowest_prime=$prime
                    fi
                fi
            fi

            exec_time="$exec_time_recorded"
        done < <(tail -c "+$start_byte" "$DATA_FILE")
    else
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue

            local prime steps sequence_max exec_time_recorded general_ratio
            if [[ "$line" == *,* ]]; then
                IFS=',' read -r prime steps sequence_max exec_time_recorded <<< "$line"
            else
                read -r prime steps sequence_max exec_time_recorded <<< "$line"
            fi
            [[ -z "$prime" ]] && continue

            ((current_line++))
            percent=$(( 100 * current_line / total_lines ))
            local filled=$(( bar_width * current_line / total_lines ))
            (( filled > bar_width )) && filled=$bar_width
            local empty=$(( bar_width - filled ))

            printf -v bar_fill '%*s' "$filled" ''
            bar_fill=${bar_fill// /#}
            printf -v bar_empty '%*s' "$empty" ''
            bar_empty=${bar_empty// /-}

            printf "\rRestoring log [%s%s] %3d%% (n=%s)" "$bar_fill" "$bar_empty" "$percent" "$prime"

            if is_prime "$prime"; then
                (( prime > largest_prime )) && largest_prime=$prime
            fi

            general_ratio=$(awk -v steps="$steps" -v prime="$prime" 'BEGIN { if (prime == 0) print 0; else printf "%.6f", steps/prime }')

            if (( sequence_max > max_value )); then
                max_value=$sequence_max
                max_value_prime=$prime
                max_value_steps=$steps
                max_value_ratio=$general_ratio
                max_value_sequence=""
            fi

            if (( steps > 1 )) && (( prime >= 7 )) && is_prime "$prime"; then
                ratio=$general_ratio

                if [[ -z "$best_ratio" ]]; then
                    best_ratio=$ratio
                    efficient_prime=$prime
                    least_steps=$steps
                    lowest_prime=$prime
                else
                    if (( $(awk -v r="$ratio" -v b="$best_ratio" 'BEGIN {print (r < b)}') )); then
                        best_ratio=$ratio
                        efficient_prime=$prime
                        least_steps=$steps
                        lowest_prime=$prime
                    elif (( $(awk -v r="$ratio" -v b="$best_ratio" 'BEGIN {print (r == b)}') )) && (( prime > ${efficient_prime:-0} )); then
                        best_ratio=$ratio
                        efficient_prime=$prime
                        least_steps=$steps
                        lowest_prime=$prime
                    fi
                fi
            fi

            exec_time="$exec_time_recorded"
        done < <(tail -n +"$resume_line" "$DATA_FILE")
    fi

    printf "\rRestoring log [%s] 100%%                     \n" "$(printf '%*s' "$bar_width" '' | tr ' ' '#')"

    if [[ -n "$lowest_prime" && -n "$least_steps" ]]; then
        lowest_prime_steps=$(collatz_sequence_string "$lowest_prime")
    else
        lowest_prime_steps=""
    fi

    if [[ -n "$max_value_prime" ]]; then
        if [[ -z "$max_value_sequence" ]]; then
            max_value_sequence=$(collatz_sequence_string "$max_value_prime")
        fi
        if [[ -z "$max_value_steps" && -f "$DATA_FILE" ]]; then
            max_value_steps=$(awk -v target="$max_value_prime" 'BEGIN {FS="[ ,]+"}
                $1 == target {print $2; exit}' "$DATA_FILE")
        fi
        if [[ -z "$max_value_ratio" ]]; then
            max_value_ratio=$(awk -v steps="$max_value_steps" -v prime="$max_value_prime" 'BEGIN { if (prime == 0) print 0; else printf "%.6f", steps/prime }')
        fi
    else
        max_value_sequence=""
        max_value_ratio=""
        max_value_steps=""
    fi

    echo
    echo "Restoration complete!"
    echo "Summary:"
    if (( largest_prime > 0 )); then
        echo "  Resume from prime: $largest_prime"
    else
        echo "  Resume from prime: 2 (no primes recorded yet)"
    fi

    if [[ -n "$efficient_prime" && -n "$best_ratio" ]]; then
        echo "  Most efficient prime: $efficient_prime ($least_steps steps, ratio $best_ratio)"
    else
        echo "  Most efficient prime: not determined (requires prime ≥ 7 with > 1 steps)"
    fi

    if (( max_value > 0 )); then
        echo "  Highest Collatz value observed: $max_value"
    fi

    state_log_line_count=$total_lines
    state_log_size=$current_size
    state_log_mtime=$current_mtime
    persist_state_snapshot
}

get_last_prime() {
    if (( largest_prime > 0 )); then
        echo "$largest_prime"
        return
    fi

    if [[ -f "$DATA_FILE" ]]; then
        awk -F',' '{print $1}' "$DATA_FILE" | sort -n | awk '
            function is_prime(n) {
                if (n < 2) return 0
                if (n % 2 == 0) return n == 2
                limit = int(sqrt(n))
                for (i = 3; i <= limit; i += 2) {
                    if (n % i == 0) return 0
                }
                return 1
            }
            { if (is_prime($1) && $1 > max) max = $1 }
            END { if (max > 0) print max; else print 2 }'
    else
        echo "2"
    fi
}
