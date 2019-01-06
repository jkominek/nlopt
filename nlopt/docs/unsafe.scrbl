#lang scribble/manual

@(require (for-label (except-in racket version)
                     (only-in ffi/unsafe cpointer? ptr-set! ptr-ref malloc
                              _double)
                     ffi/vector racket/flonum nlopt/unsafe))

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

@section{Quickstart Example}

To demonstrate the unsafe interface, the following code reconstructs the
NLOpt tutorial @url["https://nlopt.readthedocs.io/en/latest/NLopt_Tutorial/"]
in terms of it.  To understand the following, it is recommended that you
familiarize yourself with the problem description and analogous code for the
high-level nlopt interface.

In order to properly work with the unsafe interface, we require features of
Racket's unsafe FFI library.  At times we will also exploit @racket[flonum?]
and @racket[flvector]s, which are vectors of @racket[flonum?] objects that
have the same memory layout as arrays of double from C.

@racketblock[
(require nlopt/unsafe)
(require racket/flonum)
(require ffi/unsafe)
]

The unsafe interface must often keep track of the dimensions of the
target function's search space.

@racketblock[
(define DIMENSIONS 2)
]

To emphasize the low-level nature of the unsafe interface, the unsafe
implementation mirrors the implementation that can be found in the NLOpt
tutorial.  If you are familiar with C, you might with to compare this
Racket code to that C code.

