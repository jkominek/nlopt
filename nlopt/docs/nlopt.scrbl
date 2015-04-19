#lang scribble/manual

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

@section{High Level Interface}

@margin-note{This is the most unstable part of the package.}

@include-section["safe.scrbl"]
@include-section["unsafe.scrbl"]
@include-section["algorithms.scrbl"]
