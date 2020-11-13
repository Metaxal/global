#lang racket/base
(require global)

(define-global *burgers* 1 ; name + default value
  '("How many burgers do you want to order today?") ; help string
  exact-nonnegative-integer? ; validation
  string->number)  ; conversion from input string

(void (globals->command-line #:program "get-burgers"))

(printf "You've just ordered ~a burgers.\n" (*burgers*))

(*burgers* 200)
(printf "However I prefer that you order ~a burgers. Thank you.\n" (*burgers*))
