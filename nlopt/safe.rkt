#lang racket

(require racket/require
         racket/flonum
         (only-in ffi/unsafe flvector->cpointer memcpy _double))

(require
 (filtered-in
  (lambda (name)
    (let ([particularly-unsafe
           '("optimize"
             "set-min-objective" "set-max-objective"
             "set-lower-bounds" "set-upper-bounds"
             "get-lower-bounds" "get-upper-bounds"
             "add-inequality-constraint"
             "add-equality-constraint"
             "set-xtol-abs"     "get-xtol-abs"
             "set-default-initial-step"
             "set-initial-step" "get-initial-step")])
      (if (member name particularly-unsafe)
          (string-append "unsafe-" name)
          name)))
  (file "unsafe.rkt")))

; Special contracts

(define nlopt-algorithm/c
  (apply one-of/c algorithms))
(define nlopt-result/c
  (apply one-of/c '(FAILURE
                    INVALID_ARGS
                    OUT_OF_MEMORY
                    ROUNDOFF_LIMITED
                    FORCED_STOP
                    SUCCESS
                    STOPVAL_REACHED
                    FTOL_REACHED
                    XTOL_REACHED
                    MAXEVAL_REACHED
                    MAXTIME_REACHED)))
(define dimension?
  (and/c natural-number/c positive?))

(define (flvector/length? n)
  (lambda (v)
    (and (flvector? v)
         (= n (flvector-length v)))))


(provide/contract
 [algorithms (listof symbol?)]
 [algorithm->name (-> nlopt-algorithm/c string?)]
 [name->algorithm (-> string? nlopt-algorithm/c)]
 [version (-> (list/c natural-number/c
                      natural-number/c
                      natural-number/c))]
 [nlopt-opt? (-> any/c boolean?)])

;;; BASICS

(define (optimize opt initial)
  (unsafe-optimize opt (flvector->cpointer initial)))

