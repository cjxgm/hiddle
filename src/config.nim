import os
import strutils
import parseopt
import semver

type Options = object
    drag_threshold*: int
    scroll_delay*: int
    emulated_device_name*: string
    verbosity*: int

const app_name* = "hiddle"
const app_version* = init_sem_ver(2, 0, 0)
let app_filename* = get_app_filename()

proc help =
    echo """
$# - Hybrid Middle Mouse Button
version: $#

  middle mouse click           just click
  middle mouse drag            hold, move immediately
  middle mouse scroll          hold, wait for a while, move


Usage: $# [OPTION...]

  -h, --help                   show this help and quit successfully.
  -t, --threshold=PIXELS       set the drag threshold to PIXELS.
                               default is 20.
  -d, --delay=TIME             set the scroll delay to TIME milliseconds.
                               default is 500.
  -n, --name=NAME              set the emulated mouse device name to NAME.
                               default is "Hiddle Mouse"
  -v, --verbose                increase verbosity by 1. accumulate multiple
                               times to get more verbosity.
                               default verbosity is 0.
""".format(app_name, app_version, app_filename)

proc parse(): Options =
    result.drag_threshold = 20
    result.scroll_delay = 500
    result.emulated_device_name = "Hiddle Mouse"
    result.verbosity = 0
    for kind, key, value in get_opt():
        case kind
        of cmd_argument, cmd_end:
            echo "invalid argument: ", key
            help()
            quit(QUIT_FAILURE)
        of cmd_long_option, cmd_short_option:
            case key
            of "help", "h":
                help()
                quit()
            of "threshold", "t": result.drag_threshold = value.parse_int
            of "delay", "d": result.scroll_delay = value.parse_int
            of "name", "n": result.emulated_device_name = value
            of "verbose", "v": result.verbosity.inc
            else:
                echo "unknown argument $#: $#".format(key, value)
                help()
                quit(QUIT_FAILURE)

let opts* = parse()

when is_main_module:
    help()
    echo opts

