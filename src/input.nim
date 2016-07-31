## Linux Input Subsystem
## ---------------------
##
## Operate on ``/dev/input/event*`` files

import config
import os
import posix
import strutils
import sequtils
import input_common

type Device* = distinct string
type Device_descriptor* = distinct cint
type Device_capabilities* {.pure, packed.} = object
    syn {.bitsize: 1.}: bool    ## synchronize. all devices have this.
    key {.bitsize: 1.}: bool    ## key or button
    rel {.bitsize: 1.}: bool    ## relative positioning
    abs {.bitsize: 1.}: bool    ## absolute positioning

proc `$`*(dev: Device): string = "Device(" & dev.string & ")"
proc `$`*(dd: Device_descriptor): string = "Device(#" & $dd.cint & ")"
proc `$`*(caps: Device_capabilities): string =
    var cap_seq = new_seq[string]()
    if caps.syn: cap_seq.add "SYN"
    if caps.key: cap_seq.add "KEY"
    if caps.rel: cap_seq.add "REL"
    if caps.abs: cap_seq.add "ABS"
    "Capabilities[$#]".format(cap_seq.join "|")

iterator devices*(): Device =
    ## find all input devices (event files)
    for path in walk_files("/dev/input/event*"):
        yield path.Device

proc open*(dev: Device, read_only = true): Device_descriptor =
    let flags = if read_only: O_RDONLY else: O_RDWR
    dev.string.open(flags).Device_descriptor

proc close*(dd: Device_descriptor) =
    discard close(dd.cint)      # TODO: check for error instead of discard

template open_as*(dev: Device, dd: untyped, body: untyped): untyped =
    ## Open the device for read, and store the descriptor in ``dd``.
    ## The device will be closed when out of the scope.
    block:
        let dd = dev.open(read_only = true)
        defer: dd.close
        body

#[ Doesn't make sense to open event device as "writable"
template open_rw_as*(dev: Device, dd: untyped, body: untyped): untyped =
    ## Open the device for read and write, and store the descriptor in ``dd``.
    ## The device will be closed when out of the scope.
    block:
        let dd = dev.open(read_only = false)
        defer: dd.close
        body
]#

proc ioctl(dd: Device_descriptor, request: uint): POSIX_error {.varargs, importc, header: "<sys/ioctl.h>".}

proc to_mouse_button(btn: uint16): Mouse_button =
    if btn == BTN_LEFT: return left_mouse_button
    if btn == BTN_RIGHT: return right_mouse_button
    if btn == BTN_MIDDLE: return middle_mouse_button


proc name*(dd: Device_descriptor): string =
    result = new_string_of_cap 255
    let len = ioctl(dd, EVIOCGNAME(255), result.cstring).checked
    result.set_len len-1
proc name*(dev: Device): string =
    dev.open_as dd:
        result = dd.name

proc capabilities(dd: Device_descriptor): Device_capabilities =
    ioctl(dd, EVIOCGBIT(0, sizeof(result).uint8), addr result).check
proc is_mouse(caps: Device_capabilities): bool =
    caps.key and (caps.rel or caps.abs)

proc identity*(dd: Device_descriptor): Device_identity =
    ioctl(dd, EVIOCGID, addr result).check
proc identity*(dev: Device): Device_identity =
    dev.open_as dd:
        result = dd.identity

proc grab*(dd: Device_descriptor) =
    ## This can work with read-only descriptors.
    ioctl(dd, EVIOCGRAB, true).check
proc ungrab*(dd: Device_descriptor) =
    ## This can work with read-only descriptors.
    ioctl(dd, EVIOCGRAB, false).check

proc read*(dd: Device_descriptor): Device_event =
    read(dd.cint, addr result, sizeof(result).cint).POSIX_error.check     # TODO: check return value properly

proc read_mouse*(dd: Device_descriptor): Mouse_event =
    while true:
        let ev = dd.read
        if ev.`type` == EV_SYN:
            result.time = ev.time
            break

        if ev.`type` == EV_REL:
            if ev.code == 0: result.x = ev.value
            elif ev.code == 1: result.y = ev.value
            else: echo "WARNING: unrecognized relative motion: ", ev
        elif ev.`type` == EV_KEY:
            let btn = ev.code.to_mouse_button
            if ev.value == 0: result.buttons_released[btn] = true
            else: result.buttons_pressed[btn] = true
        elif ev.`type` == EV_ABS:
            echo "WARNING: absolute motion not yet supported."
        else:
            echo "WARNING: unrecognized event: ", ev


iterator mouses*(): Device =
    for dev in devices():
        dev.open_as dd:
            let caps = dd.capabilities
            if opts.verbosity > 2:
                echo "$# [$#] $#$#".format(dev, dd.name, caps, if caps.is_mouse: " is mouse" else: "")
            if caps.is_mouse: yield dev


proc pick_mouse_preferring_trackpoint*(): Device =
    proc is_trackpoint(dev: Device): bool =
        dev.open_as dd:
            result = dd.capabilities.rel and dd.name.contains "TrackPoint"

    let ms = to_seq mouses()
    if ms.len == 1: return ms[0]
    if ms.len == 0: raise System_error.new_exception "no mouse found"

    let tps = ms.filter_it(it.is_trackpoint)
    case tps.len
    of 0:
        result = ms[0]
        echo "WARNING: failed to narrow down to a single mouse device"
        for mouse in ms: echo "WARNING:   - " & mouse.name
        echo "WARNING:   picking the first one: " & result.name
    of 1:
        result = tps[0]
    else:
        result = tps[0]
        echo "WARNING: failed to narrow down to a single trackpoint device"
        for mouse in tps: echo "WARNING:   - " & mouse.name
        echo "WARNING:   picking the first one: " & result.name


when is_main_module:
    let mouse = pick_mouse_preferring_trackpoint()
    if opts.verbosity > 0: echo "PICKED: ", mouse
    mouse.open_as dd:
        dd.grab
        for i in 0..200:
            let ev = dd.read_mouse
            echo i, "  ", ev

