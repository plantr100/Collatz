# Collatz helpers for init.sh; expect DATE_CMD and tracking globals to be prepared.

is_prime() {
    local num=$1
    if (( num < 2 )); then return 1; fi
    for (( i=2; i*i<=num; i++ )); do
        (( num % i == 0 )) && return 1
    done
    return 0
}

collatz_sequence() {
    local n=$1
    local steps=0
    local sequence_max=$n
    local start_time end_time ratio general_ratio
    local best_updated=0

    start_time=$($DATE_CMD +%s.%N)
    collatz_steps="$n"

    while (( n != 1 )); do
        if (( n % 2 == 0 )); then
            n=$(( n / 2 ))
        else
            n=$(( 3 * n + 1 ))
        fi
        (( steps++ ))
        (( n > sequence_max )) && sequence_max=$n
        collatz_steps+=" → $n"
    done

    end_time=$($DATE_CMD +%s.%N)
    exec_time=$(awk -v start="$start_time" -v finish="$end_time" 'BEGIN {print finish - start}')

    printf '%s,%s,%s,%s\n' "$1" "$steps" "$sequence_max" "$exec_time" >> "$DATA_FILE"
    (( state_log_line_count++ ))

    general_ratio=$(awk -v steps="$steps" -v prime="$1" 'BEGIN { if (prime == 0) print 0; else printf "%.6f", steps/prime }')

    if is_prime "$1"; then
        (( $1 > largest_prime )) && largest_prime=$1
    fi
    if (( sequence_max > max_value )); then
        max_value=$sequence_max
        max_value_prime=$1
        max_value_steps=$steps
        max_value_sequence="$collatz_steps"
        max_value_ratio=$general_ratio
    fi

    if (( steps > 1 )) && (( $1 >= 7 )) && is_prime "$1"; then
        ratio=$general_ratio

        if [[ -z "$best_ratio" ]]; then
            best_ratio=$ratio
            efficient_prime=$1
            least_steps=$steps
            lowest_prime=$1
            lowest_prime_steps="$collatz_steps"
            best_updated=1
        else
            if (( $(awk -v r="$ratio" -v b="$best_ratio" 'BEGIN {print (r < b)}') )); then
                best_ratio=$ratio
                efficient_prime=$1
                least_steps=$steps
                lowest_prime=$1
                lowest_prime_steps="$collatz_steps"
                best_updated=1
            elif (( $(awk -v r="$ratio" -v b="$best_ratio" 'BEGIN {print (r == b)}') )) && (( $1 > ${efficient_prime:-0} )); then
                best_ratio=$ratio
                efficient_prime=$1
                least_steps=$steps
                lowest_prime=$1
                lowest_prime_steps="$collatz_steps"
                best_updated=1
            fi
        fi
    fi

    if (( best_updated )); then
        append_efficient_log "$1" "$steps" "$sequence_max" "$best_ratio" "$exec_time"
    fi

    persist_state_snapshot
}

collatz_sequence_string() {
    local n=$1
    local sequence="$n"

    while (( n != 1 )); do
        if (( n % 2 == 0 )); then
            n=$(( n / 2 ))
        else
            n=$(( 3 * n + 1 ))
        fi
        sequence+=" → $n"
    done

    printf "%s" "$sequence"
}
