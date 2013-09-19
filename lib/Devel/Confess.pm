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

=head1 NAME

Devel::Confess - Include stack track on all warnings and errors

=head1 SYNOPSIS

  perl -MDevel::Confess script.pl

  perl -d:Confess script.pl

=head1 DESCRIPTION

This module just provides a shorter name for L<Carp::Always::AndRefs>.
It also enables the L<Carp::Always::AndRefs::Hacks> module.

=cut
