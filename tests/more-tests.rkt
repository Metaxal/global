#lang racket/base
(require "../main.rkt"
         rackunit)

(define-global *v* #() "vec"
  (λ (v) (and (vector? v)
              (for/and ([x (in-vector v)]) (positive? x))))
  values)

(check-equal? (*v*) #())
(*v* #(1))
(check-equal? (*v*) #(1))
(check-exn exn:fail? (λ () (*v* 'a)))
(check-exn exn:fail? (λ () (*v* #(-1))))

(define v2 (vector 1 2))
(*v* v2)
(check-equal? (*v*) v2)

(check-not-exn
 (λ ()
   ;; When exiting `with-globals`, we should not check whether the old value is still correct.
   ;; This can happen in particular for example when the validation is `file-exists?` and the
   ;; file has been deleted in-between.
   (with-globals ([*v* #(3)])
     (vector-set! v2 0 -1))))

(check-exn (λ (exn) (and (exn:fail:contract? exn)
                         (regexp-match (regexp-quote "expected: (or/c string? (listof string?))")
                                       (exn-message exn))))
           (λ () (define-global *truc1* #f values values '("-r")) (void)))
(check-exn (λ (exn) (and (exn:fail:contract? exn)
                         (regexp-match (regexp-quote "expected: procedure?")
                                       (exn-message exn))))
           (λ () (define-global *truc2* #f "help string" values '("-r")) (void)))
(check-exn (λ (exn) (and (exn:fail:contract? exn)
                         (regexp-match (regexp-quote "expected: list?")
                                       (exn-message exn))))
           (λ () (define-global *truc3* #f "" values values "-r") (void)))
(check-exn (λ (exn) (and (exn:fail:contract? exn)
                         (regexp-match (regexp-quote "expected: procedure?")
                                       (exn-message exn))))
           (λ () (define-global *truc4* #f "help" "not-a-procedure" values) (void)))
