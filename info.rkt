#lang info
(define collection "global")
(define deps '("text-table"
               "base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))
(define scribblings '(("scribblings/global.scrbl" ())))
(define pkg-desc "Global: global variables for simple command line flags")
(define version "0.0")
(define pkg-authors '(lorseau))

(define test-omit-paths '("examples/" "tests/define-global-stress-test.rkt"))
(define test-include-paths '("tests/out-of-scope.rkt"))
