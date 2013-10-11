use strict;
use warnings;
use Test::More tests => 1;
use t::lib::capture;

$ENV{DEVEL_CONFESS_COLOR} = 1;
my $code = <<'END_CODE';
package A;

sub f {
#line 1 test-block.pl
    die "Beware!";
}

sub g {
#line 2 test-block.pl
    f();
}

package main;

#line 3 test-block.pl
A::g();
END_CODE

my $expected = <<"END_OUTPUT";
\e[31mBeware!\e[m at test-block.pl line 1.
	A::f() called at test-block.pl line 2
	A::g() called at test-block.pl line 3
END_OUTPUT

{
  local @CAPTURE_OPTS = ('-MDevel::Confess=color');
  my $out = capture $code;
  is $out, $expected, 'error message properly colorized';
}

