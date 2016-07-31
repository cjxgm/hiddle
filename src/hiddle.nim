import input, uinput, input_common
import os
import strutils

open_uinput_as u:
    let mouse = pick_mouse_preferring_trackpoint()
    echo "Controlling $# [$#]".format(mouse, mouse.name)
    u.emulate_mouse "Hiddle Mouse"
    mouse.open_as m:
        m.grab
        for i in 0..10:
            echo i
            var evs: array[30, Mouse_event]
            echo "  recording"
            for ev in evs.mitems:
                ev = m.read_mouse
            echo "  playing"
            for ev in evs:
                u.write_mouse ev
                sleep(10)

