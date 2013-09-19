package Devel::Confess;
use strict;
use warnings;

use Carp::Always::EvenObjects ();
our @ISA = qw(Carp::Always::EvenObjects);

sub import {
  $_[0]->SUPER::import(-hacks, @_[1..$#_]);
}

# allow -d:Confess
if (!defined &DB::DB) {
  *DB::DB = sub {};
}

1;

=head1 NAME

Devel::Confess - Include stack track on all warnings and errors

=head1 SYNOPSIS

  perl -MDevel::Confess script.pl

  perl -d:Confess script.pl

=head1 DESCRIPTION

This module just provides a shorter name for L<Carp::Always::EvenObjects>.
It also enables the L<Carp::Always::EvenObjects::Hacks> module.

=cut
