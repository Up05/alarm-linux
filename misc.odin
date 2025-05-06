package main

import "core:time"
import dt "core:time/datetime"
import "core:c/libc"

partition_date :: proc(str: string) -> (number, unit: string) {
    for r, i in str {
        if !(r == '-' || r == '+' || (r >= '0' && r <= '9')) {
            return str[:i], str[i:]
        }
    }
    return "", ""
}

any_of :: proc(a: $T, B: ..T) -> bool {
    for b in B {
        if a == b do return true
    }
    return false
}

localtime :: proc() -> (res: dt.DateTime) {
    temp := libc.time(nil)
    res, _ = time.time_to_datetime(time.now())
    tm := libc.localtime(&temp)
    res.hour   += auto_cast (tm.tm_gmtoff / 3600) // bit ehhhh
    res.minute += auto_cast (tm.tm_gmtoff % 3600 / 60)
    res.second += auto_cast (tm.tm_gmtoff % 60)
    return
}

to_T :: proc(data: [] byte, $T: typeid) -> T { return (cast(^T) raw_data(data))^ }

