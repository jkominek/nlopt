#lang racket/base

(require (for-syntax racket/base))

(require math/flonum
         racket/sequence
         racket/vector
         ffi/vector)

(require (only-in ffi/unsafe flvector->cpointer
                  memcpy _double _double* ptr-ref ptr-set!))
(require (rename-in (file "unsafe.rkt")
                    [optimize raw-optimize]))

(provide optimize/flvector  minimize/flvector  maximize/flvector
         optimize/f64vector minimize/f64vector maximize/f64vector
         optimize/vector    minimize/vector    maximize/vector
         optimize/list      minimize/list      maximize/list
         optimize/args      minimize/args      maximize/args
         )

(define-syntax (define-flavored-izer stx)
  (syntax-case stx ()
    [(_ name (in-kws ...) (out-kws ...) c-f a-j o-f)
     #'(define (name fun x0
                     #:method [method #f]
                     #:jac [jac #f]
                     #:bounds [bounds #f]
                     #:ineq-constraints [ineq-constraints #f]
                     #:eq-constraints [eq-constraints #f]
                     #:tolerance [tolerance 1e-8]
                     #:epsilon [epsilon 1e-8]
                     #:maxeval [maxeval 15000]
                     #:maxtime [maxtime #f]
                     in-kws ...
                     )
         (universal-optimizer fun x0
                              out-kws ...
                              #:method method
                              #:jac jac
                              #:bounds bounds
                              #:ineq-constraints ineq-constraints
                              #:eq-constraints eq-constraints
                              #:tolerance tolerance
                              #:epsilon epsilon
                              #:maxeval maxeval
                              #:maxtime maxtime
                              #:construct-func c-f
                              #:approximate-jacobian a-j
                              #:output-formatter o-f
                              #:source 'name))]))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Flonum Vectors

(define (approximate-jacobian/flvector n f epsilon)
  (lambda (y x grad)
    (define xtemp (flvector-copy x))
    (for ([i (in-naturals)]
          [v x])
     (flvector-set! xtemp i (fl+ v epsilon))
     (flvector-set! grad i
                    (fl/ (fl- (f xtemp) y) epsilon))
     (flvector-set! xtemp i v))))

(define (construct-func/flvector dimension fun jac)
  (let* ([flv-x (make-flvector dimension)]
         [flv-grad (make-flvector dimension)])
    (lambda (_ x grad data)
      (memcpy (flvector->cpointer flv-x) x dimension _double)
      (define y (fun flv-x))
      (when grad
        (jac y flv-x flv-grad)
        (memcpy grad (flvector->cpointer flv-grad) dimension _double))
      (real->double-flonum y))))

(define (identity x) x)

(define-flavored-izer minimize/flvector () (#:minimize #t)
  construct-func/flvector approximate-jacobian/flvector identity)

(define-flavored-izer maximize/flvector () (#:maximize #t)
  construct-func/flvector approximate-jacobian/flvector identity)

(define-flavored-izer optimize/flvector
  (#:minimize [minimize #f]
   #:maximize [maximize #f])
  (#:minimize minimize
   #:maximize maximize)
  construct-func/flvector approximate-jacobian/flvector identity)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; f64vectors

(define (approximate-jacobian/f64vector n f epsilon)
  (lambda (y x grad)
    (for ([i (in-range 0 n)])
     (define v (f64vector-ref x i))
     (f64vector-set! x i (fl+ v epsilon))
     (f64vector-set! grad i
                     (fl/ (fl- (f x) y) epsilon))
     (f64vector-set! x i v))))

(define (construct-func/f64vector dimension fun jac)
;;;; TODO
  (let* ([f64v-x (make-f64vector dimension)]
         [f64v-grad (make-f64vector dimension)])
    (lambda (_ x grad data)
      (memcpy f64v-x x dimension _double)
      (define y (fun f64v-x))
      (when grad
        (jac y f64v-x f64v-grad)
        (memcpy grad f64v-grad dimension _double))
      (real->double-flonum y))))

(define (flvector->f64vector flv)
  (define f64v (make-f64vector (flvector-length flv)))
  (memcpy f64v (flvector->cpointer flv) (flvector-length flv) _double)
  f64v)

(define-flavored-izer minimize/f64vector () (#:minimize #t)
  construct-func/f64vector approximate-jacobian/f64vector
  flvector->f64vector)

(define-flavored-izer maximize/f64vector () (#:maximize #t)
  construct-func/f64vector approximate-jacobian/f64vector
  flvector->f64vector)

(define-flavored-izer optimize/f64vector
  (#:minimize [minimize #f]
   #:maximize [maximize #f])
  (#:minimize minimize
   #:maximize maximize)
  construct-func/f64vector approximate-jacobian/f64vector
  flvector->f64vector)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Standard Schemely vectors

(define (approximate-jacobian/vector n f epsilon)
  (lambda (x y grad)
    (define xtemp (vector-copy x))
    (for ([i (in-naturals)]
          [v x])
     (vector-set! xtemp i (+ v epsilon))
     (vector-set! grad i (/ (- (f xtemp) y) epsilon))
     (vector-set! xtemp i v))))

(define (construct-func/vector dimension fun jac)
  (define vec-x (make-vector dimension 0.0))
  (define vec-grad (make-vector dimension 0.0))
  (lambda (_ x grad data)
    (for ([i (in-range 0 dimension)])
      (vector-set! vec-x i (ptr-ref x _double i)))
    (define y (fun vec-x))
    (when grad
      (jac vec-x y vec-grad)
      (for ([i (in-range 0 dimension)])
        (ptr-set! grad _double* i (vector-ref vec-grad i))))
    (real->double-flonum y)))

#;(define (flvector->vector flv)
  (for/vector #:length (flvector-length vlc)
              ([v flv])
    v))

(define-flavored-izer minimize/vector () (#:minimize #t)
  construct-func/vector approximate-jacobian/vector
  flvector->vector)

(define-flavored-izer maximize/vector () (#:maximize #t)
  construct-func/vector approximate-jacobian/vector
  flvector->vector)

(define-flavored-izer optimize/vector
  (#:minimize [minimize #f]
   #:maximize [maximize #f])
  (#:minimize minimize
   #:maximize maximize)
  construct-func/vector approximate-jacobian/vector
  flvector->vector)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Lists

(define (approximate-jacobian/list n f epsilon)
  (lambda (y x)
    ; we could construct the intermediate lists a bit more
    ; efficiently. but, meh. see */flvector for fast(er).
    (for/list ([i (in-naturals)]
               [v x])
      (/ (- (f (for/list ([j (in-naturals)]
                          [v x])
                         (if (= i j)
                             (+ v epsilon)
                             v))) y) epsilon))))

(define (construct-func/list dimension fun jac)
  (lambda (_ x grad data)
    (define lst-x (build-list dimension
                              (lambda (i)
                                (ptr-ref x _double i))))
    (define y (fun lst-x))
    (when grad
      (define lst-grad (jac y lst-x))
      (for ([i (in-range 0 dimension)]
            [grad-v lst-grad])
        (ptr-set! grad _double* i grad-v)))
    (real->double-flonum y)))

(define-flavored-izer minimize/list () (#:minimize #t)
  construct-func/list approximate-jacobian/list flvector->list)

(define-flavored-izer maximize/list () (#:maximize #t)
  construct-func/list approximate-jacobian/list flvector->list)

(define-flavored-izer optimize/list
  (#:minimize [minimize #f]
   #:maximize [maximize #f])
  (#:minimize minimize
   #:maximize maximize)
  construct-func/list approximate-jacobian/list
  flvector->list)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Arguments

(define (approximate-jacobian/args n f epsilon)
  (lambda x
    (define y (apply f x))
    ; we could construct the intermediate lists a bit more
    ; efficiently. but, meh. see */flvector for fast(er).
    (for/list ([i (in-naturals)]
               [v x])
      (/ (- (apply f (for/list ([j (in-naturals)]
                                [v x])
                               (if (= i j)
                                   (+ v epsilon)
                                   v))) y) epsilon))))

(define (construct-func/args dimension fun jac)
  (lambda (_ x grad data)
    (define lst-x (build-list dimension
                              (lambda (i)
                                (ptr-ref x _double i))))
    (define y (apply fun lst-x))
    (when grad
      (define lst-grad
        (let ([res (apply jac lst-x)])
          (if (list? res)
              res
              (list res))))
      (for ([i (in-range 0 dimension)]
            [grad-v lst-grad])
        (ptr-set! grad _double* i grad-v)))
    (real->double-flonum y)))

(define (flvector->args flv)
  (if (= (flvector-length flv) 1)
      (flvector-ref flv 0)
      (flvector->list flv)))

(define-flavored-izer minimize/args () (#:minimize #t)
  construct-func/args approximate-jacobian/args flvector->args)

(define-flavored-izer maximize/args () (#:maximize #t)
  construct-func/args approximate-jacobian/args flvector->args)

(define-flavored-izer optimize/args
  (#:minimize [minimize #f]
   #:maximize [maximize #f])
  (#:minimize minimize
   #:maximize maximize)
  construct-func/args approximate-jacobian/args flvector->args)





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; The universal optimizer

(define (universal-optimizer
         fun
         x0
         #:maximize [maximize #f]
         #:minimize [minimize #f]
         #:construct-func [construct-func #f]
         #:approximate-jacobian [approximate-jacobian #f]
         #:output-formatter [output-formatter #f]
         #:method [method #f]
         #:jac [jac #f]
         #:bounds [bounds #f]
         #:ineq-constraints [ineq-constraints #f]
         #:eq-constraints [eq-constraints #f]
         #:tolerance [tolerance 1e-8]
         #:epsilon [epsilon 1e-8]
         #:maxeval [maxeval 100000]
         #:maxtime [maxtime #f]
         #:source [source 'universal-optimizer]
         )
  (when (and maximize minimize)
    (raise-argument-error source "minimize xor maximize"
                          "can't minimize and maximize at the same time"))
  (unless (or maximize minimize)
    (raise-argument-error source "minimize xor maximize"
                          "must minimize or maximize"))

  (define initial-x (for/flvector ([i x0])
                                  (real->double-flonum i)))
  (define dimension (flvector-length initial-x))

  ; really want to base this off of four things:
  ; jacobian? bounds? ineq constraints? eq constraints?
  (define have-jacobian? (procedure? jac))
  (define have-bounds? (sequence? bounds))
  (define have-ineq-constraints? (sequence? ineq-constraints))
  (define have-eq-constraints? (sequence? eq-constraints))

  (define algorithm
    (if method
        method
        (if have-bounds?
            (if (or have-ineq-constraints? have-eq-constraints?)
                'LD_SLSQP
                'LD_LBFGS)
            ; this is probably insufficient/incorrect.
            (if have-jacobian?
                'LD_LBFGS
                'LN_PRAXIS))))
  
  (define opt (create algorithm dimension))

  (define actual-jac
    (if have-jacobian?
        jac
        (approximate-jacobian dimension fun epsilon)))
  (define objective-function
    (construct-func dimension fun actual-jac))

  (if minimize
      (set-min-objective opt objective-function #f)
      (set-max-objective opt objective-function #f))

  (when have-bounds?
    (define lb (make-flvector dimension -max.0))
    (define ub (make-flvector dimension +max.0))

    (for ([i (in-range 0 dimension)]
          [(lo hi) (in-parallel (sequence-map car bounds)
                                (sequence-map cdr bounds))])
      (flvector-set! lb i (real->double-flonum lo))
      (flvector-set! ub i (real->double-flonum hi)))

    (set-lower-bounds opt (flvector->cpointer lb))
    (set-upper-bounds opt (flvector->cpointer ub)))

  (when ineq-constraints
    (for ([constraint ineq-constraints])
      (define-values
        (constraintf constraintjac)
        (if (pair? constraint)
            (values (car constraint)
                    (cdr constraint))
            (values constraint
                    (approximate-jacobian
                     dimension constraint epsilon))))
             
      (define f (construct-func dimension
                                constraintf
                                constraintjac))

      (add-inequality-constraint opt f #f tolerance)))

  (when eq-constraints
        (for ([constraint eq-constraints])
      (define-values
        (constraintf constraintjac)
        (if (pair? constraint)
            (values (car constraint)
                    (cdr constraint))
            (values constraint
                    (approximate-jacobian
                     dimension constraint epsilon))))
             
      (define f (construct-func dimension
                                constraintf
                                constraintjac))

      (add-equality-constraint opt f #f tolerance)))

  (when maxeval
    (set-maxeval opt maxeval))

  (when (and maxtime (> maxtime 0))
    (set-maxtime opt maxtime))

  (let-values
      ([(res y) (raw-optimize opt (flvector->cpointer initial-x))])
    (values y (output-formatter initial-x))))
