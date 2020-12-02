#lang racket/base

(require global)

;;; Try the following calls from the command line:
;;; 1) racket -l global/example
;;; 2) racket -l global/example -- --color blue
;;; 2) racket -l global/example -- --color purple
;;; 3) racket -l global/example -- --help



;; We use the convention that global names are surrounded by '*',
;; not so much because they are globals, but so as to avoid mistakes such as
;; (when *my-global* (displayln "my-global is true"))
;; when it should be
;; (when (*my-global*) (displayln "my-global is true")).
;; That is, seeing *my-global* without a leading parethesis, should look 'naked'.

;; Note that globals can be defined in a different module than the call to `globals->command-line`
;; (as long as the former module is required by the latter).
  
(define-global *max-steps* 100
  '("Maximum number of steps"
    "Not the minimum number of steps") ; help string (multi-line)
  exact-nonnegative-integer? ; validation
  string->number) ; read from string

(define-global *max-depth* 10
  "Maximum depth"
  exact-nonnegative-integer? ; validation
  string->number
  '("-d" "--depth")) ; additional flags

(define-global *comment* "no comment"
  "Some comment"
  string?
  values)

;; A boolean can be defined like a normal global:
(define-global *abool* #f
  "A boolean"
  boolean?
  string->boolean)

;; Or using a more concise form:
(define-global:boolean *bbool* #t
  "Another boolean")

;; Categorical values are easy to define:
(define-global:category *color* 'red
  '(red green blue white black yellow)
  (format "The color.")
  '("-c"))

(define-global:boolean *interact* #f
  "Start global-interaction at the end of the program?")

(displayln "Global values before processing the command line:")
(globals->assoc)

(define file
  (globals->command-line #:program "global-example"
                         #:mutex-groups (list (list *max-steps* *max-depth*))
                         "file" "dir"))

(displayln "\nGlobal values after processing the command line:")
(globals->assoc)

(displayln "\nIndividual global values:")
(*max-steps*)
(*comment*)
(*color*)

(displayln "\nChanging the value of a global:")
(*color* 'yellow)
(*color*)
(with-globals ([*color* 'blue])
  (displayln (*color*)))
(*color*)

(when (*interact*)
  (newline)
  (displayln "Starting globals-interaction. Try 'help'.")
  (globals-interact))
