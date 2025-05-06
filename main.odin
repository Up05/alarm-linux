package main

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:time"
import dt "core:time/datetime"
import "core:mem" // what's runtime?
import "core:thread"
import "core:c/libc"

POSSIBLE_FLAGS : [] string : {
    "-h", "--help", "-?",
    "-l", "--list",
    "-c", "--clear",
    "-a", "--add",
    "--all" // execute all from the table in /tmp/ulti-alarms
}

DateTime :: dt.DateTime

main :: proc() {

    if len(os.args) <= 1 { print_help(); return }
    
    args := os.args[1:]
    for len(args) > 0 {

        switch args[0] {
        case "-h", "-?", "--help": 
            print_help()
            args = args[1:]

        case "-l", "--list": 
            print_list()
            args = args[1:]

        case "-c", "--clear":
            clear_alarms()
            args = args[1:]

        case "--all":
            read_alarms() // and execute them too
            args = args[1:]
        
        case:
            if args[0] == "-a" || args[0] == "--add" do args = args[1:]
            datetime := parse_add(&args)

            name: [dynamic] byte
            
            for len(args) > 0 {
                if any_of(args[0], ..POSSIBLE_FLAGS) {
                    fmt.printfln("Everything after the time specifiers is considered the name of an alarm! '%s' is basically ignored!", args[0])
                }
                append_string(&name, args[0])
                append(&name, 32) // <Space>
                args = args[1:]
            }

            lo, _ := time.datetime_to_time(localtime())
            hi, _ := time.datetime_to_time(datetime)

            diff := time.diff(lo, hi)
            if diff < 0 {
                fmt.println("I am so sorry, but the program cannot set alarms into the past. There is no POSIX standard function for that.")
                return 
            }
            
            if len(name) == 0 do append_string(&name, "untitled alarm")

            write_alarm(hi,   string(name[:]))
            prime_alarm(diff, string(name[:]))
        }
    }
}

prime_alarm :: proc(duration: time.Duration, name: string) {
    /*
      prime-alarm.sh:
      ---------------------------------------------------
      #!/bin/sh
      nohup bash -c "sleep $1; notify-send $2 -a alarm" &> /dev/null &
    */
    err := os.execvp("/home/ulti/src/alarm/prime-alarm.sh", { fmt.aprint(i64(duration) / 1e9), fmt.aprintf("'%s'", name) })
}

go_off :: proc(name: string) {
    os.execvp("notify-send", { name, "-a", "alarm" })
}

parse_add :: proc(args: ^[] string) -> (res: DateTime) {
    
    res = localtime()

    for len(args^) > 0 {

        number, unit := partition_date(args[0])
        
        if value, ok := strconv.parse_int(number); ok {

            switch unit {
            case "s": res, _ = dt.add_delta_to_datetime(res, { seconds = auto_cast (1 * value)    })     // res.second += auto_cast value
            case "m": res, _ = dt.add_delta_to_datetime(res, { seconds = auto_cast (60 * value)   })     // res.minute += auto_cast value
            case "h": res, _ = dt.add_delta_to_datetime(res, { seconds = auto_cast (3600 * value) })     // res.hour   += auto_cast value
            case "d": res, _ = dt.add_delta_to_datetime(res, { days    = auto_cast (1 * value)    })     // res.day    += auto_cast value
            case "M": res.month += auto_cast(value) % 12; if res.month < 0 do res.month = 12 - res.month     // res.month  += auto_cast value
            case "y": res.year += auto_cast value
            case: 
                fmt.printf("Entered bad unit after date: '%s'\n", unit)
                return
            }    

            args^ = args^[1:]

        } else {
            return
        }

    }
    return
}


print_help :: proc() {
    fmt.println(`alarm [OPTIONS] TIME [NAME CAN BE SEPERATED BY SPACE]
alarm -h, --help    # prints this menu
alarm -l, --list    # prints currently active alarms
alarm -a, --add     # (unneeded)
alarm -c, --clear   # clear all alarms
alrmm --all         # should be run on system startup, it primes all leftover alarms

TIME is [SIGN][DIGITS][UNIT], e.g.: -5h   or   1h 30m
TIME UNITS: s(econd) m(inute) h(our) d(ay) M(onth) y(ear)
Example: 
    alarm 2m 30s grab lunch
    alarm 2h clothes
    alarm 2M -7d "bus ticket"`)
}

Alarm :: struct { durr: time.Duration, name: string }

print_list :: proc() {
    alarms := read_alarms(prime = false)
    
    fmt.println("----------------------------------")
    for alarm in alarms {
        fmt.println(alarm.name, "\t", alarm.durr / 1e9 * 1e9, "(EXPIRED)" if alarm.durr < 0 else "")
    }
    fmt.println("----------------------------------")

    delete(alarms)
}

clear_alarms :: proc() {
    ok := os.write_entire_file("/tmp/ulti-alarms", {})
    if !ok do fmt.println("Failed to clear the file 'tmp/ulti-alarms' you can delete it manually.")
}

// for --all
read_alarms :: proc(prime := true) -> (out: [dynamic] Alarm) {

    if buf, ok := os.read_entire_file_from_filename("/tmp/ulti-alarms"); ok {
        
        if prime do clear_alarms()

        for len(buf) >= size_of(time.Time) + size_of(int) {
            date := to_T(buf[:size_of(time.Time)], time.Time);  buf = buf[size_of(time.Time):]
            slen := to_T(buf[:size_of(int)], int);              buf = buf[size_of(int):]
            name := string(buf[:slen]);                         buf = buf[slen:]

            now, _ := time.datetime_to_time(localtime())
            a: Alarm = { time.diff(now, date), name }

            append(&out, a)

            if prime { 

                if a.durr < 0 {
                    go_off(name)
                    continue
                }

                write_alarm(date, name)

                thread.create_and_start_with_poly_data(a, proc(alarm: Alarm) {
                    prime_alarm(alarm.durr, alarm.name)
                })
            }

        }   
    }
    return
}

write_alarm :: proc(hi: time.Time, name: string) {
    buf: [dynamic] byte
    append_elems(&buf,  ..mem.any_to_bytes(hi))
    append_elems(&buf,  ..mem.any_to_bytes(len(name)))
    append_string(&buf, name)
    
    if ok := append_file("/tmp/ulti-alarms", buf[:]); ok {
        fmt.println("Saved alarm to '/tmp/ulti-alarms'")
    } else {
        fmt.println("Failed to save alarm to the file '/tmp/ulti-alarms'! The alarm will get deleted on system shutdown!")
    }

    delete_dynamic_array(buf)

}


append_file :: proc(path: string, new: [] byte) -> bool {
    data: [dynamic] byte
    saved, ok := os.read_entire_file(path)
    if ok do append(&data, ..saved)
    append(&data, ..new)
    // defer delete(data)
    return os.write_entire_file(path, data[:])
}