(define (wrap-nlopt-func f)
  (lambda (n raw-x raw-grad data)
    (define x (make-flvector n))
    (define grad (if raw-grad
                     (make-flvector n)
                     #f))
    (memcpy (flvector->cpointer x) raw-x n _double)
    (begin0
     (f x grad data)
     (when raw-grad
       (memcpy raw-grad (flvector->cpointer grad) n _double)))))

(define (set-min-objective opt f data)
  (unsafe-set-min-objective
   opt
   (wrap-nlopt-func f)
   data))

(define (set-max-objective opt f data)
  (unsafe-set-max-objective
   opt
   (wrap-nlopt-func f)
   data))

(provide/contract
 [create (-> nlopt-algorithm/c dimension?
             nlopt-opt?)]
 [copy (-> nlopt-opt? nlopt-opt?)]
 [optimize (->i ([opt nlopt-opt?]
                 [initial (opt)
                          (flvector/length? (get-dimension opt))])
                (values [res nlopt-result/c]
                        [f real?]))]
 [set-min-objective (->i ([opt nlopt-opt?]
                          [f (opt) (-> flvector?
                                       (or/c flvector? #f)
                                       any/c
                                       flonum?)]
                          [data any/c])
                         [res nlopt-result/c])]
 [set-max-objective (->i ([opt nlopt-opt?]
                          [f (opt) (-> flvector?
                                       (or/c flvector? #f)
                                       any/c
                                       flonum?)]
                          [data any/c])
                         [res nlopt-result/c])]
 [get-algorithm (-> nlopt-opt? nlopt-algorithm/c)]
 [get-dimension (-> nlopt-opt? dimension?)])

;;; CONSTRAINTS

(define (set-lower-bounds opt bounds)
  (unsafe-set-lower-bounds opt (flvector->cpointer bounds)))

(define (set-upper-bounds opt bounds)
  (unsafe-set-upper-bounds opt (flvector->cpointer bounds)))

(define (get-lower-bounds opt)
  (define lb (make-flvector (get-dimension opt)))
  (values (unsafe-get-lower-bounds opt (flvector->cpointer lb))
          lb))

(define (get-upper-bounds opt)
  (define ub (make-flvector (get-dimension opt)))
  (values (unsafe-get-lower-bounds opt (flvector->cpointer ub))
          ub))

(define (add-inequality-constraint opt f data tol)
  (unsafe-add-inequality-constraint
   opt
   (wrap-nlopt-func f)
   data
   tol))

(define (add-equality-constraint opt f data tol)
  (unsafe-add-inequality-constraint
   opt
   (wrap-nlopt-func f)
   data
   tol))

(provide/contract
 [set-lower-bounds (->i ([opt nlopt-opt?]
                         [bounds (opt) (flvector/length? (get-dimension opt))])
                        [res nlopt-result/c])]
 [set-upper-bounds (->i ([opt nlopt-opt?]
                         [bounds (opt) (flvector/length? (get-dimension opt))])
                        [res nlopt-result/c])]
 [set-lower-bounds1 (-> nlopt-opt? real? nlopt-result/c)]
 [set-upper-bounds1 (-> nlopt-opt? real? nlopt-result/c)]
 [get-lower-bounds
  (->i ([opt nlopt-opt?])
       (values
        [res nlopt-result/c]
        [bounds (opt) (flvector/length? (get-dimension opt))]))]
 [get-upper-bounds
  (->i ([opt nlopt-opt?])
       (values
        [res nlopt-result/c]
        [bounds (opt) (flvector/length? (get-dimension opt))]))]
 [remove-inequality-constraints (-> nlopt-opt? nlopt-result/c)]
 [add-inequality-constraint
  (->i ([opt nlopt-opt?]
        [f (opt) (-> (=/c (get-dimension opt))
                     flvector?
                     (or/c flvector? #f)
                     any/c
                     flonum?)]
        [data any/c]
        [tolerance real?])
       [res nlopt-result/c])]
 [remove-equality-constraints (-> nlopt-opt? nlopt-result/c)]
 [add-equality-constraint
  (->i ([opt nlopt-opt?]
        [f (opt) (-> (=/c (get-dimension opt))
                     flvector?
                     (or/c flvector? #f)
                     any/c
                     flonum?)]
        [data any/c]
        [tolerance real?])
       [res nlopt-result/c])])

;;; STOPPING CRITERIA

(define (set-xtol-abs opt xtols)
  (unsafe-set-xtol-abs opt (flvector->cpointer xtols)))

(define (get-xtol-abs opt)
  (define xtols (make-flvector (get-dimension opt)))
  (values (unsafe-get-xtol-abs opt (flvector->cpointer xtols))
          xtols))

(provide/contract
 [set-stopval (-> nlopt-opt? real? nlopt-result/c)]
 [get-stopval (-> nlopt-opt? flonum?)]
 [set-ftol-rel (-> nlopt-opt? real? nlopt-result/c)]
 [get-ftol-rel (-> nlopt-opt? flonum?)]
 [set-ftol-abs (-> nlopt-opt? real? nlopt-result/c)]
 [get-ftol-abs (-> nlopt-opt? flonum?)]
 [set-xtol-rel (-> nlopt-opt? real? nlopt-result/c)]
 [get-xtol-rel (-> nlopt-opt? flonum?)]
 [set-xtol-abs1 (-> nlopt-opt? real? nlopt-result/c)]
 [set-xtol-abs (->i ([opt nlopt-opt?]
                     [xtols (opt) (flvector/length? (get-dimension opt))])
                    [res nlopt-result/c])]
 [get-xtol-abs (->i ([opt nlopt-opt?])
                    (values
                     [res nlopt-result/c]
                     [xtols (opt) (flvector/length? (get-dimension opt))]))]
 [set-maxeval (-> nlopt-opt? natural-number/c nlopt-result/c)]
 [get-maxeval (-> nlopt-opt? natural-number/c)]
 [set-maxtime (-> nlopt-opt? real? nlopt-result/c)]
 [get-maxtime (-> nlopt-opt? flonum?)]
 [force-stop (-> nlopt-opt? nlopt-result/c)]
 [set-force-stop (-> nlopt-opt? integer? nlopt-result/c)]
 [get-force-stop (-> nlopt-opt? integer?)])

;;; ALGORITHM-SPECIFIC PARAMETERS

(define (set-default-initial-step opt steps)
  (unsafe-set-default-initial-step opt (flvector->cpointer steps)))

(define (set-initial-step opt steps)
  (unsafe-set-initial-step opt (flvector->cpointer steps)))

(define (get-initial-step opt)
  (define steps (make-flvector (get-dimension opt)))
  (values (unsafe-get-initial-step opt steps)
          steps))

(provide/contract
 [set-local-optimizer (-> nlopt-opt? nlopt-opt? nlopt-result/c)]
 [set-population (-> nlopt-opt? natural-number/c nlopt-result/c)]
 [get-population (-> nlopt-opt? natural-number/c)]
 [set-vector-storage (-> nlopt-opt? natural-number/c nlopt-result/c)]
 [get-vector-storage (-> nlopt-opt? natural-number/c)]
 [set-default-initial-step
  (->i ([opt nlopt-opt?]
        [bounds (opt) (flvector/length? (get-dimension opt))])
       [res nlopt-result/c])]
 [set-initial-step1 (-> nlopt-opt? real? nlopt-result/c)]
 [set-initial-step
  (->i ([opt nlopt-opt?]
        [bounds (opt) (flvector/length? (get-dimension opt))])
       [res nlopt-result/c])]
 [get-initial-step
  (->i ([opt nlopt-opt?])
       (values
        [res nlopt-result/c]
        [bounds (opt) (flvector/length? (get-dimension opt))]))])
