## Common Definitions for Linux Input Subsystem
## --------------------------------------------
##
## Mainly C Interop/FFI
from posix import Timeval
export posix.Timeval

type POSIX_error* = distinct cint
type Device_event* {.pure.} = object
    time*: Timeval
    `type`*: uint16
    code*: uint16
    value*: int32
type Device_identity* {.pure.} = object
    bus_type*, vendor*, product*, version*: uint16

proc EVIOCGNAME*(size: uint8): uint {.importc, header: "<linux/input.h>".}
proc EVIOCGBIT*(mask, size: uint8): uint {.importc, header: "<linux/input.h>".}
var EVIOCGRAB* {.importc, header: "<linux/input.h>".}: uint
var EVIOCGID* {.importc, header: "<linux/input.h>".}: uint

const UINPUT_MAX_NAME_SIZE* #[{.importc, header: "<linux/uinput.h>".}: uint]# = 80
var UI_DEV_CREATE* {.importc, header: "<linux/uinput.h>".}: uint
var UI_DEV_SETUP* {.importc, header: "<linux/uinput.h>".}: uint
var UI_SET_EVBIT* {.importc, header: "<linux/uinput.h>".}: uint
var UI_SET_KEYBIT* {.importc, header: "<linux/uinput.h>".}: uint
var UI_SET_RELBIT* {.importc, header: "<linux/uinput.h>".}: uint

var EV_SYN* {.importc, header: "<linux/input.h>".}: uint16
var EV_KEY* {.importc, header: "<linux/input.h>".}: uint16
var EV_REL* {.importc, header: "<linux/input.h>".}: uint16
var EV_ABS* {.importc, header: "<linux/input.h>".}: uint16

var BTN_LEFT* {.importc, header: "<linux/input.h>".}: uint16
var BTN_RIGHT* {.importc, header: "<linux/input.h>".}: uint16
var BTN_MIDDLE* {.importc, header: "<linux/input.h>".}: uint16

var REL_X* {.importc, header: "<linux/input.h>".}: uint16
var REL_Y* {.importc, header: "<linux/input.h>".}: uint16
var REL_HWHEEL* {.importc, header: "<linux/input.h>".}: uint16
var REL_WHEEL* {.importc, header: "<linux/input.h>".}: uint16

proc err*(code: cint=1, fmt: cstring="failed") {.varargs, importc, header: "<err.h>".}
proc check*(code: POSIX_error) =
    if code.cint < 0: err()
proc checked*(code: POSIX_error): cint =
    code.check
    code.cint


type Mouse_button* = enum
    left_mouse_button
    right_mouse_button
    middle_mouse_button

type Mouse_event* = object
    time*: Timeval
    x*, y*: int     ## motion
    wx*, wy*: int   ## scrolling wheels
    buttons_pressed*: array[Mouse_button, bool]
    buttons_released*: array[Mouse_button, bool]

proc `$`*(btns: array[Mouse_button, bool]): string =
    result = "[---]"
    if btns[left_mouse_button]: result[1] = 'L'
    if btns[right_mouse_button]: result[3] = 'R'
    if btns[middle_mouse_button]: result[2] = 'M'

