# Alarm


## Installation
Download the executable from releases

or

Install [odin-lang](https://odin-lang.org);
```
git clone https://github.com/Up05/alarm-linux
cd alarm-linux
odin build .
```

Then you may add `alarm --all` to your window manager startup script (for example: `.config/i3/config`)

And you may also put `alias alarms=alarm` in your shell config.

## Usage

```
alarm [OPTIONS] TIME [NAME CAN BE SEPERATED BY SPACE]
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
    alarm 2M -7d "bus ticket"
```
