#lang scribble/manual

@(require (for-label racket math/flonum racket/flonum ffi/vector
                     nlopt/highlevel))

@title[#:tag "highlevel"]{High Level Interface}

@(defmodule nlopt/highlevel)

@margin-note{This is the most unstable part of the package.
 Not only will things here change, they might not even
 work right now.}


The highlevel package provides interfaces to NLopt functionality that are
more convenient and self-contained than the low-level C-like interfaces.
Variants are provided to cover a wide variety of styles that one might
use to represent n-ary functions and their corresponding gradient functions.

@itemize[@item{@racket[/flvector]: for mathematical functions that
          take and produce one n-element @racket[flvector];}
          @item{@racket[/f64vector]: corresponding versions for n-element
          @racket[f64vector]s;}
          @item{@racket[/vector]: corresponding versions for n-element
          @racket[vector]s;}
          @item{@racket[/list]: corresponding versions for n-element
          @racket[list]s;}
          @item{@racket[/arg]: operate seamlessly with n-argument Racket
                 functions, where the result is either a single number or a
                 n-element list of numbers.}]


@section{A Quick-start Example}

As a brief example of the high-level interface in action, we recreate the
example from the NLopt Tutorial
(@url["https://nlopt.readthedocs.io/en/latest/NLopt_Tutorial/"])
here.



Our goal is to solves the following nonlinearly-constrained minimization
problem:

consider the function:

f(x0,x1) = (sqrt x1)

find the pair x0,x1 that (approximately) minimizes f over the region

x1 >= (-x0 + 1)^3;

x1 >= (2*x0 + 0)^3;
 

First, define the target function.
@racketblock[
;; the core function
(define (fn x0 x1)
  (sqrt x1))
]

Next, render the inequality constraints.  NLopt represents
each constraint as a function C(x), which is interpreted as
imposing the inequality C(x) <= 0.  Since both constraints
have the parametric shape:

(a*x0 + b)^3

We represent them using one higher-order function that takes values for a,b and
produces the corresponding constraint function.
@racketblock[
;; parameterized inequality constraint function
;; nice when multiple inequalities have the same shape
;; (cn a b) yields a function C(x) which represents the inequality C(x) <= 0
(define ((cn a b) x0 x1)
  (- (expt (+ (* a x0) b) 3) x1))

(define ineq-constraints
  (list (cn 2.0 0.0) (cn -1.0 1.0)))
]

Set lower- and upper-bounds on the search space for x0 and x1. 
@racketblock[
;; (lower-bound . upper-bound) pairs for x0 and x1 
(define bounds '((-inf.0 . +inf.0) (0.0 . +inf.0)))
]

Choose a point in the space where search will begin
@racketblock[
;; starting point for search (within the intended bounds)
(define initial-x (list 1.234 5.678))
]

Finally we're ready:  run the search!

@racketblock[
;;
;; Simpler variation of the same problem:
;; */args can pick a default optimization method and can approximate gradients
(define-values (fn-x x)
  (minimize/args fn
                 initial-x
                 #:bounds bounds
                 #:ineq-constraints ineq-constraints))
]

The @racket[minimize/args] function returns two values: the minimal value
@racket[fn-x] and the point @racket[x] known to yield that value.

@racketblock[
;; helper for formatting decimal numbers
(define (digits n) (real->decimal-string n 3))
(printf "Result: x = ~a; f(x) = ~a.\n"
        (map digits x)
        (digits fn-x))
]

@subsection{Some extra options}

The example above is pretty minimal, but the high-level interface provides more
options to tailor the search.  For instance, the above code lets the interface
choose the optimization algorithm. Furthermore, the interface synthesizes its
own approximate gradient (a.k.a. Jacobian) functions for the target function and
the constraint functions.  We can supply our own more accurate
gradient functions, as well as select the algorithm and the optimization
direction.  The following additions execute that plan.


First, introduce gradient functions for both the target and constraint
functions.  The constraint gradient functions are parameterized, just like
the originals.

@racketblock[
;; the core gradient function 
(define (grad-fn x0 x1)
  (list 0.0 (/ 0.5 (sqrt x1))))

;; parameterized constraint gradient function 
(define ((grad-cn a b) x0 x1)
  (list (* 3 a (expt (+ (* a x0) b) 2))
        0.0))
]

Now supply constraint gradient functions alongside the constraint functions

@racketblock[
(define ineq-constraint-grads
  (list (cons (cn 2.0 0.0) (grad-cn 2.0 0.0))
        (cons (cn -1.0 1.0) (grad-cn -1.0 1.0))))
]

Finally, supply the @racket[#:minimize #t] option to the general
@racket[optimize/args] function to choose minimization, and provide the target
gradient function and constraint-gradient function pairs using keyword options.

@racketblock[
;; perform the optimization
(define-values (fn-x^ x^)
  (optimize/args fn
                 initial-x
                 #:minimize #t
                 #:jac grad-fn
                 #:method 'LD_MMA
                 #:bounds bounds
                 #:ineq-constraints ineq-constraint-grads))

(printf "Result: x = ~a; f(x) = ~a.\n"
        (map digits x^)
        (digits fn-x^))
]

@section{The Programming Interface}

@deftogether[
 (@defproc[(minimize/flvector ...) ...]
   @defproc[(maximize/flvector ...) ...]
   @defproc[(optimize/flvector
             [fun (-> flvector? any/c flonum?)]
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
 These super convenient procedures do pretty much everything for you.
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

 @racket[fun] is the procedure to be optimized. It shouldn't be
 invoked significantly more than @racket[maxeval] times, over
 @racket[maxtime] seconds. @racket[x0]
 is your initial guess for the optimization; some algorithms are more
 sensitive to the quality of your initial guess than others. @racket[data]
 is passed to every invocation of @racket[fun] or @racket[jac].
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

@deftogether[
 (@defproc[(minimize/args ...) ...]
   @defproc[(maximize/args ...) ...]
   @defproc[
 (optimize/args
  [fun (-> flonum? ...+ flonum?)]
  [x0 (sequence/c flonum?)]
  [#:maximize maximize boolean?]
  [#:minimize minimize boolean?]
  [#:method method (or/c symbol? #f)]
  [#:jac jac (or/c (-> flonum? ...+ (or/c flonum? (list/c flonum?))) #f)]
  [#:bounds bounds (or/c (sequence/c (pair/c real? real?)) #f)]
  [#:ineq-constraints ineq-constraints
   (or/c #f
         (sequence/c
          (or/c (-> flonum? ...+ flonum?)
                (cons/c
                 (-> flonum? ...+ flonum?)
                 (-> flonum? ...+
                     (or/c flonum? (list/c flonum?)))))))]
  [#:eq-constraints eq-constraints
   (or/c #f
         (sequence/c
          (or/c (-> flonum? ...+ flonum?)
                (cons/c
                 (-> flonum? ...+ flonum?)
                 (-> flonum? ...+
                     (or/c flonum? (list/c flonum?)))))))]
  [#:tolerance tolerance real?]
  [#:epsilon epsilon real?]
  [#:maxeval maxeval natural-number/c]
  [#:maxtime maxtime (and/c positive? real?)])
 (values flonum? flvector?)])]{
 The @tt{/args} variants are designed to operate on ordinary n-ary Racket
 functions.  The @tt{/args} variants are likely the slowest. Like
 @tt{/vector} and @tt{/list} variants, these will handle any @racket[real?]
 values. @tt{/args} objective functions should be of the form
 @racket[(fun xi ...)] where @racket[xi ...] are the elements of some
 @racket[x] vector, and the Jacobians should be of the form
 @racket[(jac xi ...)]. The Jacobian function should return the gradient as a
 @racket[list?] or optionally as a single @racket[flonum?] in the
 one-dimensional case. Unlike other variants, the @tt{/args} Jacobian functions
 do not receive as an argument the precomputed result @racket[y] of
 @racket[(fun xi ...)].  This allows you to quickly set up an optimization
 problem using existing mathematical functions, e.g.:

 @racketblock[
 (maximize/args sin
                '(0.0)
                #:jac cos
                #:bounds '((-inf.0 0.0)))
 ]
}
