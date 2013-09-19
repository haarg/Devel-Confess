package Devel::Confess;
use strict;
use warnings;

use Carp::Always::AndRefs ();
our @ISA = qw(Carp::Always::AndRefs);

sub import {
  $_[0]->SUPER::import(-hacks, @_[1..$#_]);
}

{
  package # hide
    DB;

  # allow -d:Confess
  sub DB {}
}

1;
