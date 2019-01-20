#lang racket

(require nlopt/unsafe)
(require racket/flonum)
(require ffi/unsafe)


(module+ test
  (require rackunit))

;;
;; stress-test.rkt - A simple maximization example to stress the FFI a little
;;



(define DIMENSIONS 1) 

;; -(x - 5)^2 + 7:  has maximum value 7 at x=5
;; we'll consider the range x ∈ [2,8]
(define (quadratic x) (- 7 (expt (- x 5) 2)))

;; -2(x - 5)
(define (gradient x) = (* (- 2) (- x 5)))



;; (-> natural-number/c cpointer? (or/c cpointer? #f) cpointer? flonum?)
;; the function to be minimized, PLUS its gradient, using nlopt/unsafe API
;; only compute the gradient when grad is not #f
(define (myfunc n x grad data)
  ;; x is a cpointer to an array of n doubles. 
  (define x0 (ptr-ref x _double 0))
  #;(collect-garbage 'major) ;; stress-test memory-safety
  (when grad
    (ptr-set! grad _double 0 (gradient x0)))
  (quadratic x0))


;; keep the optimal value below this
(define (upper-bound x)
  (+ 2 (expt (- x 6) 2)))

(define (ub-grad x)
  (*  2 (- x 6)))

(define (myconstraint n x grad data)
  ;; x is a cpointer to an array of n doubles. 
  (define x0 (ptr-ref x _double 0))
  (ptr-set! data _int 0 (add1 (ptr-ref data _int 0)))
  #;(collect-garbage 'major) ;; stress-test memory-safety
  (when grad
    (ptr-set! grad _double 0 (- (gradient x0) (ub-grad x0))))
  (- (quadratic x0) (upper-bound x0)))

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
(define lower-bounds (flvector 2.0))
(set-lower-bounds opt (flvector->cpointer lower-bounds))

;; set-max-objective objective
(set-max-objective opt myfunc #f) 


;; add-inequality-constraint
#;(define data #f)

(define data (malloc _double 1 'atomic-interior))
(ptr-set! data _int 0 7)
(add-inequality-constraint opt myconstraint data 1e-8) 


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
(ptr-set! x _double 0 3.0)

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

(printf "found minimum at f(~a) = ~a\n"
        (real->decimal-string (ptr-ref x _double 0) 3)        
        (real->decimal-string minf 3))

;; Without the constraint
#;
(module+ test
  (check-= (ptr-ref x _double 0) 5 1e-2)
  (check-= minf 7 1e-2))

;; With the constraint

(module+ test
  (check-= (ptr-ref x _double 0) 4 1e-2)
  (check-= minf 6 1e-2))

;; to understand, plot the following

(module* plotty #f
  (require plot)
  (provide the-plot)
  (define the-plot
    (plot (list (function quadratic 2 8)
                (function gradient 2 8)
                (function upper-bound 2 8 #:color 'cyan)))))
