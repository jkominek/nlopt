#lang racket

(require nlopt/unsafe)
(require racket/flonum)
(require ffi/unsafe)


(module+ test
  (require rackunit))

;;
;; unsafe-example1.rkt - A re-implementation of the NLopt example
;; from https://nlopt.readthedocs.io/en/latest/NLopt_Tutorial/
;; using the nlopt/unsafe API
;;


;;
;; The following code solves a nonlinearly-constrained minimization problem:
;; let f(x0,x1) = (sqrt x1)
;; find the pair x0,x1 that (approximately) minimize f
;; over the region
;; x1 >= (-x0 + 1)^3;
;; x1 >= (2*x0 + 0)^3;
;; 

(define DIMENSIONS 2)

;; (-> natural-number/c cpointer? (or/c cpointer? #f) (or/c cpointer? #f) flonum?)
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


;; constraint data: analogous to
;;(define-struct constraint-data (a b))
;; but structured, by hand, for safe interaction with C.
;; I suspect Racket provides pre-packaged mechanisms for this.

;; double double -> constraint
(define-cpointer-type _constraint_data)
(define (make-constraint-data a b)
  (define ptr (malloc _double 2 'atomic-interior))
  (set-cpointer-tag! ptr _constraint_data)
  (ptr-set! ptr _double 0 a)
  (ptr-set! ptr _double 1 b)
  ptr)

(define (constraint-data-a cd)
  (unless (cpointer-has-tag? cd _constraint_data)
    (error 'constraint-data-a "Invalid constraint data: ~a" (cpointer-tag cd)))
  (ptr-ref cd _double 0))

(define (constraint-data-b cd)
  (unless (cpointer-has-tag? cd _constraint_data)
    (error 'constraint-data-a "Invalid constraint data: ~a" (cpointer-tag cd)))
  (ptr-ref cd _double 1))

;; (-> natural-number/c cpointer? (or/c cpointer? #f) cpointer? flonum?)
;; parametric constraint function
(define (myconstraint n x grad data)
  ;; expect: n = DIMENSION
  ;; expect: x is a cpointer to n doubles
  ;; Manipulate x using Racket's unsafe interface
  (define x0 (ptr-ref x _double 0))
  (define x1 (ptr-ref x _double 1))

  ;; data had better be a constraint-data object.
  ;; FFI doesn't preserve tag, so unsafely force it ( :( )
  (set-cpointer-tag! data _constraint_data)
  (define a (constraint-data-a data))
  (define b (constraint-data-b data))

  ;; If the optimization algorithm needs a gradient, compute and provide one
  (when grad
    (ptr-set! grad
              _double
              0
              (* 3 a (expt (+ (* a x0) b) 2)))
    (ptr-set! grad
              _double
              1
              0.0))
  (- (expt (+ (* a x0) b) 3) x1))


;; nlopt_create
;; LD_MMA refers to the:
;; - Local (vs, Global),
;; - graDient-exploiting  (versus No gradient),
;; - MMA algorithm (see NLopt documentation for details and other algorithms)
(define opt (create 'LD_MMA DIMENSIONS))

;; set lower bounds on the search space.
;; Here it is safe to use a cpointer to an flvector because:
;; 1) set-lower-bounds does not call back into Racket, so GC will not
;;    happen during the dynamic extent of the call;
;; 2) set-lower-bounds does not hold onto the pointer that is passed to it;
;;    rather, it copies the numeric values to its own managed memory.  This
;;    means that the C library is unaffected if lower-bounds is copied or
;;    collected after set-lower-bounds returns.
(define lower-bounds (flvector -inf.0 0.0))
(set-lower-bounds opt (flvector->cpointer lower-bounds))

;; set-min-objective objective
(set-min-objective opt myfunc #f) 

;; add-inequality-constraint x 2
(define data1 (make-constraint-data 2.0 0.0))
(define data2 (make-constraint-data -1.0 1.0))

(add-inequality-constraint opt myconstraint  data1 1e-8)
(add-inequality-constraint opt myconstraint  data2 1e-8)

;; nlopt-set-xtol-rel
(set-xtol-rel opt 1e-4)

;; starting search position
;; "atomic" means the array holds no GC-moveable pointers (optional)
;; "interior" means that GC will not move the resulting memory.
;; This is necessary since NLopt calls back into Racket,
;; which could trigger garbage collection,
;; which without "interior" could move the array in memory,
;; which would leave NLopt holding a dangling pointer,
;; which would be bad.
(define x (malloc _double DIMENSIONS 'atomic-interior))
(ptr-set! x _double 0 1.234)
(ptr-set! x _double 1 5.678)

;; Perform the optimization:
;; on success, x holds the optimal position
;; result holds the value at optimal x
(define-values (result minf) (optimize opt x))

;; Check Results
(define HARD-FAILURE '(FAILURE INVALID_ARGS OUT_OF_MEMORY))

(when (member result HARD-FAILURE)
  (error "nlopt failed: ~a\n" result))

;; "roundoff limited" is a soft failure: the results may still be usable.
(when (equal? result 'ROUNDOFF_LIMITED)
  (printf "warning: roundoff limited!\n"))

(printf "found minimum at f(~a,~a) = ~a\n"
        (real->decimal-string (ptr-ref x _double 0) 3)
        (real->decimal-string (ptr-ref x _double 1) 3)
        (real->decimal-string minf 3))


(module+ test
  (check-= (ptr-ref x _double 0) 1/3 1e-2)
  (check-= (ptr-ref x _double 1) 8/27 1e-2)
  (check-= minf (sqrt 8/27) 1e-2))
