use strict;
use warnings;
use Test::More
  eval { require Carp::Source } ? (tests => 3)
    : skip_all => "source feature requires Carp::Source";

use Devel::Confess qw(source);

my $file = __FILE__;
my @lines;

sub Foo::foo {
  push @lines, __LINE__; die "error";
}

sub Bar::bar {
  push @lines, __LINE__; Foo::foo(@_);
}

sub Baz::baz {
  push @lines, __LINE__; Bar::bar(@_);
}

eval { Baz::baz([1]) };

for my $line (@lines) {
  ok $@ =~ /context for \Q$file\E line $line:/, 'trace includes required line';
}

