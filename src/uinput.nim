## Linux User Input Subsystem
## --------------------------
##
## Operate on /dev/uinput to create virtual input device.

import posix
import strutils
import input_common

type Device_descriptor* = distinct cint

proc `$`*(dd: Device_descriptor): string = "UserInput(#" & $dd.cint & ")"

proc open_uinput*(): Device_descriptor =
    # TODO: Why non blocking mode?
    "/dev/uinput".open(O_WR_ONLY or O_NON_BLOCK).Device_descriptor

proc close*(dd: Device_descriptor) =
    discard close(dd.cint)      # TODO: check for error instead of discard

template open_uinput_as*(dd: untyped, body: untyped): untyped =
    ## Open the device as write-only in non-blocking mode,
    ## and store the descriptor in ``dd``.
    ## The device will be closed when out of the scope.
    block:
        let dd = open_uinput()
        defer: dd.close
        body

proc ioctl(dd: Device_descriptor, request: uint): POSIX_error {.varargs, importc, header: "<sys/ioctl.h>".}

proc set_ev_bit(dd: Device_descriptor, ev: uint16) =
    ioctl(dd, UI_SET_EVBIT, ev).check
proc set_key_bit(dd: Device_descriptor, key: uint16) =
    ioctl(dd, UI_SET_KEYBIT, key).check
proc set_rel_bit(dd: Device_descriptor, rel: uint16) =
    ioctl(dd, UI_SET_RELBIT, rel).check
proc create(dd: Device_descriptor) =
    ioctl(dd, UI_DEV_CREATE).check
proc setup(dd: Device_descriptor, name: string, id: Device_identity) =
    type Device_setup {.pure.} = object
        id: Device_identity
        name: array[UINPUT_MAX_NAME_SIZE, char]
        ff_effects_max: uint32

    if name.len >= UINPUT_MAX_NAME_SIZE:
        raise System_error.new_exception "String too long, allow at most $#, but got $#: $#".format(UINPUT_MAX_NAME_SIZE-1, name.len, name)

    var s = Device_setup(id: id)
    copy_mem(addr s.name, name.cstring, name.len+1)
    ioctl(dd, UI_DEV_SETUP, addr s).check

proc write*(dd: Device_descriptor, ev: Device_event) =
    var e = ev
    write(dd.cint, addr e, sizeof(e)).POSIX_error.check       # TODO: proper error checking
proc write*(dd: Device_descriptor, time: Timeval, `type`: uint16, code = 0'u16, value = 0'i32) =
    dd.write(Device_event(time: time, `type`: `type`, code: code, value: value))

proc write_mouse*(dd: Device_descriptor, ev: Mouse_event) =
    if ev.x != 0: dd.write(ev.time, EV_REL, REL_X, ev.x.int32)
    if ev.y != 0: dd.write(ev.time, EV_REL, REL_Y, ev.y.int32)
    if ev.wx != 0: dd.write(ev.time, EV_REL, REL_HWHEEL, ev.wx.int32)
    if ev.wy != 0: dd.write(ev.time, EV_REL, REL_WHEEL , ev.wy.int32)
    if ev.buttons_pressed[left_mouse_button]: dd.write(ev.time, EV_KEY, BTN_LEFT, 1)
    if ev.buttons_pressed[right_mouse_button]: dd.write(ev.time, EV_KEY, BTN_RIGHT, 1)
    if ev.buttons_pressed[middle_mouse_button]: dd.write(ev.time, EV_KEY, BTN_MIDDLE, 1)
    if ev.buttons_released[left_mouse_button]: dd.write(ev.time, EV_KEY, BTN_LEFT, 0)
    if ev.buttons_released[right_mouse_button]: dd.write(ev.time, EV_KEY, BTN_RIGHT, 0)
    if ev.buttons_released[middle_mouse_button]: dd.write(ev.time, EV_KEY, BTN_MIDDLE, 0)
    dd.write(ev.time, EV_SYN)

proc emulate_mouse*(dd: Device_descriptor, name: string, id = Device_identity()) =
    dd.set_ev_bit(EV_REL)
    dd.set_ev_bit(EV_KEY)
    dd.set_rel_bit(REL_X)
    dd.set_rel_bit(REL_Y)
    dd.set_rel_bit(REL_HWHEEL)
    dd.set_rel_bit(REL_WHEEL)
    dd.set_key_bit(BTN_LEFT)
    dd.set_key_bit(BTN_RIGHT)
    dd.set_key_bit(BTN_MIDDLE)
    dd.setup(name, id)
    dd.create


when is_main_module:
    from os import sleep
    open_uinput_as dd:
        dd.emulate_mouse "User Input Virtual Mouse"
        for i in 0..20:
            dd.write_mouse Mouse_event(x: 10, wy: 2)
            sleep(100)

