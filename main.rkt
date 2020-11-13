#lang racket/base
(require (for-syntax racket/base
                     racket/syntax)
         racket/list
         racket/cmdline
         racket/port
         racket/string)

(provide define-global
         make-global
         global
         (rename-out [set-global-get! global-set!])
         global-update!
         global-unsafe-update!
         global->cmd-line
         globals
         globals->command-line
         globals->assoc
         globals-interact
         string->boolean
         )

;;; Facility to define a global variable that can be changed on the command line.
;;;
;;; global-unsafe-update! is just as fast as updating a raw variable (see
;;; tests/define-global-stress-test.rkt)
;;;
;;; Warning: Globals are *not* thread-safe (for speed).

;; `get` is actually the value itself, not a procedure
(struct global (name [get #:mutable] help valid? string->value more-commands)
  #:property prop:procedure
  (case-lambda
    [(self) (global-get self)]
    [(self v)
     (unless ((global-valid? self) v)
       (error (global-name self) "invalid value for set!: ~v" v))
     (set-global-get! self v)]))

(define (global-update! g proc)
  (g (proc (global-get g))))

(define (global-unsafe-update! g proc)
  (set-global-get! g (proc (global-get g))))

(define globals '())
(define (add-global! g)
  (set! globals (cons g globals)))

(define (make-global name init help valid? string->value [more-commands '()])
  (define g
    (global name
            init
            help
            valid?
            string->value
            more-commands))
  (add-global! g)
  g)

;; Helper to avoid typing the name twice (and ensure consistency).
;; Use `make-global` to have more flexibility on the variable name and the command-line name.
(define-syntax-rule (define-global var args ...)
  (define var
    (make-global 'var args ...)))

(define (globals->assoc [globals (reverse globals)])
  (map (λ (g) (cons (global-name g) (g)))
       globals))

;; See "Reading Booleans" in the Reference.
;; We add some common cases
(define (string->boolean s)
  (if (member s '("#false" "#f" "#F" "false" "False" "FALSE"))
      #f
      #t))

;; Returns a rule for parse-command-line
;; If the validation of g matches bool? then it is presented
;; as a boolean flag that inverts the current value of g.
;; For example, (define-global abool #t "abool" boolean? string->boolean)
;; (only) produces the flag "--no-abool" which sets abool to #f,
;; while (define-global abool #f "abool" boolean? string->boolean)
;; (only) produces the flag "--abool" which sets abool to #t.
;; Note that for booleans more-commands are used as is (without being negated).
;; Setting bool? to #f treats boolean globals as normal flags that take
;; one argument.
;; By default, name->string removes some leading and trailing special characters.
(define (global->cmd-line g
                          #:name->string
                          [name->string (λ (n) (string-trim (symbol->string n)
                                                            #px"[\\s*?]+"))]
                          #:boolean-valid? [bool? boolean?]
                          #:boolean-no-prefix [no-prefix "--no-~a"])
  (if (equal? (global-valid? g) bool?)
      `[(,(format (if (g) no-prefix "--~a")
                  (name->string (global-name g)))
         ,@(global-more-commands g))
        ,(λ (flag) (global-unsafe-update! g not))
        (,(global-help g))]
      `[(,(format "--~a" (name->string (global-name g)))
         ,@(global-more-commands g))
        ,(λ (flag v) (g ((global-string->value g) v)))
        (,(global-help g)
         ,(format "~a" (g)))]))

;; Simple command line with just the globals
;; TODO: multi with `update` of the global
;; See `global->cmd-line` for bool? and no-prefix.
(define (globals->command-line #:globals [globals (reverse globals)]
                               #:boolean-valid? [bool? boolean?]
                               #:boolean-no-prefix [no-prefix "--no-~a"]
                               #:mutex-groups [mutex-groups '()]
                               #:argv [argv (current-command-line-arguments)]
                               #:program [program "<prog>"]
                               . arg-names)
  (define (g->cmd g)
    (global->cmd-line g #:boolean-valid? bool? #:boolean-no-prefix no-prefix))
  (parse-command-line
   program argv
   (cons
    `(once-each
      ,@(map g->cmd (remove* (flatten mutex-groups) globals eq?)))
    (for/list ([gr (in-list mutex-groups)])
      `(once-any
        ,@(map g->cmd gr))))
   (λ (flag-accum . rargs) rargs)
   arg-names))

(require text-table)

(define (simple-table->string table)
  (table->string
   table
   #:align 'left
   #:border-style 'space #:row-sep? #f #:framed? #f))

(define (globals-help [globals (reverse globals)])
  (if (empty? globals)
      "No globals."
      (simple-table->string
       (for/list ([g (in-list globals)])
         (define h (global-help g))
         (list (format "  ~a" (global-name g))
               ":"
               (if (list? h)
                   (string-join h "\n")
                   h))))))

(define (globals-values [globals (reverse globals)])
  (if (empty? globals)
      "No globals."
      (simple-table->string
       (for/list ([g (in-list globals)])
         (list (global-name g) ":" (format "~v" (g)))))))

;; User interaction loop to read and write globals
(define (globals-interact [globals (reverse globals)])
  (define names (map global-name globals))
  (define (find-global name)
    (findf (λ (g) (eq? name (global-name g))) globals))
  (let loop ()
    (display "> ")
    (define cmd (read-line))
    ;; TODO: what if globals have the names of default commands? (change the defaults?)
    (case cmd
      [("") (void)] ; exit
      [("help")
       (displayln
        (simple-table->string
         '(("<Enter>" ":" "exit")
           ("<global>" ":" "print the global's value")
           ("<global> <v>" ":" "set the global's value to <v>")
           ("print" ":" "print all global values"))))
       (displayln "\nglobals:")
       (displayln (globals-help globals))
       (loop)]
      [("print")
       (displayln (globals-values globals))
       (loop)]
      [else
       (define strs (string-split cmd))
       (case (length strs)
         [(1)
          (define g (find-global (string->symbol (first strs))))
          (if g
              (displayln (global-get g))
              (printf "Unknown command: ~a\n" cmd))]
         [(2)
          (define g (find-global (string->symbol (first strs))))
          (if g
              (let ([val ((global-string->value g) (second strs))])
                (if ((global-valid? g) val)
                    (g val)
                    (displayln "Invalid value.")))
              (printf "Unknown command: ~a\n" cmd))]
         [else
          (displayln "Too many arguments.")])
       (loop)])))

;; Example.
;; Run this module with
;; racket define-global.rkt --help
;; racket define-global.rkt --color blue
;; racket define-global.rkt --color orange   # error
;; racket define-global.rkt --no-bbool --abool
