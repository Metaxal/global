global
======

Define, get, set global variables, and easily generate command line parsers.

# Installation
From the command line:
```
raco pkg install global
```

# Usage


Minimal example (included):
```racket
#lang racket/base
(require global)

(define-global *burgers* 10  ; name + default value
  '("How many burgers do you want to order today?") ; help string
  exact-nonnegative-integer? ; validation
  string->number)  ; conversion from input string

(void (globals->command-line #:program "minimal.rkt"))

(printf "You've just ordered ~a burgers. Thank you.\n" (*burgers*))
```
You can try this example with
```shell
racket -l global/examples/minimal
```
or
```shell
racket -l global/examples/minimal -- --burgers 200
```
or
```shell
racket -l global/examples/minimal -- --help
```
If you save the above example in a file and run racket directly on it (in the corresponding directory), you don't need the `--`:
```shell
racket minimal.rkt --burgers 3
```

See the [docs](https://pkg-build.racket-lang.org/doc/global@global/index.html).
