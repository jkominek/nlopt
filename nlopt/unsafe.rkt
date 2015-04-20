#lang racket/base

(require (for-syntax racket/base))
(require syntax/parse
         ffi/unsafe)

(define libnlopt-name
  (case (system-type 'os)
    [(unix) "libnlopt.so"]
    [(windows) "libnlopt-0.dll"]
    [(macosx) "libnlopt.dylib"]))

(define _nlopt_algorithm
  (_enum '(GN_DIRECT = 0
           GN_DIRECT_L
           GN_DIRECT_L_RAND
           GN_DIRECT_NOSCAL
           GN_DIRECT_L_NOSCAL
           GN_DIRECT_L_RAND_NOSCAL

           GN_ORIG_DIRECT
           GN_ORIG_DIRECT_L

           GD_STOGO
           GD_STOGO_RAND

           LD_LBFGS_NOCEDAL

           LD_LBFGS

           LN_PRAXIS

           LD_VAR1
           LD_VAR2
         
           LD_TNEWTON
           LD_TNEWTON_RESTART
           LD_TNEWTON_PRECOND
           LD_TNEWTON_PRECOND_RESTART

           GN_CRS2_LM

           GN_MLSL
           GD_MLSL
           GN_MLSL_LDS
           GD_MLSL_LDS

           LD_MMA

           LN_COBYLA

           LN_NEWUOA
           LN_NEWUOA_BOUND

           LN_NELDERMEAD
           LN_SBPLX

           LN_AUGLAG
           LD_AUGLAG
           LN_AUGLAG_EQ
           LD_AUGLAG_EQ

           LN_BOBYQA

           GN_ISRES

           ; new variants that require local_optimizer to be set
           ; not with older constants for backwards compatibility */
           AUGLAG
           AUGLAG_EQ
           G_MLSL
           G_MLSL_LDS
           
           LD_SLSQP
         
           LD_CCSAQ

           GN_ESCH

           NUM_ALGORITHMS)))

(define _nlopt_result
  (_enum '(FAILURE = -1 ; generic failure code
           INVALID_ARGS = -2
           OUT_OF_MEMORY = -3
           ROUNDOFF_LIMITED = -4
           FORCED_STOP = -5
           SUCCESS = 1 ; generic success code
           STOPVAL_REACHED = 2
           FTOL_REACHED = 3
           XTOL_REACHED = 4
           MAXEVAL_REACHED = 5
           MAXTIME_REACHED = 6)
         _int))

(define libnlopt (ffi-lib libnlopt-name))

