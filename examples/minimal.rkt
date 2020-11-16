#lang racket/base
(require global)

(define-global *burgers* 2     ; name + initial value
  "Number of burgers to order" ; help string
  exact-nonnegative-integer?   ; validation
  string->number)              ; conversion from input string

(void (globals->command-line #:program "burgers.rkt"))

(printf "You've just ordered ~a burgers.\n" (*burgers*))

(*burgers* 200)
(printf "However I prefer that you order ~a burgers. Thank you.\n" (*burgers*))
