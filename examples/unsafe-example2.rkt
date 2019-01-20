#lang racket

(require nlopt/unsafe)
(require racket/flonum)
(require ffi/unsafe)

(module+ test
  (require rackunit))

;;
;; unsafe-example2.rkt - A re-implementation of the NLopt example
;; from https://nlopt.readthedocs.io/en/latest/NLopt_Tutorial/
;; using the nlopt/unsafe API
;;
;; Take 2: Some Niceties
;; - Use indirection to support Racket native constraint data;
;; - (due to a bug in Racket 7.1, it requires manual memory management
;;    until Racket 7.2 is released)


;;
;; The following code solves a nonlinearly-constrained minimization problem:
;; let f(x0,x1) = (sqrt x1)
;; find the pair x0,x1 that (approximately) minimize f
;; over the region
;; x1 >= (-x0 + 1)^3;
;; x1 >= (2*x0 + 0)^3;
;; 

(define DIMENSIONS 2) 

;; (-> natural-number/c cpointer? (or/c cpointer? #f) cpointer? flonum?)
;; the function to be minimized, PLUS its gradient, using nlopt/unsafe API
;; only compute the gradient when grad is not #f
(define (myfunc n x grad data)
  ;(collect-garbage 'major)
  ;; x is a cpointer to an array of n doubles. 
  (define x0 (ptr-ref x _double 0))
  (define x1 (ptr-ref x _double 1))
  (when grad
    (ptr-set! grad _double 0 0.0)
    (ptr-set! grad _double 1 (/ 0.5 (sqrt x1))))
  (sqrt x1))

;;
;; CBOX: Indirection to a Racket object for safe passage to C
;;
(define-cpointer-type _cbox)


;; Workaround variant cbox for Racket 7.1, using manual memory management
(define cboxes '())

(define (cbox-workaround s)  
  (define ptr (malloc-immobile-cell s))
  (set-cpointer-tag! ptr _cbox)
  (ptr-set! ptr _racket s)
  (set! cboxes (cons ptr cboxes))
 ptr)

(define (free-cboxes)
  (for ([cb cboxes])
    (free-immobile-cell cb))
  (define n (length cboxes))
  (set! cboxes '())
  n)
;; End Workaround

;; This (correct) version of cbox should work once Racket 7.2 is released
(define (cbox-7.2 s)  
  (define ptr (malloc _racket 'atomic-interior))
  (set-cpointer-tag! ptr _cbox)
  (ptr-set! ptr _racket s)
  ptr)

;; For now (under Racket 7.1) use the workaround
(define cbox cbox-workaround)


(define (cunbox cb)
  (unless (cpointer-has-tag? cb _cbox)
    (error 'constraint-data-a "Invalid cbox: ~a" (cpointer-tag cb)))
  (ptr-ref cb _racket))


;; constraint data
(define-struct constraint-data (a b))

;; (-> natural-number/c cpointer? (or/c cpointer? #f) cpointer? flonum?)
;; parametric constraint function
(define (myconstraint n x grad data)
  ;; expect: n = 2
  ;; expect: x is a cpointer to 2 doubles.

  ;; Manipulate x using Racket's unsafe interface
  (define x0 (ptr-ref x _double 0))
  (define x1 (ptr-ref x _double 1))
  ;; data had better be a cboxed constraint-data object
  ;; FFI doesn't preserve tag, so unsafely force it ( :( )
  (set-cpointer-tag! data _cbox)
  (define cd (cunbox data))
  (define a (constraint-data-a cd))
  (define b (constraint-data-b cd))
  ;(printf "(~a,~a) constraint\n" a b)

  ;; Manipulate grad using Racket's unsafe interface
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
(set-lower-bounds opt (flvector->cpointer lower-bounds))

;; set-min-objective objective
(set-min-objective opt myfunc #f) 


;; add-inequality-constraint x 2
(define cbdata1 (cbox (make-constraint-data 2.0 0.0)))
(define cbdata2 (cbox (make-constraint-data -1.0 1.0)))
(collect-garbage 'major) ;; stress test

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

;; cleanup
(printf "~a freed cboxes" (free-cboxes))