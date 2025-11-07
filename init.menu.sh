# First function called in init.sh
# Will prompt user to manually pass a positive integer to collatz_sequence()
# or to continue from the last prime processed prior to a signal interupt.
prompt_user_input_mode() {
    manual_run_number=""

    echo "------------------------------------"
    echo "Choose a mode:"
    echo "  [1] Continue computing primes normally"
    echo "  [2] Enter a number to test manually"
    read -rp "Selection: " mode

    if [[ "$mode" == "2" ]]; then
        read -rp "Enter a positive integer: " custom_num
        if ! [[ "$custom_num" =~ ^[0-9]+$ && "$custom_num" -gt 1 ]]; then
            echo "Invalid number. Falling back to normal mode."
            manual_run_number=""
            return
        fi

        read -rp "Run in debug mode? (y/n): " debug
        if [[ "$debug" =~ ^[Yy]$ ]]; then
            bash -x "$0" --manual "$custom_num"
            exit 0
        fi

        manual_run_number="$custom_num"
        echo "Manual run scheduled for $custom_num. Results will display before prime tracking resumes."
    fi
}
