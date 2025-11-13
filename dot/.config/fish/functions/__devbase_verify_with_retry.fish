function __devbase_verify_with_retry --description "Verify a condition with exponential backoff retry"
    set -l verification_cmd $argv[1]
    set -l expected_value $argv[2]
    set -l error_prefix $argv[3]
    set -l max_attempts $argv[4]
    set -l base_wait_ms $argv[5]
    set -l max_wait_ms $argv[6]
    
    if test -z "$max_attempts"
        set max_attempts 5
    end
    
    if test -z "$base_wait_ms"
        set base_wait_ms 100
    end
    
    if test -z "$max_wait_ms"
        set max_wait_ms 1000
    end
    
    set -l attempt 0
    
    while test $attempt -lt $max_attempts
        set attempt (math $attempt + 1)
        
        set -l current_value (eval $verification_cmd 2>/dev/null)
        
        if test "$current_value" = "$expected_value"
            return 0
        end
        
        if test $attempt -lt $max_attempts
            set -l wait_time (math "$base_wait_ms * (2 ^ ($attempt - 1))")
            if test $wait_time -gt $max_wait_ms
                set wait_time $max_wait_ms
            end
            sleep (math "$wait_time / 1000")
        end
    end
    
    echo "✗ $error_prefix: Verification failed after $max_attempts attempts" >&2
    echo "  Expected: $expected_value" >&2
    echo "  Current: $current_value" >&2
    return 1
end
