#lang scribble/manual

@title{NLopt}
@author[@author+email["Jay Kominek" "kominek@gmail.com"]]

@section-index["nlopt"]

@(defmodule nlopt)

@margin-note{I consider this wrapper unstable, currently.
             I fully intend to make API changes. Hopefully
             they'll improve the situation.}

This package provides a wrapper for the NLopt nonlinear optimization
package@cite{NLopt}, which is a common interface for a number of
different optimization routines.

@include-section["safe.scrbl"]
@include-section["unsafe.scrbl"]
@include-section["algorithms.scrbl"]
