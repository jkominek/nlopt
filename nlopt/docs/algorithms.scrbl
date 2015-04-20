#lang scribble/manual

@(require scriblib/autobib)

@title[#:tag "algorithms"]{Algorithms}

@margin-note{This section is a rough sketch of what I intend it to be
             when the package is complete: Categorize the algorithms,
             list their Racket names, briefly indicate what they are,
             provide citations, and include DOI in the bibliography.}

This section is not intended to completely describe the algorithms.
Rather, the goal is to quickly give you a sense of what your options are. 
That way, if you have simple needs, you won't have to consult external
documentation. If you anticipate needing to know the exact details of
the optimization algorithm you use, consider consulting the NLopt website

@section{Global Optimization}

@deftogether[(@defthing[GN_DIRECT symbol?]
              @defthing[GN_DIRECT_L symbol?]
              @defthing[GLOBAL_DIRECT_L_RAND symbol?]
              @defthing[GLOBAL_DIRECT_NOSCAL symbol?]
              @defthing[GLOBAL_DIRECT_L_NOSCAL symbol?]
              @defthing[GLOBAL_DIRECT_L_RAND_NOSCAL symbol?]
              @defthing[GN_ORIG_DIRECT symbol?]
              @defthing[GN_ORIG_DIRECT_L symbol?]
              )]

@code{GN_DIRECT} is the DIviding RECTangles algorithm described in @cite{Jones93}.
@code{GN_DIRECT_L} is the "locally biased" variant proposed in @cite{Gablonsky01}.
They are deterministic search algorithms based on systematic division of
the search domain into smaller and smaller hyperrectangles. The NLopt documentation
suggests starting with @code{GN_DIRECT_L} first.


@section{Local derivative-free optimization}

@section{Local gradient-based optimization}

@section{Augmented Lagrangian algorithm}

@deftogether[(@defthing[AUGLAG symbol?]
              @defthing[AUGLAG_EQ symbol?])]

Requires the specification of a subsidiary optimization algorithm
via @racket[set-local-optimizer]. @code{AUGLAG} converts the
objective function and all constraints into a single function,
and uses the subsidiary algorithm to optimize it. @code{AUGLAG_EQ}
only converts the objective and equality constraints; the inequality
constraints are passed through to the subsidiary algorithm. (Which
must be able to handle them.)

Described in @cite{Conn91} and @cite{Birgin08}.

@(bibliography
  (bib-entry
   #:key "NLopt"
   #:title "The NLopt nonlinear-optimization package"
   #:url "http://ab-initio.mit.edu/nlopt")

  (bib-entry
   #:key "Jones93"
   #:title "Lipschitzian optimization without the lipschitz constant"
   #:location (journal-location "J. Optimization Theory and Applications"
                                #:volume 79
                                #:pages '(157 157))
   #:date "1993"
   #:url "http://dx.doi.org/10.1007/BF00941892")
  (bib-entry
   #:key "Gablonsky01"
   #:title "A locally-biased form of the DIRECT algorithm"
   #:location (journal-location "Journal of Global Optimization"
                                #:volume 21
                                #:number 1
                                #:pages '(27 37))
   #:date "2001"
   #:url "http://dx.doi.org/10.1023/A:1017930332101")
   
  (bib-entry
   #:key "Conn91"
   #:author "Andrew R. Conn, Nicholas I. M. Gould, and Philippe L. Toint"
   #:title "A globally convergent augmented Lagrangian algorithm for optimization with general constraints and simple bounds"
   #:location (journal-location "SIAM J. Numer. Anal."
                                #:volume 28
                                #:number 2
                                #:pages '(545 572))
   #:date "1991"
   #:url "http://dx.doi.org/10.1137/0728030")
  (bib-entry
   #:key "Birgin08"
   #:author "E. G. Birgin and J. M. Martínez"
   #:title "Improving ultimate convergence of an augmented Lagrangian method"
   #:location (journal-location "Optimization Methods and Software"
                                #:volume 23
                                #:number 2
                                #:pages '(177 195))
   #:date "2008"
   #:url "http://dx.doi.org/10.1080/10556780701577730")
  )
