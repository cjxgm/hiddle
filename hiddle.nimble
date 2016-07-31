# vim: ft=nim
mode = ScriptMode.Verbose

# package
version       = "2.0.0"
author        = "Giumo Clanjor (哆啦比猫/兰威举)"
description   = "Hybrid Middle Mouse Button"
license       = "MIT"

# dependencies
requires "nim >= 0.14.2"

# rules
src_dir = "/src"
bin_dir = "/build"
bin = @["hiddle"]

const build_path = this_dir() & bin_dir
const nimcache_path = this_dir() & src_dir & "/" & nimcache_dir()

before build:
    mkdir(build_path)

task clean, "cleanup":
    rmdir(build_path)
    rmdir(nimcache_path)

