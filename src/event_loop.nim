import posix
import input_common
export POLL_IN

type Poll_setup* = T_poll_fd

proc setup_poll*(fd: cint, events: cshort = 0): Poll_setup =
    Poll_setup(fd: fd, events: events)

proc poll*(pss: var open_array[Poll_setup]): cint =
    if pss.len == 0: return 0
    poll(addr pss[0], pss.len.Tnfds, -1).POSIX_error.checked

