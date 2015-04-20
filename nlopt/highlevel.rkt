#lang racket/base

(require racket/flonum)
(require (only-in ffi/unsafe flvector->cpointer memcpy _double))
(require "unsafe.rkt")

(provide (rename-out [hl-optimize optimize])
         minimize
         maximize)

(define (minimize fun
                  x0
                  [data #f]
                  #:method [method #f]
                  #:jac [jac #f]
                  #:bounds [bounds #f]
                  #:ineq-constraints [ineq-constraints #f]
                  #:eq-constraints [eq-constraints #f]
                  #:tolerance [tolerance 1e-8]
                  #:epsilon [epsilon 1e-8]
                  #:maxeval [maxeval 100000]
                  #:maxtime [maxtime #f]
                  )
  (hl-optimize fun x0 data
               #:minimize #t
               #:method method
               #:jac jac
               #:bounds bounds
               #:ineq-constraints ineq-constraints
               #:eq-constraints eq-constraints
               #:tolerance tolerance
               #:epsilon epsilon
               #:maxeval maxeval
               #:maxtime maxtime))

(define (maximize fun
                  x0
                  [data #f]
                  #:method [method #f]
                  #:jac [jac #f]
                  #:bounds [bounds #f]
                  #:ineq-constraints [ineq-constraints #f]
                  #:eq-constraints [eq-constraints #f]
                  #:tolerance [tolerance 1e-8]
                  #:epsilon [epsilon 1e-8]
                  #:maxeval [maxeval 100000]
                  #:maxtime [maxtime #f]
                  )
  (hl-optimize fun x0 data
               #:maximize #t
               #:method method
               #:jac jac
               #:bounds bounds
               #:ineq-constraints ineq-constraints
               #:eq-constraints eq-constraints
               #:tolerance tolerance
               #:epsilon epsilon
               #:maxeval maxeval
               #:maxtime maxtime))

(define (approximate-jacobian f epsilon)
  (lambda (x y data grad)
    (define n (flvector-length x))
    (define d (make-flvector n 0.0))
    (define xtemp (flvector-copy x))

    (for
     ([i (in-naturals)]
      [v x])
     (flvector-set! xtemp i (fl+ v epsilon))
     (flvector-set! grad i
                    (/ (- (f xtemp data) y) epsilon))
     (flvector-set! xtemp i v))))

(define (hl-optimize
         fun
         x0
         [data #f]
         #:maximize [maximize #f]
         #:minimize [minimize #f]
         #:method [method #f]
         #:jac [jac #f]
         #:bounds [bounds #f]
         #:ineq-constraints [ineq-constraints #f]
         #:eq-constraints [eq-constraints #f]
         #:tolerance [tolerance 1e-8]
         #:epsilon [epsilon 1e-8]
         #:maxeval [maxeval 100000]
         #:maxtime [maxtime #f]
         )
  (when (and maximize minimize)
    (error "can't minimize and maximize at the same time"))
  (unless (or maximize minimize)
    (error "have to minimize or maximize"))
  
  (define initial-x (if (flvector? x0)
                        x0
                        (for/flvector ([i x0])
                                      (real->double-flonum i))))
  (define dimension (flvector-length initial-x))

  ; really want to base this off of four things:
  ; jacobian? bounds? ineq constraints? eq constraints?
  (define algorithm
    (if bounds
        (if (or ineq-constraints eq-constraints)
            'SLSQP
            'LD_LBFGS)
        (if jac
            'LD_LBFGS
            'LN_PRAXIS)))

  (define opt (create algorithm dimension))

  (define actual-jac
    (if jac
        jac
        (approximate-jacobian fun epsilon)))
  (define objective-function
    (let* ([flv-x (make-flvector dimension)]
           [flv-x-ptr (flvector->cpointer flv-x)]
           [flv-grad (make-flvector dimension)]
           [flv-grad-ptr (flvector->cpointer flv-grad)])
      (lambda (_ x grad data)
        (memcpy flv-x-ptr x dimension _double)
        (define y (fun flv-x data))
        (when grad
              (actual-jac flv-x y data flv-grad)
              (memcpy grad flv-grad-ptr dimension _double))
        (real->double-flonum y))))

  (if minimize
      (set-min-objective opt objective-function data)
      (set-max-objective opt objective-function data))

  (when maxeval
    (set-maxeval opt maxeval))
  (when (and maxtime (> maxtime 0))
    (set-maxtime opt maxtime))

  (let-values
      ([(res y)
        (optimize opt (flvector->cpointer initial-x))])
    (values y initial-x)))