@racketblock[
;; (-> natural-number/c cpointer? cpointer? cpointer? flonum?)
;; the function to be minimized, PLUS its gradient, using nlopt/unsafe API
;; only compute the gradient when grad is not #f
(define (myfunc n x grad data)
  ;(collect-garbage 'major) ;; stress-test for memory-safety
  ;; x is a cpointer to an array of n doubles. 
  (define x0 (ptr-ref x _double 0))
  (define x1 (ptr-ref x _double 1))
  (when grad
    (ptr-set! grad _double 0 0.0)
    (ptr-set! grad _double 1 (/ 0.5 (sqrt x1))))
  (sqrt x1))
]

This function uses Racket's unsafe memory operations @racket[ptr-ref] and
@racket[ptr-set!] to manipulate arrays of double values.  Racket's FFI
translates null C pointers to @racket[#f], so a simple Boolean
check on @racket[grad] is used to determine whether NLopt needs the function
to compute its gradient.

Following the NLOpt tutorial, we use the NLOpt's client data mechanism to
register different values for @racket[a] and @racket[b] to be used in two
separate constraints.  Note that this approach is not recommended:  client
data is used in C to simulate closures, but Racket's FFI supports passing
closures to C as callbacks (see the highlevel API's quick-start example).
We use client data here simply to illustrate what is possible, not what is
recommended.

Since NLOpt retains pointers to client data, we use Racket's custom memory
allocation to construct objects to create two-element arrays that the
garbage collector guarantees not to move (i.e., @italic{interior} memory),
and are known not to contain pointers (i.e., @italic{atomic} memory).
See the @racket[malloc] documentation for details.

Later, we show how to pass a Racket struct through this interface, using
one layer of indirection.
@racketblock[

;; double double -> constraint
(define (make-constraint-data a b)
  (define ptr (malloc _double 2 'atomic-interior))
  (ptr-set! ptr _double 0 a)
  (ptr-set! ptr _double 1 b)
  ptr)

(define (constraint-data-a cd)
  (ptr-ref cd _double 0))

(define (constraint-data-b cd)
  (ptr-ref cd _double 1))
]

The @racket[myconstraint] function implements a family of inequality
constraints, parameterized on values @racket[a] and @racket[b], which
are retrieved from client-data.

@racketblock[
(define (myconstraint n x grad data)

  (define x0 (ptr-ref x _double 0))
  (define x1 (ptr-ref x _double 1))

  (define a (constraint-data-a data))
  (define b (constraint-data-b data))

  (when grad
    (ptr-set! grad _double 0
              (* 3 a (expt (+ (* a x0) b) 2)))
    (ptr-set! grad _double 1 0.0))
  (- (expt (+ (* a x0) b) 3) x1))
]

To prepare for optimization, we create an optimization options object that
commits to its algorithm---a Local, graDient-exploiting variant of MMA
(see NLopt documentation for details and other algorithms).

@racketblock[
(define opt (create 'LD_MMA DIMENSIONS))
]

Next, we set lower bounds on the search space.

Here it is safe to use a cpointer to an @racket[flvector] because:
@itemize[
 @item{@racket[set-lower-bounds] does not call back into Racket, so
  garbage collection will not happen during the dynamic extent of the call;}
 @item{@racket[set-lower-bounds] does not hold onto the pointer that is passed
  to it; rather, it copies the numeric values to its own managed memory.  This
  means that the C library is unaffected if lower-bounds is copied or collected
  after set-lower-bounds returns.}
 ]
  
@racketblock[
(define lower-bounds (flvector -inf.0 0.0))
(set-lower-bounds opt (flvector->cpointer lower-bounds))
]

Next, we configure the optimization to minimize the @racket[myfunc] function.
Client data is initialized to #f (equivalent to a null pointer in C), since
@racket[myfunc] uses no client data.

@racketblock[
;; set-min-objective objective
(set-min-objective opt myfunc #f) 
]

We configure two constraints using a combination of the @racket[myconstraint]
function and distinct client data for each constraint.

@racketblock[
(define data1 (make-constraint-data 2.0 0.0))
(define data2 (make-constraint-data -1.0 1.0))

(add-inequality-constraint opt myconstraint  data1 1e-8)
(add-inequality-constraint opt myconstraint  data2 1e-8)
]

NLOpt needs at least one stopping criterium to ensure that optimization
terminates.  Here we set a lower-bound on the the relative change of @racket[x]
during search.  See the documentation for alternative termination criteria.

@racketblock[
;; nlopt-set-xtol-rel
(set-xtol-rel opt 1e-4)
]

Finally, we allocate an interior array that is set to an initial search point,
and that NLOpt will modify to hold the final search value.

@racketblock[
(define x (malloc _double DIMENSIONS 'atomic-interior))
(ptr-set! x _double 0 1.234)
(ptr-set! x _double 1 5.678)
]

With all settings in place, we initiate the optimization.

@racketblock[
;; Perform the optimization:
;; on success, x holds the optimal position
;; result holds the value at optimal x
(define-values (result minf) (optimize opt x))
]

@racket[optimize] returns three values.  @racket[result] is a status flag,
@racket[minf] is the minimum value found during search, and @racket[x] has
been modified to hold the point at which the function produced @racket[minf].

We can interrogate the status flag and possibly report errors.

@racketblock[
;; Check Results
(define HARD-FAILURE '(FAILURE INVALID_ARGS OUT_OF_MEMORY))

(when (member result HARD-FAILURE)
  (error "nlopt failed: ~a\n" result))
]

According to the NLOpt documentation, the result of optimization may still
be useful even if the optimization procedure resorted to rounding, but it is
good practice to report that this happened.

@racketblock[
;; "roundoff limited" is a soft failure: the results may still be usable.
(when (equal? result 'ROUNDOFF_LIMITED)
  (printf "warning: roundoff limited!\n"))
]

Finally, if optimization was successful (which it should be in this example),
we can inspect and manipulate the results.

@racketblock[
(printf "found minimum at f(~a,~a) = ~a\n"
        (real->decimal-string (ptr-ref x _double 0) 3)
        (real->decimal-string (ptr-ref x _double 1) 3)
        (real->decimal-string minf 3))
]

@subsection{Passing Racket Structured Data Directly}

Though closures are preferred for passing client data to NLOpt, one may wish to
directly pass structured client data.  This can be done using an extra layer of
indirection.  The following code, without commentary, shows what changes
to the above code that supports creating a safe block of memory that points to
a traditional Racket struct to support the retrieval of client data.
Note that this code only works for versions of Racket after Version 7.1 due to
a since-fixed bug in the memory allocator.

@racketblock[
(define (cbox s)
  (define ptr (malloc _racket 'atomic-interior))
  (ptr-set! ptr _racket s)
  ptr)
 
(define (cunbox cb)
  (ptr-ref cb _racket))

(define-struct constraint-data (a b))

(define (myconstraint n x grad data)

  (define x0 (ptr-ref x _double 0))
  (define x1 (ptr-ref x _double 1))

  (define cd (cunbox data))
  (define a (constraint-data-a cd))
  (define b (constraint-data-b cd))

  (when grad
    (ptr-set! grad _double 0
              (* 3 a (expt (+ (* a x0) b) 2)))
    (ptr-set! grad _double 1 0.0))
  (- (expt (+ (* a x0) b) 3) x1))
                        
(define cbdata1 (cbox (make-constraint-data 2.0 0.0)))
(define cbdata2 (cbox (make-constraint-data -1.0 1.0)))

(add-inequality-constraint opt myconstraint cbdata1 1e-8) 
(add-inequality-constraint opt myconstraint cbdata2 1e-8)                         
]
                      
@section{Differences in the Basics}

@defproc[(optimize [opt nlopt-opt?]
                   [x cpointer?])
         (values [res symbol?]
                 [f flonum?])]{
  As with the safe version of @racket[optimize], but @racket[x] is
  provided as a bare pointer. It must point to a block of memory
  containing @racket[(get-dimension opt)] double-precision floats.

  You should ensure that the @racket[x] pointer will not be moved over the
  course of execution. For short runs, or one-off hacky bits of code
  it probably doesn't matter. But if you start running long optimizations,
  sooner or later the garbage collector will move anything that can be
  moved. @racket[malloc] with a mode of @racket['atomic-interior] is
  suggested.
}

@defproc[(set-min-objective [opt nlopt-opt?]
                            [f (-> natural-number/c
                                   cpointer?
                                   (or/c cpointer? #f)
                                   cpointer?
                                   flonum?)]
                            [data any/c])
         symbol?]{
  As with the safe version of @racket[set-min-objective],
  but the objective function @racket[f] receives only bare pointers instead
  of @racket[flvector]s.
  }

@defproc[(set-max-objective [opt nlopt-opt?]
                            [f (-> natural-number/c
                                   cpointer?
                                   (or/c cpointer? #f)
                                   cpointer?
                                   flonum?)]
                            [data any/c])
         symbol?]{
  As with the safe version of @racket[set-max-objective],
  but the objective function @racket[f] receives only bare pointers instead
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
                                           cpointer?
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
                                         cpointer?
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
