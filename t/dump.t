use strict;
use warnings;
use Carp ();
use Test::More defined &Carp::format_arg
  ? (tests => 2)
  : (skip_all => 'Dump option not supported on ancient carp');

use Devel::Confess qw(dump);

sub Foo::foo {
  die "error";
}

sub Bar::bar {
  Foo::foo(@_);
}

sub Baz::baz {
  Bar::bar(@_);
}

eval { Baz::baz([1]) };
like $@, qr/Foo::foo\(\[1\]\)/, 'references are dumped in arguments';

eval { Baz::baz(["yarp\nnarp"]) };
like $@, qr/Foo::foo\(\["yarp\\nnarp"\]\)/, 'newlines are dumped in escaped form';
