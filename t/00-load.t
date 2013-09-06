use strict;
use Test::More;
use File::Find;

my @modules;
find({
  no_chdir => 1,
  wanted => sub {
    return unless -f && s/\.pm$//;
    s{^lib/}{};
    s{/}{::}g;
    push @modules, $_;
  },
}, 'lib');

plan tests => scalar @modules;
grep { !require_ok($_) } @modules
  and BAIL_OUT('Compile error!');
