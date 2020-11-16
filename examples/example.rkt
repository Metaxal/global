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
  '("-d" "--depth"))

(define-global *comment* "no comment"
  "Some comment"
  string?
  values)

(define-global *abool* #f
  "A boolean"
  boolean?
  string->boolean)

(define-global *bbool* #t
  "Another boolean"
  boolean?
  string->boolean)

(define colors '(red green blue white black yellow))
(define-global *color* 'red
  (format "The color. One of ~a" colors)
  (λ (v) (memq v colors))
  string->symbol
  '("-c"))

(define-global *interact* #f
  "Start global-interaction at the end of the program?"
  boolean?
  string->boolean)

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
(*color* 'yellow)
(*color*)

(when (*interact*)
  (newline)
  (displayln "Starting globals-interaction. Try 'help'.")
  (globals-interact))
