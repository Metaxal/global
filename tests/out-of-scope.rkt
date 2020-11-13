#lang racket/base

(require global
         rackunit)

(define-global *a* 10
  "num"
  exact-positive-integer?
  string->number)

(check-equal? (map global-name (get-globals))
              '(*a*))

(let ()
  (define-global *b* 10
    "num"
    exact-positive-integer?
    string->number)
  (check-equal? (map global-name (get-globals))
                '(*a* *b*)))

(collect-garbage) ; important
(check-equal? (map global-name (get-globals))
              '(*a*))
