#lang scribble/manual

@(require (for-label racket math/flonum racket/flonum nlopt))

@title{NLopt}
@author[@author+email["Jay Kominek" "kominek@gmail.com"]]

@section-index["nlopt"]

@(defmodule nlopt)

@margin-note{I consider this package to be in a somewhat beta state.
             I don't yet promise to keep the API from changing. It
             needs some feedback yet. Feel free to comment on it.}

This package provides a wrapper for the NLopt nonlinear optimization
package@cite{NLopt}, which is a common interface for a number of
different optimization routines.

@section{High Level Interface}

@margin-note{This is the most unstable part of the package.
             Not only will things here change, they might not even
             work right now.}

@defproc[(optimize [fun procedure?]
                   [x0 flvector?]
                   [data any/c]
                   [#:maximize maximize boolean?]
                   [#:minimize minimize boolean?]
                   [#:method method (or/c symbol? #f)]
                   [#:jac jac (or/c procedure? #f)]
                   [#:bounds bounds (or/c (sequence/c (pair/c real? real?)) #f)]
                   [#:ineq-constraints ineq-constraints (or/c (sequence/c procedure?) #f)]
                   [#:eq-constraints eq-constraints (or/c (sequence/c procedure?) #f)]
                   [#:tolerance tolerance real?]
                   [#:epsilon epsilon real?]
                   [#:maxeval maxeval natural-number/c]
                   [#:maxtime maxtime (and/c positive? real?)]
                   )
         (values real?
                 flvector?)]{
  This super convenient procedure does pretty much everything for you.

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
  of constraint functions (or @racket[#f]). 

  @racket[tolerance]
  
  This procedure was based on scipy's optimize function.
  }

@defproc[(minimize ...) ...]{
  Completely identical to @racket[optimize], except it takes neither
  @racket[#:maximize] nor @racket[#:minimize]. Obviously, it performs
  a minimization.
  }

@defproc[(maximize ...) ...]{
  Completely identical to @racket[optimize], except it takes neither
  @racket[#:maximize] nor @racket[#:minimize]. Obviously, it performs
  a maximization.
  }

@include-section["safe.scrbl"]
@include-section["unsafe.scrbl"]
@include-section["algorithms.scrbl"]
