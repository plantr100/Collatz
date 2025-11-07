#!/bin/bash

# File to store primes and Collatz steps
DATA_FILE="collatz_prime.log"
STATE_FILE="collatz_state.sh"
EFFICIENT_LOG="collatz_efficient.log"

# Manual mode value (set via menu)
manual_run_number=""

# Terminal tracking flags
USE_TPUT=0
display_initialized=0
display_cleaned=0
last_status_message=""

# Layout constants for tput UI
STATUS_LABEL_COL=0
STATUS_VALUE_COL=32

STATUS_TITLE_ROW=0
STATUS_LARGEST_ROW=2
STATUS_EXEC_ROW=3
STATUS_LEAST_ROW=4
STATUS_HIGHEST_ROW=5
STATUS_EFFICIENT_ROW=6
STATUS_DIVIDER_ROW=7
STATUS_STEPS_LABEL_ROW=8
STATUS_STEPS_ROW=9
STEPS_MAX_LINES=5
HIGH_STEPS_MAX_LINES=5
STATUS_HIGH_STEPS_LABEL_ROW=$((STATUS_STEPS_ROW + STEPS_MAX_LINES + 1))
STATUS_HIGH_STEPS_ROW=$((STATUS_HIGH_STEPS_LABEL_ROW + 1))
STATUS_SECOND_DIVIDER_ROW=$((STATUS_HIGH_STEPS_ROW + HIGH_STEPS_MAX_LINES))
STATUS_QUIT_ROW=$((STATUS_SECOND_DIVIDER_ROW + 1))

MESSAGE_ROW_FALLBACK=$((STATUS_QUIT_ROW + 1))
TERMINAL_WIDTH=80

# Pick correct date command (Linux: date, macOS: gdate)
environment_check() {
    if command -v gdate &>/dev/null; then
        DATE_CMD="gdate"
    else
        DATE_CMD="date"
    fi
}