(define-for-syntax (convert-name stx n)
  (datum->syntax stx
		 (string->symbol
		  (regexp-replaces
		   (symbol->string (syntax->datum n))
		   '((#rx"-" "_")
		     [#rx"(.*)$" "nlopt_\\1"]
		     (#rx"!$" ""))))))

(define-syntax (defnlopt stx)
  (syntax-case stx (:)
    [(_ name wrapper : type ...)
     (with-syntax
      ([libsym (convert-name stx #'name)])
      #'(begin
	  (define name
	    (procedure-rename
	     (wrapper (get-ffi-obj 'libsym libnlopt (_fun type ...)))
	     'name))
	  (provide name)))]
    [(_ name : type ...)
     (with-syntax
      ([libsym (convert-name stx #'name)])
      #'(begin
	  (define name
            (procedure-rename
             (get-ffi-obj 'libsym libnlopt (_fun type ...))
             'name))
	  (provide name)))]))

(defnlopt version
  : (major : (_ptr o _int)) (minor : (_ptr o _int)) (bugfix : (_ptr o _int))
  -> _void -> (list major minor bugfix))

(define _nlopt_opt _pointer)
(define-struct nlopt-opt [ptr
                          ; these will hold on to allocated racket objects
                          ; TODO this doesn't guarantee the GC won't move
                          ; them, which would screw things up
                          (obj-data #:mutable #:auto)
                          (ineq-data #:mutable #:auto)
                          (eq-data #:mutable #:auto)]
  #:property prop:cpointer 0)

(provide version nlopt-opt?)


;;; BASICS

(define algorithms
  (for/list ([i (in-range 0 (cast 'NUM_ALGORITHMS _nlopt_algorithm _int))])
    (cast i _int _nlopt_algorithm)))

(defnlopt algorithm-name : _nlopt_algorithm -> _string)

(define algorithm-name-hash
  (for/hash ([algo algorithms])
    (values (algorithm-name algo)
            algo)))

(define (name->algorithm s)
  (hash-ref algorithm-name-hash s))

(provide algorithms
         (rename-out [algorithm-name algorithm->name])
         name->algorithm)

(defnlopt destroy : _nlopt_opt -> _void)
(defnlopt create
  (lambda (f)
    (lambda args
      (define o (apply f args))
      (register-finalizer
       o
       (lambda (x)
         (destroy x)))
      (nlopt-opt o)))
  : _nlopt_algorithm _uint -> _nlopt_opt)
(defnlopt copy
  (lambda (f)
    (lambda (o)
      (nlopt-opt (f o)
                 (nlopt-opt-obj-data o)
                 (nlopt-opt-ineq-data o)
                 (nlopt-opt-eq-data o))))
  : _nlopt_opt -> _nlopt_opt)

(defnlopt optimize : _nlopt_opt _pointer (opt_f : (_ptr o _double)) -> (res : _nlopt_result) -> (values res opt_f))

(define _nlopt_func (_fun (n : _uint) _pointer (_or-null _pointer) _racket -> _double))

(define (objective-wrapper raw)
  (lambda (o f d)
    (set-nlopt-opt-obj-data! o d)
    (raw o f d)))
(defnlopt set-min-objective objective-wrapper : _nlopt_opt _nlopt_func _racket -> _nlopt_result)
(defnlopt set-max-objective objective-wrapper : _nlopt_opt _nlopt_func _racket -> _nlopt_result)

; These are currently omitted
; set-precond-min-objective
; set-precond-max-objective

(defnlopt get-algorithm : _nlopt_opt -> _nlopt_algorithm)
(defnlopt get-dimension : _nlopt_opt -> _uint)

(provide create copy optimize
         set-min-objective set-max-objective
         get-algorithm get-dimension)



;;; CONSTRAINTS

(defnlopt set-lower-bounds : _nlopt_opt _pointer -> _nlopt_result)
(defnlopt set-upper-bounds : _nlopt_opt _pointer -> _nlopt_result)
(defnlopt set-lower-bounds1 : _nlopt_opt _double* -> _nlopt_result)
(defnlopt set-upper-bounds1 : _nlopt_opt _double* -> _nlopt_result)

(defnlopt get-lower-bounds
  : (opt : _nlopt_opt) (lb : _pointer)
  -> (res : _nlopt_result))
(defnlopt get-upper-bounds
  : (opt : _nlopt_opt) (ub : _pointer)
  -> (res : _nlopt_result))

(define (add-in/eq-wrapper accessor setter)
  (lambda (raw)
    (lambda (o f d t)
      (setter o (cons d (accessor o)))
      (raw o f d t))))
(define (remove-in/eq-wrapper setter)
  (lambda (raw)
    (lambda (o)
      (setter o '())
      (raw o))))

(defnlopt remove-inequality-constraints
  (remove-in/eq-wrapper set-nlopt-opt-ineq-data!)
  : _nlopt_opt -> _nlopt_result)
(defnlopt add-inequality-constraint
  (add-in/eq-wrapper nlopt-opt-ineq-data set-nlopt-opt-ineq-data!)
  : _nlopt_opt _nlopt_func _racket _double* -> _nlopt_result)
; omitted
; add-precond-inequality-constraint
; add-inequality-mconstraint

(defnlopt remove-equality-constraints
  (remove-in/eq-wrapper set-nlopt-opt-eq-data!)
  : _nlopt_opt -> _nlopt_result)
(defnlopt add-equality-constraint
  (add-in/eq-wrapper nlopt-opt-eq-data set-nlopt-opt-eq-data!)
  : _nlopt_opt _nlopt_func _racket _double* -> _nlopt_result)
; omitted
; add-precond-equality-constraint
; add-equality-mconstraint

(provide set-lower-bounds  set-upper-bounds
         set-lower-bounds1 set-upper-bounds1
         get-lower-bounds  get-upper-bounds
         remove-inequality-constraints
         add-inequality-constraint
         remove-equality-constraints
         add-equality-constraint)

;;; STOPPING CRITERIA

(defnlopt set-stopval : _nlopt_opt _double* -> _nlopt_result)
(defnlopt get-stopval : _nlopt_opt -> _double)

(defnlopt set-ftol-rel : _nlopt_opt _double* -> _nlopt_result)
(defnlopt get-ftol-rel : _nlopt_opt -> _double)
(defnlopt set-ftol-abs : _nlopt_opt _double* -> _nlopt_result)
(defnlopt get-ftol-abs : _nlopt_opt -> _double)

(defnlopt set-xtol-rel : _nlopt_opt _double* -> _nlopt_result)
(defnlopt get-xtol-rel : _nlopt_opt -> _double)
(defnlopt set-xtol-abs1 : _nlopt_opt _double* -> _nlopt_result)
(defnlopt set-xtol-abs : _nlopt_opt _pointer -> _nlopt_result)
(defnlopt get-xtol-abs : _nlopt_opt _pointer -> _nlopt_result)

(defnlopt set-maxeval : _nlopt_opt _int -> _nlopt_result)
(defnlopt get-maxeval : _nlopt_opt -> _int)

(defnlopt set-maxtime : _nlopt_opt _double* -> _nlopt_result)
(defnlopt get-maxtime : _nlopt_opt -> _double)

(defnlopt force-stop : _nlopt_opt -> _nlopt_result)
(defnlopt set-force-stop : _nlopt_opt _int -> _nlopt_result)
(defnlopt get-force-stop : _nlopt_opt -> _int)

(provide set-stopval    get-stopval
         set-ftol-rel   get-ftol-rel
         set-ftol-abs   get-ftol-abs
         set-xtol-rel   get-xtol-rel
         set-xtol-abs1
         set-xtol-abs   get-xtol-abs
         set-maxeval    get-maxeval
         set-maxtime    get-maxtime
         force-stop
         set-force-stop get-force-stop)

;;; ALGORITHM-SPECIFIC PARAMETERS

(defnlopt set-local-optimizer : _nlopt_opt _nlopt_opt -> _nlopt_result)

(defnlopt set-population : _nlopt_opt _uint -> _nlopt_result)
(defnlopt get-population : _nlopt_opt -> _uint)

(defnlopt set-vector-storage : _nlopt_opt _uint -> _nlopt_result)
(defnlopt get-vector-storage : _nlopt_opt -> _uint)

(defnlopt set-default-initial-step : _nlopt_opt _pointer -> _nlopt_result)
(defnlopt set-initial-step : _nlopt_opt _pointer -> _nlopt_result)
(defnlopt set-initial-step1 : _nlopt_opt _double* -> _nlopt_result)
(defnlopt get-initial-step : _nlopt_opt _pointer _pointer -> _nlopt_result)

(provide set-local-optimizer
         set-population      get-population
         set-vector-storage  get-vector-storage
         set-default-initial-step
         set-initial-step1
         set-initial-step    get-initial-step)

;;; WRAPPER INTERNALS

; not currently used anywhere
(define _nlopt_munge (_fun _racket -> _pointer))
(defnlopt set-munge : _nlopt_opt _nlopt_munge _nlopt_munge -> _void)


