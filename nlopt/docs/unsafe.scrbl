#lang scribble/manual

@(require (for-label ffi/unsafe))
@(require (for-label ffi/vector))

@title[#:tag "unsafe"]{Unsafe Interface}

@defmodule[nlopt/unsafe]

This module is the unsafe, contractless version of the interface
to the C library. For the safe, fully-contracted version, see
@racket[nlopt/safe].

The one bit of safety provided by this module is that @code{nlopt_opt}
structures will be cleaned up properly, and Racket values passed to
NLopt procedures will be held onto until NLopt no longer refers to
them.

The API of this module is probably the most stable thing in the whole
package, as it is a direct mapping of the C API.

@margin-note{Failure to obey any of the requirements mentioned below
will probably cause Racket to crash.}

@section{Differences in the Basics}

@defproc[(optimize [opt nlopt-opt?]
                   [x cpointer?])
         (values [res symbol?]
                 [f flonum?])]{
  As with the safe version of @racket[optimize], but @racket[x] is
  provided as a bare pointer. It must point to a block of memory
  containing @racket[(get-dimension opt)] double-precision floats.
}

@defproc[(set-min-objective [opt nlopt-opt?]
                            [f (-> natural-number/c
                                   cpointer?
                                   (or/c cpointer? #f)
                                   any/c
                                   flonum?)]
                            [data any/c])
         symbol?]{
  As with the safe version of @racket[set-min-objective],                                                                               but the objective function @racket[f] receives only bare pointers instead
  of @racket[flvector]s.
  }

@defproc[(set-max-objective [opt nlopt-opt?]
                            [f (-> natural-number/c
                                   cpointer?
                                   (or/c cpointer? #f)
                                   any/c
                                   flonum?)]
                            [data any/c])
         symbol?]{
  As with the safe version of @racket[set-max-objective],                                                                               but the objective function @racket[f] receives only bare pointers instead
  of @racket[flvector]s.
  }

@section{Differences in the Constraints}

@defproc[(set-lower-bounds [opt nlopt-opt?] [bounds cpointer?])
         symbol?]{
  As with the safe version of @racket[set-lower-bounds], but
  @racket[bounds] is provided as a bare pointer. It must point
  to a block of memory containing @racket[(get-dimension opt)]
  double-precision floats.
  }
  
@defproc[(set-upper-bounds [opt nlopt-opt?] [bounds cpointer?])
         symbol?]{
  As with the safe version of @racket[set-upper-bounds], but
  @racket[bounds] is provided as a bare pointer. It must point
  to a block of memory containing @racket[(get-dimension opt)]
  double-precision floats.
  }

@defproc[(get-lower-bounds [opt nlopt-opt?] [bounds cpointer?])
         symbol?]{
  As with the safe version of @racket[get-lower-bounds], but
  @racket[bounds] is provided as a bare pointer. It must point
  to a block of memory large enough to contain @racket[(get-dimension opt)]
  double-precision floats.
  }
  
@defproc[(get-upper-bounds [opt nlopt-opt?] [bounds cpointer?])
         symbol?]{
  As with the safe version of @racket[get-upper-bounds], but
  @racket[bounds] is provided as a bare pointer. It must point
  to a block of memory large enough to contain @racket[(get-dimension opt)]
  double-precision floats.
  }

@defproc[(add-inequality-constraint [opt nlopt-opt?]
                                    [f (-> nlopt-opt?
                                           cpointer?
                                           (or/c cpointer? #f)
                                           any/c
                                           flonum?)]
                                    [data any/c]
                                    [tolerance real?])
         symbol?]{
  As with the safe version of @racket[add-inequality-constraint],
  but the constraint function receives only bare pointers instead
  of @racket[flvector]s.
}

@defproc[(add-equality-constraint [opt nlopt-opt?]
                                  [f (-> nlopt-opt?
                                         cpointer?
                                         (or/c cpointer? #f)
                                         any/c
                                         flonum?)]
                                  [data any/c]
                                  [tolerance real?])
         symbol?]{
  As with the safe version of @racket[add-inequality-constraint],
  but the constraint function receives only bare pointers instead
  of @racket[flvector]s.
}

@section{Differences in the Stopping Criteria}

@defproc[(set-xtol-abs [opt nlopt-opt?]
                       [xtols cpointer?])
         symbol?]{
  As with the safe version of @racket[set-xtol-abs], but
  @racket[xtols] is provided as a bare pointer. It must point
  to a block of memory containing @racket[(get-dimension opt)]
  double-precision floats.
}

@defproc[(get-xtol-abs [opt nlopt-opt?]
                       [bounds cpointer?])
         symbol?]{
  As with the safe version of @racket[set-xtol-abs], but
  @racket[xtols] is provided as a bare pointer. It must point
  to a block of memory large enough to contain @racket[(get-dimension opt)]
  double-precision floats.
}

@section{Differences in the Algorithm-Specific Parameters}

@defproc[(set-default-initial-step [opt nlopt-opt?]
                                   [stepsizes cpointer?])
         symbol?]{
  As with the safe version of @racket[set-default-initial-step], but
  @racket[stepsizes] is provided as a bare pointer. It must point
  to a block of memory containing @racket[(get-dimension opt)]
  double-precision floats.
}

@defproc[(set-initial-step [opt nlopt-opt?]
                           [stepsizes cpointer?])
         symbol?]{
  As with the safe version of @racket[set-initial-step], but
  @racket[stepsizes] is provided as a bare pointer. It must point
  to a block of memory containing @racket[(get-dimension opt)]
  double-precision floats.
}

@defproc[(get-initial-step [opt nlopt-opt?]
                           [stepsizes cpointer?])
         symbol?]{
  As with the safe version of @racket[get-initial-step], but
  @racket[stepsizes] is provided as a bare pointer. It must point
  to a block of memory large enough to contain @racket[(get-dimension opt)]
  double-precision floats.
}
