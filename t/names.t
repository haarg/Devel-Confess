use strict;
use warnings;
use Devel::Confess ();
use Test::More
  Devel::Confess::_CAN_USE_INFORMATIVE_NAMES ? (tests => 2)
  : (skip_all => "Can't enable better names at runtime on perl < 5.8");

use Devel::Confess qw(better_names);

sub foo {
  die "welp";
}

my $bar = sub {
  foo();
};

sub baz {
  $bar->();
}

eval q{ baz; };
my $err = $@;

Devel::Confess->unimport;

my $file = quotemeta __FILE__;

my @lines = split /\n/, $err;

like $lines[2], qr/main::__ANON__\[$file:\d+\]\(\) called at/,
  'anonymous function names include file and line number';

like $lines[4], qr/baz;/,
  'string evals include eval text';
