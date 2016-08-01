import posix
export Timeval

proc elapsed_milliseconds*(`from`, to: Timeval): int =
    (to.tv_sec - `from`.tv_sec) * 1000 +
        to.tv_usec div 1000 - `from`.tv_usec div 1000

