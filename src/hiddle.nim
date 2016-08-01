import input, uinput, input_common
import config
import signal
import event_loop
import timeval
import os, strutils
import posix

proc hiddle(emulated_mouse: uinput.Device_descriptor, mouse: input.Device_descriptor)
type Mode {.pure.} = enum
    normal
    pending
    drag
    scroll


if opts.verbosity > 1: echo "options: ", opts

let mouse = pick_mouse_preferring_trackpoint()
if opts.verbosity > 0: echo "Capturing $# [$#]".format(mouse, mouse.name)

mouse.open_as m:
    open_uinput_as u:
        u.emulate_mouse opts.emulated_device_name
        hiddle(u, m)

proc hiddle(emulated_mouse: uinput.Device_descriptor, mouse: input.Device_descriptor) =
    let sig_fd = ignore_get_signal_fd(SIG_INT, SIG_TERM)
    var polls = [
        setup_poll(sig_fd.cint, POLL_IN),
        setup_poll( mouse.cint, POLL_IN),
    ]

    var mode = Mode.normal
    var pending_start: Timeval
    var pending_dragged_distance: int

    mouse.grab
    while true:
        if polls.poll == 0: continue
        if (polls[0].revents and POLL_IN) != 0:
            sig_fd.skip
            if opts.verbosity > 0: echo "Quiting..."
            break
        if (polls[1].revents and POLL_IN) != 0:
            var ev = mouse.read_mouse
            case mode
            of Mode.normal:
                if ev.buttons_pressed[middle_mouse_button]:
                    if opts.verbosity > 1: echo "-> pending"
                    pending_start = ev.time
                    pending_dragged_distance = 0
                    mode = Mode.pending

                    ev.buttons_pressed[middle_mouse_button] = false

            of Mode.pending:
                pending_dragged_distance += ev.x.abs + ev.y.abs

                if ev.buttons_released[middle_mouse_button]:
                    if opts.verbosity > 1: echo "-> normal [click]"
                    mode = Mode.normal

                    var press_ev = Mouse_event(time: pending_start)
                    press_ev.buttons_pressed[middle_mouse_button] = true
                    if opts.verbosity > 2: echo press_ev
                    emulated_mouse.write_mouse press_ev
                else:
                    let drag_timed_out = elapsed_milliseconds(pending_start, ev.time) > opts.scroll_delay
                    let drag_exceeds_threshold = pending_dragged_distance > opts.drag_threshold

                    if drag_timed_out:
                        if opts.verbosity > 1: echo "-> scroll"
                        mode = Mode.scroll

                    elif drag_exceeds_threshold:
                        if opts.verbosity > 1: echo "-> drag"
                        mode = Mode.drag

                        ev.buttons_pressed[middle_mouse_button] = true

                # no mouse motion in pending mode
                ev.x = 0
                ev.y = 0

            of Mode.drag:
                if ev.buttons_released[middle_mouse_button]:
                    if opts.verbosity > 1: echo "-> normal [stop drag]"
                    mode = Mode.normal

            of Mode.scroll:
                if ev.buttons_released[middle_mouse_button]:
                    if opts.verbosity > 1: echo "-> normal [stop scroll]"
                    mode = Mode.normal

                let ax = ev.x.abs
                let ay = ev.y.abs
                if ay >= ax: ev.wy = -ev.y
                if ax >= ay: ev.wx = ev.x

                # no mouse motion in scroll mode
                ev.x = 0
                ev.y = 0

            if opts.verbosity > 2: echo ev
            emulated_mouse.write_mouse(ev)

