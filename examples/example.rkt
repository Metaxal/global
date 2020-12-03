#lang racket/base

(require global
         racket/pretty)

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

;========================;
;=== Global variables ===;
;========================;
  
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

(define-global:string *comment* "no comment"
  "Some comment")

;; A boolean global defined in a concise form.
;; Note that since *abool* is #f by default,
;; the flag '--abool' is generated.
(define-global:boolean *abool* #f
  "A boolean")

;; Or using a more general definition.
;; Note that since *bbool* is #t by default,
;; the flag '--no-bbool' is generated.
(define-global *bbool* #t
  "Another boolean"
  boolean?
  string->boolean)

;; Categorical values are easy to define:
(define-global:category *color* 'red
  '(red green blue white black yellow)
  (format "The color.")
  '("-c"))

(define-global:boolean *interact* #f
  "Start global-interaction at the end of the program?")

;============================;
;=== Command line parsing ===;
;============================;

(displayln "Global values before processing the command line:")
(pretty-print (globals->assoc))

(define file
  (globals->command-line #:program "global-example"
                         #:mutex-groups (list (list *max-steps* *max-depth*))
                         "file" "dir"))

(displayln "\nGlobal values after processing the command line:")
(pretty-print (globals->assoc))

;==========================;
;=== Further processing ===;
;==========================;

(displayln "\nIndividual global values:")
(*max-steps*)
(*comment*)
(*color*)

(displayln "\nChanging the value of a global:")
(*color* 'yellow)
(*color*)
(with-globals ([*color* 'blue])
  (println (*color*)))
(*color*)

(when (*interact*)
  (newline)
  (displayln "Starting globals-interaction. Try 'help'.")
  (globals-interact))
