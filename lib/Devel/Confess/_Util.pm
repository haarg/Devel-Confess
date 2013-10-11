package Devel::Confess::_Util;
use 5.006;
use strict;
use warnings FATAL => 'all';
no warnings 'once';

use base 'Exporter';

our @EXPORT = qw(blessed refaddr weaken longmess);

use Carp ();
use Scalar::Util qw(blessed refaddr);

# fake weaken if it isn't available.  will cause leaks, but this
# is a brute force debugging tool, so we can deal with it.
*weaken = defined &Scalar::Util::weaken
  ? \&Scalar::Util::weaken
  : sub ($) { 0 };

*longmess = $Carp::VERSION ? \&Carp::longmess : sub {
  my $level = 0;
  $level++ while ((caller($level))[0] =~ /^Carp(?:::|$)|^Devel::Confess/);
  local $Carp::CarpLevel = $Carp::CarpLevel + $level;
  &Carp::longmess;
};

if ($Carp::VERSION && $Carp::VERSION < 1.32) {
  my $format_arg = \&Carp::format_arg;
  eval q{
    package
      Carp;
    our $in_recurse;
    no warnings 'redefine';
    sub format_arg {
      if (! $in_recurse) {
        local $SIG{__DIE__} = sub {};
        local $in_recurse = 1;
        local $@;

        my $arg;
        if (
          Scalar::Util::blessed($_[0])
          && eval { $_[0]->can('CARP_TRACE') }
        ) {
          return $_[0]->CARP_TRACE;
        }
        elsif (
          ref $_[0]
          && our $RefArgFormatter
          && eval { $arg = $RefArgFormatter->(@_); 1 }
        ) {
          return $arg;
        }
      }
      $format_arg->(@_);
    }
  };
}

1;
