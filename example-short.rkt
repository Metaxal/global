#lang racket/base
(require global)

(define-global *burgers* 10 ; name + default value
  '("How many burgers do you want to order today?") ; help string
  exact-nonnegative-integer? ; validation
  string->number  ; conversion from input string
  '("-b")) ; optional additional command line names

(void (globals->command-line #:program "global-example-short"))

(printf "You've just ordered ~a burgers. Thank you.\n" (*burgers*))
