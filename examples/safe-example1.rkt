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


(define DIMENSIONS 2) 
(define counter 0)
(define (myfunc x grad _)
  (define x0 (flvector-ref x 0))
  (define x1 (flvector-ref x 1))
  (collect-garbage 'major)
  (printf "try ~a\n" counter)
  (set! counter (add1 counter))
  (when grad
    (flvector-set! grad 0 0.0)
    (flvector-set! grad 1 (/ 0.5 (sqrt x1))))
  (sqrt x1))


;; (-> flvector? (or/c flvector? #f) any/c flonum?)
;; parametric constraint function
(define ((myconstraint a b) x grad _)
  (define x0 (flvector-ref x 0))
  (define x1 (flvector-ref x 1))

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

(define lower-bounds (flvector -inf.0 0.0))
(set-lower-bounds opt lower-bounds)

;; set-min-objective objective
(set-min-objective opt myfunc #f) 

;; add-inequality-constraint x 2
(add-inequality-constraint opt (myconstraint 2.0 0.0) #f 1e-8) 
(add-inequality-constraint opt (myconstraint -1.0 0.0) #f 1e-8) 

;; nlopt-set-xtol-rel
(set-xtol-rel opt 1e-4)

;; starting search position
(define x (flvector 1.234 5.678))

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
