#lang racket

(require nlopt/safe)
(require racket/flonum)
(require ffi/unsafe)

(module+ test
  (require rackunit))

;;
;; safe-example.rkt - A re-implementation of the NLopt example
;; from https://nlopt.readthedocs.io/en/latest/NLopt_Tutorial/
;; using the nlopt/safe API
;;
;; Take 2: Some Niceties
;; - Use indirection to support Racket native constraint data


;;
;; The following code solves a nonlinearly-constrained minimization problem:
;; let f(x0,x1) = (sqrt x1)
;; find the pair x0,x1 that (approximately) minimize f
;; over the region
;; x1 >= (-x0 + 1)^3;
;; x1 >= (2*x0 + 0)^3;
;; 

(define DIMENSIONS 2) 

;; (-> flvector? (or/c flvector? #f) any/c flonum?)
;; the function to be minimized, PLUS its gradient, using nlopt/safe API
;; only compute the gradient when grad is not #f
(define (myfunc x grad data)
  ;; x is a cpointer to an array of n doubles. 
  (define x0 (flvector-ref x 0))
  (define x1 (flvector-ref x 1))
  (collect-garbage 'major)
  (when grad
    (flvector-set! grad 0 0.0)
    (flvector-set! grad 1 (/ 0.5 (sqrt x1))))
  (sqrt x1))


;; CBOX: Indirection to a Racket object for safely passing to C
(define-cpointer-type _cbox)
(define (cbox s)
  (define ptr (malloc _racket 'interior))
  (set-cpointer-tag! ptr _cbox)
  (ptr-set! ptr _racket s)
  ptr)

(define (cunbox cb)
  (unless (cpointer-has-tag? cb _cbox)
    (error 'constraint-data-a "Invalid cbox: ~a" (cpointer-tag cb)))
  (ptr-ref cb _racket))


;; constraint data
(define-struct constraint-data (a b))

;; (-> flvector? (or/c flvector? #f) any/c flonum?)
;; parametric constraint function
(define (myconstraint x grad data)
  ;; expect: n = 2
  ;; expect: x is a cpointer to 2 doubles.

  ;; Manipulate x using Racket's unsafe interface
  (define x0 (flvector-ref x 0))
  (define x1 (flvector-ref x 1))
  ;; data had better be a cboxed constraint-data object
  ;; FFI doesn't preserve tag, so unsafely force it ( :( )
  (set-cpointer-tag! data _cbox)
  (define cd (cunbox data))
  (define a (constraint-data-a cd))
  (define b (constraint-data-b cd))
  ;(printf "(~a,~a) constraint\n" a b)

  ;; Compute gradient of constraint function, if needed
  (when grad
    (flvector-set! grad
                   0
                   (* 3 a (expt (+ (* a x0) b) 2)))
    (flvector-set! grad
                   1
                   0.0))
  (- (expt (+ (* a x0) b) 3) x1))



;; nlopt_create
(define opt (create 'LD_MMA DIMENSIONS))

;; set-lower-bounds
;; Here it is safe to use a cpointer to flvector data because:
;; 1) set-lower-bounds does not call back into Racket, so GC will not
;;    happen during the dynamic extent of the call;
;; 2) set-lower-bounds does not hold onto the pointer that is passed to it;
;;    rather, it copies the numeric values to its own managed memory.  This
;;    means that the C library is unaffected if lower-bounds is copied or
;;    collected after set-lower-bounds returns.
(define lower-bounds (flvector -inf.0 0.0))
(set-lower-bounds opt lower-bounds)

;; set-min-objective objective
(set-min-objective opt myfunc #f) 

;; add-inequality-constraint x 2
(define cbdata1 (cbox (make-constraint-data 2.0 0.0)))
(define cbdata2 (cbox (make-constraint-data -1.0 1.0)))

(add-inequality-constraint opt myconstraint cbdata1 1e-8) 
(add-inequality-constraint opt myconstraint cbdata2 1e-8) 

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

(define x (flvector 1.234 5.678))
;(define x (malloc _double DIMENSIONS 'atomic-interior))
;(ptr-set! x _double 0 1.234)
;(ptr-set! x _double 1 5.678)

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
        (real->decimal-string (flvector-ref x 0) 3)
        (real->decimal-string (flvector-ref x 1) 3)
        (real->decimal-string minf 3))


(module+ test
  (check-= (flvector-ref x 0) 1/3 1e-2)
  (check-= (flvector-ref x 1) 8/27 1e-2)
  (check-= minf (sqrt 8/27) 1e-2))

