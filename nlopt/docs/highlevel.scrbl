#lang scribble/manual

@(require (for-label racket math/flonum racket/flonum nlopt/highlevel))

@title[#:tag "highlevel"]{High Level Interface}

@(defmodule nlopt/highlevel)

@margin-note{This is the most unstable part of the package.
 Not only will things here change, they might not even
 work right now.}

@deftogether[(@defproc[(minimize/flvector ...) ...]
               @defproc[(maximize/flvector ...) ...]
               @defproc[(optimize/flvector [fun (-> flvector? any/c flonum?)]
                                           [x0 flvector?]
                                           [#:maximize maximize boolean?]
                                           [#:minimize minimize boolean?]
                                           [#:method method (or/c symbol? #f)]
                                           [#:jac jac (or/c (-> flonum? flvector? flvector? any/c) #f)]
                                           [#:bounds bounds (or/c (sequence/c (pair/c real? real?)) #f)]
                                           [#:ineq-constraints ineq-constraints
                                            (or/c #f
                                                  (sequence/c
                                                   (or/c (-> flvector? any/c flonum?)
                                                         (cons/c
                                                          (-> flvector? any/c flonum?)
                                                          (-> flonum? flvector? flvector? any/c)))))]
                                           [#:eq-constraints eq-constraints
                                            (or/c #f
                                                  (sequence/c
                                                   (or/c (-> flvector? any/c flonum?)
                                                         (cons/c
                                                          (-> flvector? any/c flonum?)
                                                          (-> flonum? flvector? flvector? any/c)))))]
                                           [#:tolerance tolerance real?]
                                           [#:epsilon epsilon real?]
                                           [#:maxeval maxeval natural-number/c]
                                           [#:maxtime maxtime (and/c positive? real?)])
                        (values real? flvector?)])]{
 These super convenient procedure does pretty much everything for you.
 @racket[minimize/flvector] and @racket[maximize/flvector] behave the
 same as @racket[optimize/flvector], and take all the same arguments,
 except for @racket[#:minimize] and @racket[#:maximize].

 These @tt{/flvector} variants require @racket[flonum?] values. (Which
 is largely enforced by the @racket[flvector]s themselves.) @tt{/flvector}
 objective functions should be of the form @racket[(fun x)] where
 @racket[x] is an @racket[flvector?] and the Jacobians should be
 of the form @racket[(jac y x grad)] where @racket[y] is @racket[(fun x)],
 and @racket[grad] is an @racket[flvector?] to be populated with the
 gradient.

 @racket[fun] is the procedure that will be optimized. It shouldn't be
 invoked significantly more than @racket[maxeval] times, over
 @racket[maxtime] seconds. @racket[x0]
 is your initial guess for the optimization; some algorithms are more
 sensitive to the quality of your initial guess than others. @racket[data]
 will be passed to every invocation of @racket[fun] or @racket[jac].
 You may use @racket[force-stop] inside of @racket[fun].

 @racket[#:maximize] and @racket[#:minimize] determine whether a
 maximization, or minimzation will be performed. Exactly one of them
 must be @racket[#t]. Anything else will result in an exception being
 raised.

 @racket[method] is a symbol indicating which optimization algorithm
 to run. See the Algorithms section for your options. If you omit it,
 or set it to @racket[#f], an algorithm will be chosen automatically
 based on @racket[jac], @racket[bounds], @racket[ineq-constraints]
 and @racket[eq-constraints]. It should run without error; performance
 is not guaranteed.

 @racket[jac] is the Jacobian of @racket[fun]. If you omit it, or supply
 @racket[#f] then a very simple approximation will be constructed, by
 determining how much @racket[fun] varies when the current @racket[x] is
 varied by @racket[epsilon]. If you provide a Jacobian, or it is not used
 by the algorithm you select, then @racket[epsilon] is unused.

 @racket[bounds] may be @racket[#f] in which case no upper or lower bounds
 are applied. If it isn't @racket[#f] then it should be a sequence of the
 same length as @racket[x0], each element in the sequence should be a pair.
 The @racket[car] of each pair will be the lower bound, and the @racket[cdr]
 the upper bound. You may supply @racket[+max.0] and @racket[-max.0] if
 you don't wish to bound a dimension above or below, respectively.

 @racket[ineq-constraints] and @racket[eq-constraints] are sequences
 of constraint functions (or @racket[#f]). They must have the same
 interface as an objective function. An inequality constraint @racket[f]
 will constrain the optimization so that @racket[(<= (f x _) 0.0)] is
 @racket[#t]. An equality constraint requires that @racket[(= (f x _) 0.0)]
 remain @racket[#t]. You may provide just the constraint function itself,
 or a pair, containing the constraint function in @racket[car], and
 the Jacobian of the constraint function in @racket[cdr].

 @racket[tolerance] is not currently used. Sorry!
  
 This procedure's interface was based on scipy's optimize function.
}

@deftogether[(@defproc[(minimize/f64vector ...) ...]
               @defproc[(maximize/f64vector ...) ...]
               @defproc[(optimize/f64vector ...) ...])]{
 Takes different arguments. Needs docs.
  
 The @tt{/f64vector} variants should perform about as
 well as the @tt{/flvector} variants. They accept any
 @racket[real?] values. @tt{/flvector}
 objective functions should be of the form @racket[(fun x)] where
 @racket[x] is an @racket[f64vector?] and the Jacobians should be
 of the form @racket[(jac y x grad)] where @racket[y] is @racket[(fun x)],
 and @racket[grad] is an @racket[f64vector?] to be populated with the
 gradient.
}

@deftogether[(@defproc[(minimize/vector ...) ...]
               @defproc[(maximize/vector ...) ...]
               @defproc[(optimize/vector ...) ...])]{
 Takes different arguments. Needs docs.
  
 The @tt{/vector} variants will be less efficient
 than the @tt{/flvector} variants. They accept any
 @racket[real?] values. @tt{/vector}
 objective functions should be of the form @racket[(fun x)] where
 @racket[x] is a @racket[vector?] and the Jacobians should be
 of the form @racket[(jac y x grad)] where @racket[y] is @racket[(fun x)],
 and @racket[grad] is a @racket[vector?] to be populated with the
 gradient.
}

@deftogether[(@defproc[(minimize/list ...) ...]
               @defproc[(maximize/list ...) ...]
               @defproc[(optimize/list ...) ...])]{
 Takes different arguments. Needs docs.
  
 The @tt{/list} variants will be the slowest. Like
 @tt{/vector} variants, will handle any @racket[real?]
 values.  @tt{/list}
 objective functions should be of the form @racket[(fun x)] where
 @racket[x] is a @racket[list?] and the Jacobians should be
 of the form @racket[(jac y x)] where @racket[y] is @racket[(fun x)].
 They should return the gradient as a @racket[list?].
}

@deftogether[(@defproc[(minimize/args ...) ...]
               @defproc[(maximize/args ...) ...]
               @defproc[(optimize/args
                         [fun (-> flonum? ... any/c flonum?)]
                         [x0 (sequence/c flonum?)]
                         [#:maximize maximize boolean?]
                         [#:minimize minimize boolean?]
                         [#:method method (or/c symbol? #f)]
                         [#:jac jac (or/c (-> flonum? flvector? flvector? any/c) #f)]
                         [#:bounds bounds (or/c (sequence/c (pair/c real? real?)) #f)]
                         [#:ineq-constraints ineq-constraints
                          (or/c #f
                                (sequence/c
                                 (or/c (-> flvector? any/c flonum?)
                                       (cons/c
                                        (-> flvector? any/c flonum?)
                                        (-> flonum? flvector? flvector? any/c)))))]
                         [#:eq-constraints eq-constraints
                          (or/c #f
                                (sequence/c
                                 (or/c (-> flvector? any/c flonum?)
                                       (cons/c
                                        (-> flvector? any/c flonum?)
                                        (-> flonum? flvector? flvector? any/c)))))]
                         [#:tolerance tolerance real?]
                         [#:epsilon epsilon real?]
                         [#:maxeval maxeval natural-number/c]
                         [#:maxtime maxtime (and/c positive? real?)])
                        (values real? flvector?)])]{
 @;@deftogether[(@defproc[(minimize/args ...) ...]
 @;              @defproc[(maximize/args ...) ...]
 @;              @defproc[(optimize/args ...) ...])]{
 Takes different arguments. Needs docs.
  
 The @tt{/args} variants will be among the slowest. Like
 @tt{/vector} and @tt{/list} variants, will handle any @racket[real?]
 values. @tt{/args} objective functions should be of the form
 @racket[(fun x ...)] where @racket[x ...] are the elements of the
 @racket[x] vector and the Jacobians should be of the form
 @racket[(jac x ...)]. They should return the gradient as a
 @racket[list?]. Note @tt{/args} Jacobian functions do not receive the the
 precomputed @racket[y]. This allows you to quickly set up an
 optimization problem using existing mathematical functions:

 @racketblock{
  (maximize/args sin
  '(0.0)
  #:jac cos
  #:bounds '((-inf.0 0.0)))
 }
}
