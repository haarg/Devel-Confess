package Carp::Always::WithRefs;
use 5.006;
use strict;
use warnings;

use Carp qw(verbose); # makes carp() cluck and croak() confess
use Moo::Role ();
use overload ();

sub _warn {
  if ($_[-1] =~ /\n$/s) {
    my $arg = pop @_;
    $arg =~ s/(.*)( at .*? line .*?\n$)/$1/s;
    push @_, $arg;
  }
  warn &Carp::longmess;
}
$Carp::Internal{+__PACKAGE__}++;

sub _die {
  if (ref $_[0]) {
    my $ex = $_[0];
    my $stringify = overload::Method($ex, '""');
    Moo::Role->apply_roles_to_object($ex, 'Carp::Always::WithRefs::AttachTrace');
    $ex->_stringify($stringify);
    $ex->_trace(Carp::longmess);
    die $ex;
  }
  if ($_[-1] =~ /\n$/s) {
    my $arg = pop @_;
    $arg =~ s/(.*)( at .*? line .*?\n$)/$1/s;
    push @_, $arg;
  }
  die &Carp::longmess;
}

my %OLD_SIG;

BEGIN {
  @OLD_SIG{qw(__DIE__ __WARN__)} = @SIG{qw(__DIE__ __WARN__)};
  $SIG{__DIE__} = \&_die;
  $SIG{__WARN__} = \&_warn;
}

END {
  @SIG{qw(__DIE__ __WARN__)} = @OLD_SIG{qw(__DIE__ __WARN__)};
}

{
  package Carp::Always::WithRefs::AttachTrace;
  use Moo::Role;
  has _stringify => (is => 'rw');
  has _trace => (is => 'rw');
  use overload '""' => sub {
    my $self = shift;
    my $stringify = $self->_stringify || \&overload::StrVal;
    return ($self->$stringify . $self->_trace);
  };
}

1;
