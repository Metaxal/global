#lang racket/base
(require global
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
