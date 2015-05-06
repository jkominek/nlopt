#lang scribble/manual

@(require (for-label racket math/flonum racket/flonum))

@title{NLopt}
@author[@author+email["Jay Kominek" "kominek@gmail.com"]]

@section-index["nlopt"]

@(defmodule nlopt)

@margin-note{I consider this package to be in a somewhat beta state.
             I don't yet promise to keep the API from changing. It
             needs some feedback yet. Feel free to comment on it.}

This package provides a wrapper for the NLopt nonlinear optimization
package@cite{NLopt}, which is a common interface for a number of
different optimization routines.

The @racket[nlopt] module currently reexports the contents of
@racket[nlopt/highlevel]. The interface provided by
@racket[nlopt/highlevel] will be more stable than the interface
provided by @racket[nlopt]. The goal of @racket[nlopt] will be to
facilitate interactive programming, scripting, and generally getting
things done quickly with a minimal amount of typing.  If
@racket[nlopt/highlevel] is no longer the best way to do that,
@racket[nlopt] will provide different stuff which better satisfies
those goals, while @racket[nlopt/highlevel] will be left alone.
(Perhaps @racket[nlopt] would reexport a hypothetical new
"@racket[nlopt/highlevel2]".)

@section{Installation}

This Racket wrapper was developed and tested against NLopt 2.4.2; I'd expect
anything later in the 2.4.x series to suffice as well, but there are no
guarantees.

You'll need to get the appropriate NLopt shared library for your Racket
installation. Precompiled Windows binaries are available from the NLopt
website; make sure you download the appropriate bitness.

Many Linux distributions provide NLopt. Look for @tt{libnlopt0} or similar.

In FreeBSD, NLopt is available in the ports collection as @tt{nlopt}.

And on Mac OS X, I believe you're stuck compiling it for yourself.

If you have to compile it yourself, and on Windows, where you're handed a
DLL, you'll need to ensure that the shared library ends up somewhere that
Racket will be able to find it with minimal effort. Placing it in the same
directory as your code might work, or you can modify your @tt{PATH} or
@tt{LD_LIBRARY_PATH} environmental variables to point to it.

@include-section["highlevel.scrbl"]
@include-section["safe.scrbl"]
@include-section["unsafe.scrbl"]
@include-section["algorithms.scrbl"]
