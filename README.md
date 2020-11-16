global
======

Define, get, set global variables, and easily generate command line parsers.

# Installation
From the command line:
```
raco pkg install global
```

# Usage


Save this minimal example in the file "burger.rkt":
```racket
#lang racket/base
(require global)

(define-global *burgers* 10       ; name + initial value
  "Number of burgers to order"    ; help string
  exact-nonnegative-integer?      ; validation
  string->number)                 ; conversion from input string

(void (globals->command-line #:program "minimal.rkt"))

(printf "You've just ordered ~a burgers. Thank you.\n" (*burgers*))
```
Then on the command line, try some of the following:
```shell
racket burger.rkt 
racket burger.rkt --burgers 200
racket burger.rkt --burgers many
racket burger.rkt --help
```
A similar example is included and you can try it directly (after installing the package) with
```shell
racket -l global/examples/minimal -- --burgers 3
```

See the [docs](https://pkg-build.racket-lang.org/doc/global@global/index.html).
