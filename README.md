# k-circus-semantics

This implementation of the Circus operational semantics was developed during my stay as a visiting researcher at LRI-France.

The full documentation for this piece of work can be found in the following technical report:
https://hal.science/hal-01438386/

It is part of my PhD thesis, available at:
https://www.teses.usp.br/teses/disponiveis/55/55134/tde-04012019-112931/en.php

The command line to build it and run a pretty-printed example is:
  $rm -rf circus-kompiled/ && kompile circus.k && krun \
  teste.circus   | xmllint --format -

K-framework used to test was a nightly built version 4 (in 2017)