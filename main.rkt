#lang racket/base
(require (for-syntax racket/base
                     racket/syntax)
         racket/contract/base
         racket/format
         racket/list
         racket/cmdline
         racket/port
         racket/string
         text-table)

(provide define-global
         define-global:boolean
         define-global:string
         define-global:category
         with-globals

         global?
         
         (contract-out
          [make-global (->* [symbol?
                             any/c
                             (or/c string? (listof string?))
                             procedure?
                             procedure?]
                            [(listof string?)]
                            global?)]
          [global-name              (-> global? any)]
          [global-help              (-> global? any)]
          [global-valid?            (-> global? any)]
          [global-string->value     (-> global? any)]
          [global-more-commands     (-> global? any)]
          [global-set!              (-> global? any/c any)]
          [global-update!           (-> global? procedure? any)]
          [global-set-from-string!  (-> global? string? any)]
          [globals->assoc           (->* [] [(listof global?)] any)])
         (rename-out [set-global-get! global-unsafe-set!])
         global-unsafe-update!
         get-globals
         global->cmd-line-rule
         globals->command-line
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

(define (global-set! g v)
  (g v))

(define (global-update! g proc)
  (g (proc (global-get g))))

(define (global-unsafe-update! g proc)
  (set-global-get! g (proc (global-get g))))

(define globals '())
(define (add-global! g)
  (set! globals (cons (make-weak-box g) globals)))

(define (get-globals)
  (reverse (filter-map weak-box-value globals)))

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

(define (globals->assoc [globals (get-globals)])
  (map (λ (g) (cons (global-name g) (g)))
       globals))

;; See "Reading Booleans" in the Reference.
;; We add some common cases for the command line
(define (string->boolean s)
  (and (member (string-downcase (string-trim s))
              '("#f" "#false" "false"))
       #t))

(define (global-set-from-string! g str)
  (define v ((global-string->value g) str))
  (unless ((global-valid? g) v)
    (error 'global-set-from-string!
           "Invalid value for global ~a: ~v (string value: ~s)"
           (global-name g)
           v
           str))
  (set-global-get! g v))

(define (default-name->string n)
  (string-trim (symbol->string n)
               #px"[\\s*?]+"))

;; Returns a rule for parse-command-line.
(define (global->cmd-line-rule g
                               #:name->string [name->string default-name->string]
                               #:boolean-valid? [bool? boolean?]
                               #:boolean-no-prefix [no-prefix "--no-~a"])
  (unless (global? g)
    (raise-argument-error 'global->cmd-line-rule global? g))
  (if (equal? (global-valid? g) bool?)
    `[(,(format (if (g) no-prefix "--~a")
                (name->string (global-name g)))
       ,@(global-more-commands g))
      ,(λ (flag) (global-unsafe-update! g not))
      (,(global-help g))]
    `[(,(format "--~a" (name->string (global-name g)))
       ,@(global-more-commands g))
      ,(λ (flag v) (global-set-from-string! g v))
      (,(global-help g)
       ,(format "~a" (g)))]))

;; Simple command line with just the globals
;; TODO: multi with `update` of the global
;; See `global->cmd-line` for bool? and no-prefix.
(define (globals->command-line #:globals [globals (get-globals)]
                               #:name->string [name->string default-name->string]
                               #:boolean-valid? [bool? boolean?]
                               #:boolean-no-prefix [no-prefix "--no-~a"]
                               #:mutex-groups [mutex-groups '()]
                               #:argv [argv (current-command-line-arguments)]
                               #:program [program "<prog>"]
                               . arg-names)
  (define (g->cmd g)
    (global->cmd-line-rule g
                           #:name->string name->string
                           #:boolean-valid? bool?
                           #:boolean-no-prefix no-prefix))
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

(define (simple-table->string table)
  (table->string
   table
   #:align 'left
   #:border-style 'space #:row-sep? #f #:framed? #f))

(define (globals-help [globals (get-globals)])
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

(define (globals-values [globals (get-globals)])
  (if (empty? globals)
      "No globals."
      (simple-table->string
       (for/list ([g (in-list globals)])
         (list (global-name g) ":" (format "~v" (g)))))))

;; User interaction loop to read and write globals
(define (globals-interact [globals (get-globals)])
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

;; A category is a list of atoms read with `read`, i.e.,
;; numbers, symbols, etc. To read to a string, it must be
;; quoted on the command line, i.e., "\"a racket string\"".
;; TODO: use syntax-parse
(define-syntax define-global:category
  (syntax-rules ()
    [(_ id init vals help)
     (define-global:category id init vals help '())]
    [(_ id init vals help more-commands)
     (define-global id init
       (let ([h1 help] ; in case `help` is not an atom
             [h2 (apply ~a "One of:" vals #:separator " ")])
         (if (list? h1)
           (append h1 (list h2))
           (list h1 h2)))
       (λ (x) (member x vals))
       (λ (s) (with-input-from-string s read))
       more-commands)]))

(define-syntax define-global:boolean
  (syntax-rules ()
    [(_ id init help)
     (define-global:boolean id init help '())]
    [(_ id init help more-commands)
     (define-global id init
       help
       boolean?
       string->boolean
       more-commands)]))

(define-syntax define-global:string
  (syntax-rules ()
    [(_ id init help)
     (define-global:string id init help '())]
    [(_ id init help more-commands)
     (define-global id init
       help
       string?
       values
       more-commands)]))

;; TODO: :input-file :input-directory :output-file
;; check if exists

(define-syntax-rule (with-globals ([g v] ...) body ...)
  (let* ([gs (list g ...)] ; in case `g` is an expression
         [old-vs (for/list ([gg (in-list gs)]) (gg))]
         [vs (list v ...)])
    (dynamic-wind
     (λ () (for ([gg (in-list gs)] [x (in-list vs)])
             (gg x)))
     (λ () body ...)
     (λ () (for ([gg (in-list gs)] [x (in-list old-vs)])
             (gg x))))))


