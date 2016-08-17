use strict;
use warnings;
BEGIN {
  $ENV{DEVEL_CONFESS_OPTIONS} = '';
}
use Test::More tests => 3;

use Devel::Confess qw(evalsource);

my $file = __FILE__;
my @evals;

sub Foo::foo {
  die "error";
}

sub Bar::bar {
  push @evals, 'Foo::foo()';
  eval $evals[-1];
  die $@ if $@;
}

push @evals, 'sub Baz::baz { Bar::bar() } 1;';
eval $evals[-1] or die $@;

eval { Baz::baz() };

for my $eval (@evals) {
  ok $@ =~ /context for \(eval \d+\).* line 1:\n\s*1 :.*\Q$eval\E/,
    'trace includes eval text';
}

ok $@ !~ /context for \Q$file\E/,
  'trace only includes eval frames';
