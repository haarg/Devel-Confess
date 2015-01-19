use Config;
BEGIN {
  unless ($Config{useithreads}) {
    print "1..0 # SKIP your perl does not support ithreads\n";
    exit 0;
  }
}
use threads;
use strict;
use warnings;
use Test::More tests => 1;
use Devel::Confess;

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

my $ex = bar();

my $stringy_ex = "$ex";

my $stringy_from_thread = threads->create(sub {
  "$ex";
})->join;

is $stringy_from_thread, $stringy_ex,
  'stack trace maintained across threads';
