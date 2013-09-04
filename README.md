# hiddle - Hybrid mIDDLE mouse button
Licensed under the MIT License.<br>
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
* `glibc` (Of course! It's the standard GNU C library)
* If you are going to compile from source, a working C language build
  environment is also required (GNU make, gcc, standard GNU C headers).

## Compile and Install
Just
```bash
make
sudo make install
```

## Uninstall
Just
```bash
sudo make uninstall
```

## Use
Generally, just run `hiddle`.
You can also run `hiddle --help` for more information.

**But**, before running `hiddle`, you should gain **read** permission
to your mouse device file (default is `/dev/input/mice`). You can use
any one of the following methods:
* run `hiddle` with `root`
* `sudo hiddle`
* `sudo chmod 644 /dev/input/mice` then run `hiddle`, but you should set
  the permission every time you fire up your computer.
* To persist the permission, use udev rules.
  Edit file `/etc/udev/rules.d/99-zzz-mouse.rules`
  (the path may be different in different OS. The prefix `99-zzz` is used
  so that the rule will be parsed last.):

  ```udev
  KERNEL=="mice", MODE="644"
  ```

## To Do
See the top of `hiddle.c`.

