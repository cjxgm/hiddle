import strutils

type Sem_ver = object
    major*: int
    minor*: int
    patch*: int
    postfix*: string

proc init_sem_ver*(major, minor, patch: int = 0; postfix = ""): Sem_ver =
    Sem_ver(
        major: major,
        minor: minor,
        patch: patch,
        postfix: postfix,
    )

proc `$`*(ver: Sem_ver): string = "$#.$#.$#$#".format(ver.major, ver.minor, ver.patch, ver.postfix)

