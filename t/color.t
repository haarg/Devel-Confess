use strict;
use warnings;
use Test::More;
use t::lib::capture capture_color => ['-MDevel::Confess=color'];

if ($^O eq 'MSWin32') {
  plan skip_all => 'color option requires Win32::Console::ANSI in Windows'
    unless eval { require Win32::Console::ANSI; };
}
plan tests => 1;

$ENV{DEVEL_CONFESS_FORCE_COLOR} = 1;
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
  my $out = capture_color $code;
  is $out, $expected, 'error message properly colorized';
}