setup_terminal_support() {
    if [[ -t 1 ]] && command -v tput &>/dev/null && [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
        USE_TPUT=1
    else
        USE_TPUT=0
    fi

    update_terminal_dimensions
}

update_terminal_dimensions() {
    local cols

    if command -v tput &>/dev/null; then
        cols=$(tput cols 2>/dev/null)
    fi

    if [[ -z "$cols" && -n "$COLUMNS" ]]; then
        cols=$COLUMNS
    fi

    if [[ -n "$cols" && "$cols" -ge 20 ]]; then
        TERMINAL_WIDTH=$cols
    else
        TERMINAL_WIDTH=80
    fi
}

recalc_message_row() {
    if (( ! USE_TPUT )); then
        MESSAGE_ROW=$MESSAGE_ROW_FALLBACK
        return
    fi

    update_terminal_dimensions

    local lines
    lines=$(tput lines 2>/dev/null)
    if [[ -z "$lines" || "$lines" -lt 1 ]]; then
        MESSAGE_ROW=$MESSAGE_ROW_FALLBACK
        return
    fi

    local candidate=$((lines - 2))
    local max_row=$((lines - 1))

    if (( max_row < 0 )); then
        MESSAGE_ROW=$MESSAGE_ROW_FALLBACK
        return
    fi

    if (( max_row < MESSAGE_ROW_FALLBACK )); then
        candidate=$max_row
    else
        (( candidate < MESSAGE_ROW_FALLBACK )) && candidate=$MESSAGE_ROW_FALLBACK
    fi

    (( candidate > max_row )) && candidate=$max_row
    MESSAGE_ROW=$candidate
}

environment_check

# Importing functions
source ./init.menu.sh
source ./init.persistence.sh
source ./init.collatz.sh

# Initialize global tracking variables
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
collatz_steps=""
last_steps_block=""
MESSAGE_ROW=$MESSAGE_ROW_FALLBACK
TRACKING_STATUS_MESSAGE="Generating primes and testing against Collatz Conjecture. Press 'q' to exit."


# Render the static frame for live status output
display_live_status_titles() {
    if (( ! USE_TPUT )); then
        display_initialized=0
        return
    fi

    tput clear
    tput civis
    display_initialized=1
    last_steps_block=""
    recalc_message_row
    update_terminal_dimensions

    tput cup "$STATUS_TITLE_ROW" "$STATUS_LABEL_COL"
    printf "%s" "=== Prime Number Collatz Tracker ==="

    tput cup "$STATUS_LARGEST_ROW" "$STATUS_LABEL_COL"
    printf "%-30s" "Largest Prime Processed:"

    tput cup "$STATUS_EXEC_ROW" "$STATUS_LABEL_COL"
    printf "%-30s" "Execution Time (last):"

    tput cup "$STATUS_LEAST_ROW" "$STATUS_LABEL_COL"
    printf "%-30s" "Prime with Least Steps:"

    tput cup "$STATUS_HIGHEST_ROW" "$STATUS_LABEL_COL"
    printf "%-30s" "Highest Collatz Value Reached:"

    tput cup "$STATUS_EFFICIENT_ROW" "$STATUS_LABEL_COL"
    printf "%-30s" "Most Efficient Prime:"

    tput cup "$STATUS_DIVIDER_ROW" "$STATUS_LABEL_COL"
    printf "%s" "------------------------------------"

    tput cup "$STATUS_STEPS_LABEL_ROW" "$STATUS_LABEL_COL"
    printf "%s" "Steps for most efficient prime:"

    tput cup "$STATUS_HIGH_STEPS_LABEL_ROW" "$STATUS_LABEL_COL"
    printf "%s" "Steps for highest value prime:"

    tput cup "$STATUS_SECOND_DIVIDER_ROW" "$STATUS_LABEL_COL"
    printf "%s" "------------------------------------"

    tput cup "$STATUS_QUIT_ROW" "$STATUS_LABEL_COL"
    printf "%s" "Press 'q' to exit."

    recalc_message_row
    tput cup "$MESSAGE_ROW" "$STATUS_LABEL_COL"
    tput el
}

# Function to display live tracking of results
display_live_status() {
    local largest_display="N/A"
    local exec_display="N/A"
    local least_display="N/A"
    local highest_display="N/A"
    local efficient_display="N/A"
    local efficient_label_text efficient_lines_text
    local max_label_text max_lines_text
    local steps_block
    local wrap_width line
    local -a efficient_lines_array=()
    local -a max_lines_array=()

    update_terminal_dimensions

    if [[ -n "$least_steps" && "$least_steps" -le 1 ]]; then
        least_steps=""
        lowest_prime=""
        lowest_prime_steps=""
    fi

    if [[ -n "$lowest_prime" && "$lowest_prime" -lt 7 ]]; then
        least_steps=""
        lowest_prime=""
        lowest_prime_steps=""
    fi

    if (( largest_prime > 0 )); then
        largest_display="$largest_prime"
    fi

    if [[ -n "$exec_time" ]]; then
        exec_display=$(awk -v value="$exec_time" 'BEGIN {printf "%.6f", value}')
    fi

    if [[ -n "$least_steps" && -n "$lowest_prime" ]]; then
        least_display="$lowest_prime ($least_steps steps)"
    fi

    if (( max_value > 0 )); then
        highest_display="$max_value"
        if [[ -n "$max_value_prime" ]]; then
            highest_display+=" (from $max_value_prime"
            if [[ -n "$max_value_steps" ]]; then
                highest_display+=", $max_value_steps steps"
            fi
            if [[ -n "$max_value_ratio" ]]; then
                highest_display+=", ratio $max_value_ratio"
            fi
            highest_display+=")"
        fi
    fi

    if [[ -n "$efficient_prime" && -n "$best_ratio" ]]; then
        efficient_display="$efficient_prime (ratio $best_ratio)"
    fi

    wrap_width=$(( TERMINAL_WIDTH - STATUS_LABEL_COL - 2 ))
    (( wrap_width < 20 )) && wrap_width=20

    efficient_label_text="Steps for most efficient prime:"
    if [[ -n "$least_steps" && -n "$lowest_prime" ]]; then
        efficient_label_text="Steps for $lowest_prime (most efficient):"
        if [[ -n "$lowest_prime_steps" ]]; then
            mapfile -t efficient_lines_array < <(printf '%s\n' "$lowest_prime_steps" | fold -w "$wrap_width" -s | head -n "$STEPS_MAX_LINES")
        fi
        if (( ${#efficient_lines_array[@]} == 0 )); then
            efficient_lines_array=("Sequence data unavailable.")
        fi
    else
        efficient_lines_array=("No qualifying steps recorded yet.")
    fi

    max_label_text="Steps for highest value prime:"
    if (( max_value > 0 )) && [[ -n "$max_value_prime" ]]; then
        max_label_text="Steps for $max_value_prime (highest value):"
        if [[ -n "$max_value_sequence" ]]; then
            mapfile -t max_lines_array < <(printf '%s\n' "$max_value_sequence" | fold -w "$wrap_width" -s | head -n "$HIGH_STEPS_MAX_LINES")
        fi
        if (( ${#max_lines_array[@]} == 0 )); then
            if [[ -n "$max_value_steps" ]]; then
                max_lines_array=("Sequence unavailable (prime has $max_value_steps steps).")
            else
                max_lines_array=("Sequence data unavailable.")
            fi
        fi
    else
        max_lines_array=("No highest value recorded yet.")
    fi

    efficient_lines_text=$(printf "%s\n" "${efficient_lines_array[@]}")
    efficient_lines_text=${efficient_lines_text%$'\n'}
    max_lines_text=$(printf "%s\n" "${max_lines_array[@]}")
    max_lines_text=${max_lines_text%$'\n'}
    steps_block="$wrap_width"$'\n'"$efficient_label_text"$'\n'"$efficient_lines_text"$'\n'"$max_label_text"$'\n'"$max_lines_text"

    if (( USE_TPUT )); then
        tput cup "$STATUS_LARGEST_ROW" "$STATUS_VALUE_COL"
        tput el
        printf "%s" "$largest_display"

        tput cup "$STATUS_EXEC_ROW" "$STATUS_VALUE_COL"
        tput el
        if [[ "$exec_display" == "N/A" ]]; then
            printf "N/A"
        else
            printf "%s seconds" "$exec_display"
        fi

        tput cup "$STATUS_LEAST_ROW" "$STATUS_VALUE_COL"
        tput el
        printf "%s" "$least_display"

        tput cup "$STATUS_HIGHEST_ROW" "$STATUS_VALUE_COL"
        tput el
        printf "%s" "$highest_display"

        tput cup "$STATUS_EFFICIENT_ROW" "$STATUS_VALUE_COL"
        tput el
        printf "%s" "$efficient_display"

        if [[ "$steps_block" != "$last_steps_block" ]]; then
            tput cup "$STATUS_STEPS_LABEL_ROW" "$STATUS_LABEL_COL"
            tput el
            printf "%s" "$efficient_label_text"

            for ((line=0; line<STEPS_MAX_LINES; line++)); do
                tput cup $((STATUS_STEPS_ROW + line)) "$STATUS_LABEL_COL"
                tput el
                if (( line < ${#efficient_lines_array[@]} )); then
                    printf "%s" "${efficient_lines_array[line]}"
                fi
            done

            tput cup "$STATUS_HIGH_STEPS_LABEL_ROW" "$STATUS_LABEL_COL"
            tput el
            printf "%s" "$max_label_text"

            for ((line=0; line<HIGH_STEPS_MAX_LINES; line++)); do
                tput cup $((STATUS_HIGH_STEPS_ROW + line)) "$STATUS_LABEL_COL"
                tput el
                if (( line < ${#max_lines_array[@]} )); then
                    printf "%s" "${max_lines_array[line]}"
                fi
            done

            last_steps_block="$steps_block"
        fi
    else
        clear
        echo "=== Prime Number Collatz Tracker ==="
        echo "Largest Prime Processed: $largest_display"
        if [[ "$exec_display" == "N/A" ]]; then
            echo "Execution time (last): N/A"
        else
            echo "Execution time (last): $exec_display seconds"
        fi
        echo "Prime with Least Steps: $least_display"
        echo "Highest Collatz Value Reached: $highest_display"
        echo "Most Efficient Prime: $efficient_display"
        echo "------------------------------------"
        echo "$efficient_label_text"
        if [[ -n "$efficient_lines_text" ]]; then
            echo "$efficient_lines_text"
        fi
        echo ""
        echo "$max_label_text"
        if [[ -n "$max_lines_text" ]]; then
            echo "$max_lines_text"
        fi
        echo "------------------------------------"
        echo ""
        echo "Press 'q' to exit."
        if [[ -n "$last_status_message" ]]; then
            echo "$last_status_message"
        fi

        last_steps_block="$steps_block"
    fi
}

update_status_message() {
    local message=$1

    if [[ "$message" == "$last_status_message" ]]; then
        return
    fi

    if (( USE_TPUT )); then
        recalc_message_row
        tput cup "$MESSAGE_ROW" "$STATUS_LABEL_COL"
        tput el
        printf "%s" "$message"
        last_status_message="$message"
    else
        last_status_message="$message"
        display_live_status
    fi
}

handle_resize() {
    update_terminal_dimensions

    if (( USE_TPUT )); then
        last_steps_block=""
        display_live_status_titles
        display_live_status
        if [[ -n "$last_status_message" ]]; then
            update_status_message "$last_status_message"
        fi
    fi
}

run_manual_number() {
    local value=$1
    local skip_prompt=${2:-0}

    collatz_sequence "$value"
    display_live_status

    if (( skip_prompt )); then
        update_status_message "Manual run complete for $value."
    elif [[ -t 0 ]]; then
        update_status_message "Manual run complete for $value. Press Enter to begin prime tracking..."
        read -r
        update_status_message ""
    fi

    manual_run_number=""
}

cleanup_display() {
    if (( display_cleaned )); then
        return
    fi

    if (( USE_TPUT )) && (( display_initialized )); then
        local last_row=$(( $(tput lines) - 1 ))
        (( last_row < 0 )) && last_row=0

        recalc_message_row
        tput cup "$MESSAGE_ROW" "$STATUS_LABEL_COL"
        tput el
        tput cnorm
        tput cup "$last_row" 0
        tput el
    fi

    printf "\n"
    display_cleaned=1
}

exit_program() {
    local message=$1
    cleanup_display
    if [[ -n "$message" ]]; then
        echo "$message"
    fi
    exit 0
}

handle_interrupt() {
    exit_program "Interrupted by user. Progress saved in $DATA_FILE"
}

# Function to generate primes and test Collatz
generate_primes_and_test_collatz() {
    local num key

    num=$(get_last_prime)
    local status_message="Resuming from prime number: $num. $TRACKING_STATUS_MESSAGE"

    display_live_status
    update_status_message "$status_message"

    while true; do
        if [[ -t 0 ]]; then
            if read -rsn1 -t 0.001 key; then
                if [[ $key == "q" ]]; then
                    exit_program "Exiting by user request. Progress saved in $DATA_FILE"
                fi
            fi
        fi

        if is_prime "$num"; then
            collatz_sequence "$num"
            display_live_status
        fi

        (( num++ ))
        sleep 0.002
    done
}

main() {
    previous_data_check
    prompt_user_input_mode
    setup_terminal_support
    display_live_status_titles

    if [[ -n "$manual_run_number" ]]; then
        run_manual_number "$manual_run_number"
    else
        display_live_status
    fi

    generate_primes_and_test_collatz
}

trap 'handle_interrupt' SIGINT
trap 'handle_resize' SIGWINCH
trap 'cleanup_display' EXIT

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ "$1" == "--manual" ]]; then
        manual_run_number="$2"
        if ! [[ "$manual_run_number" =~ ^[0-9]+$ && "$manual_run_number" -gt 1 ]]; then
            echo "Usage: $0 --manual <positive integer greater than 1>"
            exit 1
        fi

        previous_data_check
        setup_terminal_support
        display_live_status_titles
        display_live_status
        manual_value="$manual_run_number"
        run_manual_number "$manual_value" 1
        exit_program "Manual run complete for $manual_value."
    fi

    main
fi
