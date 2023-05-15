#lang scribble/manual
@require[@for-label[global
                    racket/cmdline
                    racket/base]]

@title{global: Global variables with command-line interaction}
@author{Laurent Orseau}

@defmodule[global]

@bold{Usage:} Use @racket[define-global] to define global variables (possibly in different modules)
with cross-module getters and setters.
@racket[globals->command-line] automatically generates a command line parser
for all the globals defined in modules that are transitively required,
and @racket[globals-interact] generates and textual interaction for reading and writing globals.

Here's a minimal expample that defines the global @racketid[*burgers*]
and generates a command-line parser:
@margin-note{Globals can be used without a command-line parser.}
@#reader scribble/comment-reader
(racketmod
 #:file "burger.rkt"
 racket/base
 (require global)

 (define-global *burgers*     ;; name
   1                          ;; initial value
   "Number of burgers"        ;; help string for the command line
   exact-nonnegative-integer? ;; validation
   string->number)            ;; conversion from input string

 (void (globals->command-line))

 (printf "You ordered ~a burgers.\n" (*burgers*))
 )

Save this example as @tt{burger.rkt}, then on the command line (in the
corresponding directory), type:
@codeblock{racket burger.rkt --help}
then try
@codeblock{racket burger.rkt --burgers 10}
and maybe
@codeblock{racket burger.rkt --burgers a}

@bold{Note:} A similar example is included with the package and can be run with
@codeblock{racket -l global/examples/minimal -- --help}

For a more extensive example, including a use of @racket[globals-interact], try
@codeblock{racket -l global/examples/example -- --help}


@bold{Additional remarks:}

A global variable defined with @racket[define-global]
in a module A is shared between all modules that require A.

Note that a global defined in module A that is transitively required by module B
can be fully accessed in module B even if A does not export any identifier.

By convention, globals' identifiers are surrounded by @racketid[*]. The value of a global @racket[*my-global*] can be retrieved with @racket[(*my-global*)]
and set with @racket[(*my-global* some-new-value)].



By contrast to parameters, globals
@itemize{
 @item{always have a single value at any time,}
 @item{are not thread safe.}
}

Suggestions, questions or issues? File an @hyperlink["https://github.com/Metaxal/global/issues"]{issue}.

@section{Globals}

