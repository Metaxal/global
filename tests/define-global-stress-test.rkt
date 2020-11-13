#lang racket/base

(require global)

(define-global *counter* 0
  "Counter"
  number?
  string->number)

(define counter 0)

(define N 10000000)

(collect-garbage)
(time
 (for ([n (in-range N)])
  (if (= 0 (modulo n 100))
      (set! counter (- counter 1))
      (set! counter (+ counter 1)))))

;; Just as fast as the raw counter!
(collect-garbage)
(time
 (for ([n (in-range N)])
  (if (= 0 (modulo n 100))
      (global-unsafe-update! *counter* sub1)
      (global-unsafe-update! *counter* add1))))

(*counter* 0)

;; 2-3x slower.
(collect-garbage)
(time
 (for ([n (in-range N)])
  (if (= 0 (modulo n 100))
      (global-update! *counter* sub1)
      (global-update! *counter* add1))))


