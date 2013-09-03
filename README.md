# hiddle - Hybrid mIDDLE mouse button
Licensed under the MIT License.
Copyright (C) 2013 eXerigumo Clanjor (哆啦比猫/兰威举)<hr>

This little program is for those who are using a laptop
(with physical middle mouse button) and need both the ability to
use middle mouse drag and the ability to use middle mouse scroll.

With this program:
* to **click** middle mouse button: just **click** it
* to **drag** with middle mouse button: **hold** down it, and **move** your mouse
  within 1 second (the time will be customizable in the future).
* to **scroll** with middle mouse button: **hold** down it, **wait** for 1 second,
  then **move** your mouse.

## Prerequisites
* A working `linux` (`archlinux` recommended)
* A working unix shell environment. More specifically, you need:
  * an `sh`-compatible shell
  * `grep`
  * `head`
  * `cut`
* `xinput` (`xorg-xinput` in archlinux)
* `libxdo` (`xdotool` in archlinux)
* `libc` (Of course! It's the standard C library)
* If you are going to compile from source, a working C language build
  environment is also required (GNU make, gcc, standard C headers).

## Compile
Just
```bash
make
```

## Install
Just move `hiddle` to your `/usr/bin/`

## Uninstall
Just remove `/usr/bin/hiddle`

## Use
You can run the following command to see help:
```bash
hiddle --help
```
You need read permission to your mouse device file
(default is `/dev/input/mice`).
On archlinux, you can write udev rules to set the read permission:
`/etc/udev/rules.d/20-mice-permission.rules`
```udev
KERNEL=="mice", MODE="644"
```

