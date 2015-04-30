#lang racket

(require nlopt/unsafe)
(require ffi/unsafe ffi/vector)
(require math/flonum)

(define opt (create 'LN_COBYLA 2))
(set-maxeval opt 150000)
(set-lower-bounds1 opt -10.0)
(define (f dim x grad data)
  (define a (ptr-ref x _double 0))
  (define b (ptr-ref x _double 1))
  (when grad
        (ptr-set! grad _double 0 (cos a))
        (ptr-set! grad _double 1 (cos b)))
  (+ (* a a) (* b b)))
(set-min-objective opt f #f)
(add-equality-constraint opt
                         (lambda (dim x grad data)
                           (+ (ptr-ref x _double 0)
                              (ptr-ref x _double 1)
                              -1.0))
                         #f
                         1e-8)
(define x (flvector -3.0 -0.5))
(optimize opt (flvector->cpointer x))
(flvector->list x)

