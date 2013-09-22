use strict;
use warnings;
use Test::More tests => 3;
use t::capture;

my $code = <<'END_CODE';
package A;

sub f {
#line 1 test-block.pl
    die  "Beware!";
}

sub g {
#line 2 test-block.pl
    f();
}

package main;

#line 3 test-block.pl
A::g();
END_CODE

my $output = <<'END_OUTPUT';
Beware! at test-block.pl line 1.
	A::f() called at test-block.pl line 2
	A::g() called at test-block.pl line 3
END_OUTPUT
my $debug_output = $output . <<'END_OUTPUT';
 at test-block.pl line 1.
	A::f() called at test-block.pl line 2
	A::g() called at test-block.pl line 3
END_OUTPUT


{
  local @t::capture::OPTS = ('-MDevel::Confess');
  is capture $code, $output, 'Devel::Confess usable as a normal module';
}

{
  local @t::capture::OPTS = ('-d:Confess');
  is capture $code, $output, 'Devel::Confess usable as a debugger';
}

{
  local @t::capture::OPTS = ('-d', '-MDevel::Confess');
  local $ENV{PERLDB_OPTS} = 'NonStop noTTY dieLevel=1';
  is capture $code, $debug_output, 'Devel::Confess usable with the debugger';
}