@defproc[(make-global [name symbol?]
                      [init any/c]
                      [help (or/c string? (listof string?))]
                      [valid? (-> any/c any/c)]
                      [string->value (-> any/c any/c)]
                      [more-commands (listof string?) '()])
         global?]{
Returns a global variable with initial value @racket[init].
The @racket[name] is for printing purposes.

The procedure @racket[valid?] is used when setting or updating the value of the global to check if the new value is valid.
Note that @racket[valid?] is @emph{not} used on @racket[init]: this can be useful to set the initial value to @racket[#f]
for example while only allowing certain values when set by the user.

The procedure @racket[string->value] is used to convert command line arguments to values that are checked with @racket[valid?]
before setting the corresponding global to this value.
(They could also be used for example in @racket[text-field%] in GUI applications.)

@racket[more-commands] is an optional list of additional command-line flags, which can be used in particular
to specify short flags.
}

@defform[(define-global var init help valid? string->value [more-commands])]{
Shorthand for @racket[(define var (make-global 'var ....))].}

@deftogether[
 (@defform[(define-global:boolean  id init help maybe-more-commands)]
   @defform[(define-global:string   id init help maybe-more-commands)]
   @defform[(define-global:natural0 id init help maybe-more-commands)]
   @defform[(define-global:natural1 id init help maybe-more-commands)]
   @defform[(define-global:integer  id init help maybe-more-commands)]
   @defform[(define-global:real     id init help maybe-more-commands)]
   @defform[(define-global:rational id init help maybe-more-commands)])]{
Like @racket[define-global] but specialize @racket[valid?] to be, respectively,
 @racket[boolean?],
 @racket[string?],
 @racket[exact-nonnegative-integer?],
 @racket[exact-positive-integer?],
 @racket[exact-integer?],
 @racket[real?],
 @racket[rational?],
 and specializes @racket[string->value] to @racket[string->boolean], @racket[values], and
 @racket[string->number].}

@defform[(define-global:category id init vals help maybe-more-commands)
         #:grammar ([vals (list expr ...)])]{
Like @racket[define-global] but specializes @racket[(valid? x)]
to @racket[(member x vals)] where @racket[vals] is a list of values,
and uses @racket[read] for @racket[string->value].
The help string is also augmented to display the available set of values.}



@defproc*[([(global? [g any/c]) boolean?]
           [(global-name [g global?]) symbol?]
           [(global-help [g global?]) (or/c string? (listof string?))]
           [(global-valid? [g global?]) (-> any/c boolean?)]
           [(global-string->value [g global?]) (-> string? any/c)]
           [(global-more-commands [g global?]) (listof string?)]
           )]{
Predicate and accessors. See @racket[make-global].}



@defproc*[([(global-get [g global?]) any/c]
           [(global-set! [g global?] [v any/c]) void?]
           [(global-update! [g global?] [updater (-> any/c any/c)]) void?]
           )]{
 @racket[(global-get *g*)] is equivalent to @racket[(*g*)] and returns the value of the global.
 @racket[(global-set! *g* v)] is equivalent to @racket[(*g* v)].
 @racket[global-update!] updates the value of the global based on its previous value.
 @racket[global-set!] and @racket[global-update!]
 raise an exception if @racket[global-valid?] returns @racket[#f] for the new value.
}

@defproc*[([(global-unsafe-set! [g global?] [v any?]) void?]
           [(global-unsafe-update! [g global?] [updater (-> any/c any/c)]) void?]
           )]{
 Forces setting and updating the value of the global @emph{without}
 checking its validity with @racket[global-valid?].
}

@defproc[(global-set-from-string! [g global?] [str string?]) void?]{
Combines @racket[global-string->value] and @racket[global-set!].}

@defproc[(get-globals) (listof global?)]{
Returns the list of globals that have not been GC'ed (even if they cannot be read directly by the module
calling @racket[get-globals]).

@;{
@bold{Note:} 

 If one of the transitively required modules
has defined a local(!) global that has become unreachable at the call site of
@racket[(get-globals)],
it is advised to precede the call with @racket[(collect-garbage)] to make sure
that the local global does not appear in the returned list.
Defining local globals is discouraged, and using submodules is preferred (such as @racket[(submodule+ main ...)]).
}
}

@defproc[(globals->assoc [globals (listof global?) (get-globals)]) (listof (cons/c symbol? any/c))]{
Returns an association list of the global names and their values.}

@defproc[(string->boolean [s string?]) boolean?]{
Interprets @racketid[s] as a boolean. Equivalent to
 @racketblock[(and (member (string-downcase (string-trim s))
                           '("#f" "#false" "false"))
                   #t)]
}

@defform[(with-globals ([g v] ...) body ...)]{
 Changes the value of the global @racket[g] to @racket[v] for the dynamic extent of @racket[body ...].
 Similar to @racket[parameterize], but for globals.}


@section{Command line}

@defproc[(default-name->string [sym symbol?]) string?]{
 Returns a string made of @racket[sym] where the surrounding @racketid[*] and spaces have been removed.
 Used as the default argument for @racket[global->cmd-line-rule] and @racket[globals->command-line].
}

@defproc[(globals->command-line [#:globals globals (listof global?) (get-globals)]
                                [#:name->string name->string (-> symbol? string?) default-name->string]
                                [#:boolean-valid? bool? (-> any/c any/c) boolean?]
                                [#:boolean-no-prefix no-prefix string? "--no-~a"]
                                [#:mutex-groups mutex-groups (listof (listof global?)) '()]
                                [#:argv argv (vectorof (and/c string? immutable?)) (current-command-line-arguments)]
                                [#:program program string? "<prog>"]
                                [#:usage-help usage (listof string?) '()]
                                [trailing-arg-name string?] ...)
         any]{
 Produces a command line parser via @racket[parse-command-line]
 for all the global variables @racket[globals].

 See @racket[parse-command-line] for general information.
 Each list of globals within @racket[mutex-groups] are placed in a separate @racketid[once-any] group in
@racket[parse-command-line].
Multi flags are not supported by globals.

 See @racket[global->cmd-line-rule] for some of the keywords and for more information about boolean flags.

See also the note in @racket[(get-globals)].
}

@defproc[(global->cmd-line-rule [g global?]
                                [#:name->string name->string default-name->string]
                                [#:boolean-valid? bool? boolean?]
                                [#:boolean-no-prefix no-prefix "--no-~a"])
         list?]{
Returns a rule for @racket[parse-command-line]. Used by @racket[globals->command-line].

 Booleans are treated specially on the command line, as they don't require arguments.
If the validation of @racket[g] is @racket[equal?] to @racket[bool?] then
the returned rule corresponds to a boolean flag that inverts the @emph{current} value of @racket[g].
For example,
if @racket[bool?] is @racket[boolean?],
then, for
 @racketblock[(define-global:boolean *abool* #t "a boolean")]
 the call
 @racket[(global->cmd-line-rule *abool*)]
 (only) produces a rule with the flag @racket["--no-abool"] which sets @racket[*abool*] to @racket[#f]
 if present on the command line, while for
 @racketblock[(define-global:boolean *abool* #f "a boolean")]
it (only) produces the flag @racket["--abool"] which sets @racket[*abool*] to @racket[#t].
The additional flags set in @racket[more-commands] always @emph{invert} the default value of the
global.
Setting @racket[bool?] to @racket[#f] treats boolean globals as normal flags that take
one argument.
By default, @racket[name->string] removes some leading and trailing special characters.
}

@section{Text interaction}

@defproc[(globals-interact [globals (listof global?) (get-globals)]) void?]{
Produces a command-line interaction with the user to read and write values of @racket[globals].}

