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

;; string->boolean and global-set-from-string!
(for ([s (in-list '("#t" "#true" "true" " TRUE "))])
  (check-equal? (string->boolean s) #t))
(for ([s (in-list '("#f" "#false" "false" " #F "))])
  (check-equal? (string->boolean s) #f))
(check-equal? (string->boolean "banana") 'invalid)

(define-global:boolean *b* #f "a bool")
(global-set-from-string! *b* "true")
(check-equal? (*b*) #t)
(global-set-from-string! *b* "#f")
(check-equal? (*b*) #f)
(check-exn exn:fail? (λ () (global-set-from-string! *b* "banana")))
(check-equal? (*b*) #f)

;; Boolean more-commands negation prefixing & dynamic sensitivity
(define-global:boolean *g* #t "bool with aliases" '("--alias" "-a"))
(check-equal? (car (global->cmd-line-rule *g*))
              '("--no-g" "--no-alias" "-a"))

(*g* #t)
(void (globals->command-line #:globals (list *g*) #:argv #("--no-alias")))
(check-equal? (*g*) #f)

(*g* #t)
(void (globals->command-line #:globals (list *g*) #:argv #("-a")))
(check-equal? (*g*) #f)

(*g* #t)
(check-exn exn:fail?
           (λ () (globals->command-line #:globals (list *g*) #:argv #("--alias"))))

;; Mutating (*g* #f) before calling globals->command-line flips expected flags to positive
(*g* #f)
(check-equal? (car (global->cmd-line-rule *g*))
              '("--g" "--alias" "-a"))

(*g* #f)
(void (globals->command-line #:globals (list *g*) #:argv #("--alias")))
(check-equal? (*g*) #t)

(*g* #f)
(void (globals->command-line #:globals (list *g*) #:argv #("-a")))
(check-equal? (*g*) #t)

(*g* #f)
(check-exn exn:fail?
           (λ () (globals->command-line #:globals (list *g*) #:argv #("--no-alias"))))

;; Passing "--no-..." in more-commands for a boolean global raises an error
(define-global:boolean *bad-neg* #t "bad neg" '("--no-alias"))
(check-exn exn:fail:contract?
           (λ () (global->cmd-line-rule *bad-neg*)))

;; Malformed flag in more-commands raises an error
(define-global:boolean *bad-flag* #f "bad flag" '("alias"))
(check-exn exn:fail:contract?
           (λ () (global->cmd-line-rule *bad-flag*)))

;; Flag deduplication
(define-global:boolean *foo* #f "doc" '("--foo" "--bar" "--foo"))
(check-equal? (car (global->cmd-line-rule *foo*))
              '("--foo" "--bar"))
(*foo* #t)
(check-equal? (car (global->cmd-line-rule *foo*))
              '("--no-foo" "--no-bar"))

(define-global:integer *num* 0 "num doc" '("--num" "-n" "-n"))
(check-equal? (car (global->cmd-line-rule *num*))
              '("--num" "-n"))

