#lang scribble/manual

@(require (for-label (except-in racket version)
                     nlopt/safe racket/flonum))

@title[#:tag "safe"]{Safe Interface}

@defmodule[nlopt/safe]

This module is the safe, fully-contracted version of the interface
to the C library. For the unsafe, contractless version, see
@racket[nlopt/unsafe].

@section{Basics}

@defproc[(create [algorithm symbol?]
                 [dimension (and/c natural-number/c positive?)])
         nlopt-opt?]{
  Creates a new NLopt options structure. The algorithm and dimension
  of the optimization problem cannot be changed later. Everything else
  can be.

  The general pattern for using this library is to @racket[create] an
  options structure, apply the various setup options to it (making sure
  to include a stopping condition!), and then run @racket[optimize].
                     }

@defproc[(copy [opt nlopt-opt?])
         nlopt-opt?]{
  Copies an existing options object. Racket objects stored as data
  arguments for functions are not copied.
                     }

@defproc[(get-algorithm [opt nlopt-opt?])
         symbol?]{
  Returns the algorithm being used by the options structure.
  }

@defproc[(get-dimension [opt nlopt-opt?])
         (and/c natural-number/c positive?)]{
  Returns the dimension the options structure is set up to handle.
  }

@defproc[(optimize [opt nlopt-opt?]
                   [x flvector?])
         (values [res symbol?]
                 [f flonum?])]{
  Runs the optimization problem, with an initial guess provided
  in @racket[x]. The status of the optimization is returned in
  @racket[res]. If it was successful, @racket[x] will contain the
  optimized values of the parameters, and @racket[f] will by the
  corresponding value of the objective function.

  @racket[x] must be at least as large as the dimension of @racket[opt].
                             }

@section{Constraints}

@section{Stopping Criteria}

@section{Algorithm-Specific Parameters}

