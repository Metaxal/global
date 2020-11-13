#lang scribble/manual
@require[@for-label[global
                    racket/cmdline
                    racket/base]]

@title{global: Global variables with command-line interaction}
@author{laurent.orseau@"@"gmail.com}

@defmodule[global]

@bold{Usage:} Use @racket[define-global] to define global variables (possibly in different modules),
and optionally use @racket[(globals->command-line)] to automatically generate a command line parser
for all the globals defined in modules that are transitively required.

For a minimal example, look at the file @tt{examples/minimal.rkt}, and run it on the command line with:
@codeblock{racket -l global/examples/minimal -- --help}
and then try for example
@codeblock{racket -l global/examples/minimal -- --burgers 10}
and maybe
@codeblock{racket -l global/examples/minimal -- --burgers a}

@bold{Note:} The @code{-l} and @code{--} are because we run a file that is part of a collection.
But if the current directory is set to the one containining @tt{minimal.rkt}, one can simply write instead:
@codeblock{racket minimal.rkt --burgers 10}

@bold{Additional remarks:}

A global variable defined with @racket[define-global]
in a module A is shared between all modules that require A.

Note that a global defined in module A that is transitively required by module B
can be fully accessed in module B even if A does not export any identifier.

By convention, globals' identifiers are surrounded by *. The value of a global @racket[*my-global*] can be retrieved with @racket[(*my-global*)]
and set with @racket[(*my-global* some-new-value)].



By contrast to parameters, globals
@itemize{
 @item{always have a single value at any time,}
 @item{are not thread safe.}
}



@defproc[(make-global [name symbol?]
                      [init any/c]
                      [help (or/c string? (listof string?))]
                      [valid? (-> any/c any/c)]
                      [string->value (-> any/c any/c)]
                      [more-commands (listof string?) '()])
         global?]{
Returns a global variable with initial value @racketid[init].
The @racketid[name] is for printing purposes.

The procedure @racketid[valid?] is used with @racket[global-set!] and @racket[global-update!]
to check if the new value is valid.
Note that @racketid[valid?] is @emph{not} used on @racketid[init]: this can be useful to set the initial value to @racket[#f]
for example while only allowing certain values when set by the user.

The procedure @racketid[string->value] is used to convert command line arguments to values that are checked with @racketid[valid?]
before setting the corresponding global to this value.
(They could also be used for example in @racket[text-field%] in GUI applications.)

More command line flags for this global variable can be specified in the @racketid[more-commands] argument.
}

@defform[(define-global var )]{
Shorthand for @racket[(define var (make-global 'var ...))]}


@defproc*[([(global? [g any/c]) boolean?]
           [(global-name [g global?]) symbol?]
           [(global-help [g global?]) (or/c string? (listof string?))]
           [(global-valid? [g global?]) (-> any/c boolean?)]
           [(global-string->value [g global?]) (-> string? any/c)]
           [(global-more-commands [g global?]) (listof string?)]
           )]{
Predicate and field accessors of the global's fields.}



@defproc*[([(global-get [g global?]) any/c]
           [(global-set! [g global?] [v any?]) void?]
           [(global-update! [g global?] [updater (-> any/c any/c)]) void?]
           )]{
Get, set and update a global variable's value. Note that parameters get/set style is also available.
The global's validation procedure provided in @racket[make-global] is called by @racket[global-set!]
and @racket[global-update!] and an exception is raised if it returns @racketid[#f].
}

@defproc*[([(global-unsafe-set! [g global?] [v any?]) void?]
           [(global-unsafe-update! [g global?] [updater (-> any/c any/c)]) void?]
           )]{
Like @racket[global-set!] and @racket[global-update!] but the validation procedure is not called.
}

@defproc[(get-globals) (listof global?)]{
Returns the list of globals that have not gone out of scope (even if they cannot be read directly by the module
calling @racket[get-globals]).


@bold{Note:} If one of the transitively require modules
has defined a local(!) global that has become unreachable at call site of
@racket[(get-globals)],
it is advised to precede the call with @racket[(collect-garbage)] to make sure
that the local global does not appear in the returned list.
}


@defproc[(global->cmd-line-rule [g global?]
                                [#:name->string name->string (λ (n) (string-trim (symbol->string n)
                                                                                 #px"[\\s*?]+"))]
                                [#:boolean-valid? bool? boolean?]
                                [#:boolean-no-prefix no-prefix "--no-~a"])
         list?]{
Returns a rule to be used with @racket[parse-command-line].

 Booleans are treated specially on the command line, as they don't require arguments.
If the validation of @racketid[g] is @racket[equal?] to @racketid[bool?] then
the returned rule corresponds to a boolean flag that inverts the @emph{current} value of @racketid[g].
For example,
if @racket[bool?] is @racket[boolean?],
then, for
 @racketblock[(define-global abool #t "abool" boolean? string->boolean)]
 the call
 @racket[(global->cmd-line-rule (list abool))]
 (only) produces a rule with the flag @racket["--no-abool"] which sets @racketid[abool] to @racket[#f]
 if present on the command line,
while for
 @racketblock[(define-global abool #f "abool" boolean? string->boolean)]
it (only) produces the flag @racket["--abool"] which sets abool to @racket[#t].
Note that for booleans, @racket[more-commands] are used as is (without being negated).
Setting @racketid[bool?] to @racket[#f] treats boolean globals as normal flags that take
one argument.
By default, @racketid[name->string] removes some leading and trailing special characters.
}

@defproc[(globals->command-line [#:globals globals (listof global?) (get-globals)]
                                [#:boolean-valid? bool? (-> any/c any/c) boolean?]
                                [#:boolean-no-prefix no-prefix string? "--no-~a"]
                                [#:mutex-groups mutex-groups (listof (listof global?)) '()]
                                [#:argv argv (vectorof (and/c string? immutable?)) (current-command-line-arguments)]
                                [#:program program string? "<prog>"]
                                [trailing-arg-name string?] ...)
         any]{
Produces a command line parser via @racket[parse-command-line]
 (refer to the latter for general information).

See @racket[global->cmd-line-rule] for more information about boolean flags.

Each list of globals within @racket[mutex-groups] are placed in a separate @racketid{once-any} group in
@racket[parse-command-line].

Repeated flags are not supported by globals.

See also the note in @racket[(get-globals)].
}

@defproc[(globals->assoc [globals (listof global?) (get-globals)]) (listof (cons/c symbol? any/c))]{
Returns an association list of the global name and its value.}

@defproc[(globals-interact [globals (get-globals)]) void?]{
Produces a command-line interaction with the user to read and write values of @racket[globals].}

@defproc[(string->boolean [s string?]) boolean?]{
Interprets @racketid[s] as a boolean. Equivalent to
 @racketblock[(and (member (string-downcase (string-trim s))
                           '("#f" "#false" "false"))
                   #t)]
}
