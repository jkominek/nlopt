#lang racket

(require nlopt/highlevel)


(module+ test
  (require rackunit))

;;
;; highlevel-example.rkt - A re-implementation of the NLopt example
;; from https://nlopt.readthedocs.io/en/latest/NLopt_Tutorial/
;; using the nlopt/highlevel API
;;


;;
;; The following code solves a nonlinearly-constrained minimization problem:
;; let f(x0,x1) = (sqrt x1)
;; find the pair x0,x1 that (approximately) minimize f
;; over the region
;; x1 >= (-x0 + 1)^3;
;; x1 >= (2*x0 + 0)^3;
;; 

;; the core function
(define (fn x0 x1)
  (sqrt x1))

;; the core gradient function (not strictly needed! see below)
(define (grad-fn x0 x1)
  (list 0.0 (/ 0.5 (sqrt x1))))

;; parameterized inequality constraint function
;; nice when multiple inequalities have the same shape
;; (cn a b) yields a function C(x) which represents the inequality C(x) <= 0
(define ((cn a b) x0 x1)
  (- (expt (+ (* a x0) b) 3) x1))

;; parameterized constraint gradient-function function (not strictly needed!)
(define ((grad-cn a b) x0 x1)
  (list (* 3 a (expt (+ (* a x0) b) 2))
        0.0))

;; (lower-bound . upper-bound) pairs for x0 and x1 
(define bounds '((-inf.0 . +inf.0) (0.0 . +inf.0)))

;; starting point for search (within the intended bounds)
(define initial-x (list 1.234 5.678))

(define ineq-constraints
  (list (cons (cn 2.0 0.0) (grad-cn 2.0 0.0))
        (cons (cn -1.0 1.0) (grad-cn -1.0 1.0))))

;; helper for formatting decimal numbers
(define (digits n) (real->decimal-string n 3))

;; perform the optimization
(define-values (fn-x-final x-final)
  (optimize/args fn
                 initial-x
                 #:minimize #t
                 #:jac grad-fn
                 #:method 'LD_MMA
                 #:bounds bounds
                 #:ineq-constraints ineq-constraints))

(printf "Result: x = ~a; f(x) = ~a.\n" (map digits x-final) (digits fn-x-final))

;;
;; Simpler variation of the same problem:
;; */args can pick a default optimization method and can approximate gradients
(define-values (fn-x-final^ x-final^)
  (minimize/args fn
                 initial-x
                 #:bounds bounds
                 #:ineq-constraints (list (cn 2.0 0.0) (cn -1.0 1.0))))

(printf "Result: x = ~a; f(x) = ~a.\n" (map digits x-final) (digits fn-x-final))

