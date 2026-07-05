# shellcheck shell=bash
# shellcheck disable=SC2034  # RANDKIT_AWK_LIB is consumed by the sourcing tools
# Shared awk random-sampling runtime for randkit's bash tools.
#
# Usage:
#   . "$(dirname "$0")/../lib/rand-awk.sh"
#   randkit_open_byte_stream
#   awk "$RANDKIT_AWK_LIB"'
#       BEGIN { print rand_range(6) + 1 }
#   '
#
# randkit_open_byte_stream starts a single od process streaming /dev/urandom
# as decimal bytes on FD 3. The awk functions below consume that stream, so a
# tool forks od and awk once per invocation regardless of how many samples it
# draws.

randkit_open_byte_stream() {
    # The stream's first line is the wrapper's pid, announced before od
    # starts so it cannot interleave with od's output. Reading it from the
    # stream is the only portable way to learn the pid — $! after a process
    # substitution is unreliable in bash 3.2. od's stderr is silenced: in
    # environments that ignore SIGPIPE (GitHub Actions runners, some
    # daemons), od survives the consumer exiting and prints "write error:
    # Broken pipe" instead of dying quietly. A real read failure is still
    # reported by rand_byte's refill_buf.
    # The TERM trap is installed in two stages so a kill arriving at any
    # moment finds a handler: before od exists a bare exit suffices; the
    # od-killing trap replaces it as soon as od has a pid. A tool can exit
    # this early (e.g. shuffle with empty stdin never draws a byte).
    exec 3< <(sh -c '
        echo "$$"
        trap "exit 0" TERM
        od -An -tu1 -v /dev/urandom 2>/dev/null &
        trap "kill $! 2>/dev/null; exit 0" TERM
        wait')
    read -r RANDKIT_STREAM_PID <&3
    # Reap the producer explicitly on exit. Relying on SIGPIPE to end od
    # deadlocks under ignored SIGPIPE on macOS: bash waits for the process
    # substitution child at exit while still holding FD 3 open, od never
    # dies, and any caller capturing our output blocks with it. TERM makes
    # the wrapper kill od and exit normally, so bash has no signal death to
    # report on stderr (a notice `wait 2>/dev/null` cannot silence in 3.2).
    trap 'exec 3<&-; kill "$RANDKIT_STREAM_PID" 2>/dev/null; wait "$RANDKIT_STREAM_PID" 2>/dev/null' EXIT
}

# rand_byte() dispenses one byte from the FD 3 stream, buffering a line of
# od output at a time. rand_range(n) returns a uniform integer in [0, n)
# using rejection sampling, scaling the byte width (1/2/4) to the range so
# small ranges don't burn entropy. n must be <= 2^32.
RANDKIT_AWK_LIB='
function refill_buf(   line) {
    if ((getline line < "/dev/fd/3") <= 0) {
        print "randkit: /dev/urandom read failed" > "/dev/stderr"
        exit 2
    }
    buf_n = split(line, buf, " ")
    buf_i = 0
}
function rand_byte() {
    if (buf_i >= buf_n) refill_buf()
    buf_i++
    return buf[buf_i] + 0
}
function rand_range(range,   nbytes, cap, thresh, v, i) {
    if (range <= 256)        { nbytes = 1; cap = 256 }
    else if (range <= 65536) { nbytes = 2; cap = 65536 }
    else                     { nbytes = 4; cap = 4294967296 }
    thresh = cap - (cap % range)
    while (1) {
        v = 0
        for (i = 0; i < nbytes; i++) v = v * 256 + rand_byte()
        if (v < thresh) return v % range
    }
}
'
