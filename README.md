# redemon

## Basic usage

Runs `echo "Hello World!"` whenever a file in the directory `foo` changes.

```sh
redemon --path=foo echo "Hello World!"
```

## Manual

```
REDEMON(1)                      Redemon Manual                      REDEMON(1)



NAME
       redemon - A filewatcher built with luv

SYNOPSIS
       redemon [OPTION]... COMMAND [ARGS]...

ARGUMENTS
       ARGS
           args to send to COMMAND

       COMMAND (required)
           Command to run

OPTIONS
       --delay=DELAY (absent=100)
           Time in ms to wait before restarting

       -e EXT, --extensions=EXT
           File extensions that should trigger changes

       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of `auto',
           `pager', `groff' or `plain'. With `auto', the format is `pager` or
           `plain' whenever the TERM env var is `dumb' or undefined.

       -p PATH, --path=PATH
           Path to watch, repeatable

       --paths=PATHS
           Paths to watch as comma separated list

       -v, --verbose
           Verbose logging

Redemon                                                             REDEMON(1)
```
