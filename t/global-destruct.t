use strict;
use warnings;
no warnings 'once';
use Test::More tests => 1;
Test::More->builder->no_ending(1);
use Devel::Confess;
use POSIX ();

{
  package MyException;
  use overload
    fallback => 1,
    '""' => sub {
      $_[0]->{message};
    },
  ;
  sub new {
    my ($class, $message) = @_;
    my $self = bless { message => $message }, $class;
    return $self;
  }
}

sub foo {
  eval { die MyException->new("yarp") };
  $@;
}

sub bar {
  foo();
}

our $ex = bar();
my $stringy = "$ex";

# gd order is unpredictable, try multiple times
our $last01 = bless {}, 'InGD';
our $last02 = bless {}, 'InGD';
our $last03 = bless {}, 'InGD';
our $last04 = bless {}, 'InGD';

sub InGD::DESTROY {
  if (!defined $ex) {
    SKIP: {
      skip "got unlucky on GD order, can't test", 1;
    }
  }
  else {
    my $gd_stringy = "$ex";
    is $gd_stringy, $stringy,
      "stringifies properly in global destruction"
        or POSIX::_exit(1);
  }
  POSIX::_exit(0);
}
