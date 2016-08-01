import posix
import input_common

var garbage: array[256, char]

type Signal_descriptor* = distinct cint
proc signalfd(fd: cint, mask: var Sig_set, flags: cint): cint {.importc, header: "<sys/signalfd.h>".}
var SFD_NONBLOCK {.importc, header: "<sys/signalfd.h>".}: cint

proc ignore_get_signal_fd*(sigs: varargs[cint]): Signal_descriptor =
    var ss, old: Sig_set
    ss.sig_empty_set().POSIX_error.check
    for sig in sigs:
        ss.sig_add_set(sig).POSIX_error.check
    sig_proc_mask(SIG_BLOCK, ss, old).POSIX_error.check
    signalfd(-1, ss, SFD_NON_BLOCK).POSIX_error.checked.Signal_descriptor

proc skip*(sd: Signal_descriptor) =
    while true:
        case read(sd.cint, addr garbage, sizeof(garbage))
        of 0: break
        of -1:
            if errno == E_AGAIN or errno == E_WOULD_BLOCK: break
            else: err()
        else: discard

