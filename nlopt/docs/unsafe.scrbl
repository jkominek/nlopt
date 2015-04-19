#lang scribble/manual

@(require (for-label ffi/unsafe))
@(require (for-label ffi/vector))

@title[#:tag "unsafe"]{Unsafe Interface}

@defmodule[nlopt/unsafe]

This module is the unsafe, contractless version of the interface
to the C library. For the safe, fully-contracted version, see
@racket[nlopt/safe].

@section{Basics}

@defproc[(optimize [opt nlopt-opt?]
                   [x cpointer?])
         (values [res symbol?]
                 [f real?])]{
  Runs the optimization problem, with an initial guess provided
  in @racket[x]. The status of the optimization is returned in
  @racket[res]. If it was successful, @racket[x] will contain the
  optimized values of the parameters, and @racket[f] will by the
  corresponding value of the objective function.

  @racket[x] must be at least as large as the dimension of @racket[opt].
                             }
