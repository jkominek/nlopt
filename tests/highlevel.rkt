#lang racket/base
(require math/flonum)
(require nlopt)

(minimize (lambda (x _) (sin (flvector-ref x 0)))
          (flvector 0.5))


(define (fun x _)
  (fl+ (flexpt (fl- (flvector-ref x 0) 1.0) 2.0)
       (flexpt (fl- (flvector-ref x 1) 2.5) 2.0)))

(define (ca x _)
  (- (+ (flvector-ref x 0)
        (fl* -2.0 (flvector-ref x 1))
        2.0)))

(define (cb x _)
  (- (+ (fl- 0.0 (flvector-ref x 0))
        (fl* -2.0 (flvector-ref x 1))
        6.0)))

(define (cc x _)
  (- (+ (fl- 0.0 (flvector-ref x 0))
        (fl* 2.0 (flvector-ref x 1))
        2.0)))

(minimize fun '(2 0)
          #:method 'LD_SLSQP
          #:eq-constraints (list (lambda (x _)
                                   (fl- (flvector-sum x) 1.0))))
