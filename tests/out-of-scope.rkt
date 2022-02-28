#lang racket/base

(require global
         rackunit)

(define-global:natural1 *a* 10
  "num")

(check-equal? (map global-name (get-globals))
              '(*a*))

(let ()
  (define-global:natural1 *b* 10
    "num")
  (check-equal? (map global-name (get-globals))
                '(*a* *b*)))

(collect-garbage) ; important
(check-equal? (map global-name (get-globals))
              '(*a*))
