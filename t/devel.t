use strict;
use warnings;
use Test::More tests => 2;
use t::lib::capture;
use Cwd qw(cwd);

my $code = <<'END_CODE';
BEGIN { print STDERR "started\n" }
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

my $expected = <<'END_OUTPUT';
Beware! at test-block.pl line 1.
	A::f() called at test-block.pl line 2
	A::g() called at test-block.pl line 3
END_OUTPUT

{
  local @CAPTURE_OPTS = ('-d:Confess');
  my $out = capture $code;
  $out =~ s/\A.*?^started\s+//ms;
  is $out, $expected, 'Devel::Confess usable as a debugger';
}

{
  local @CAPTURE_OPTS = ('-d', '-MDevel::Confess');

  local %ENV = %ENV;
  delete $ENV{$_} for grep /^PERL5?DB/, keys %ENV;
  delete $ENV{LOGDIR};
  $ENV{HOME} = cwd;
  $ENV{PERLDB_OPTS} = 'NonStop noTTY dieLevel=0';
  my $out = capture $code;
  $out =~ s/\A.*?^started\s+//ms;
  is $out, $expected, 'Devel::Confess usable with the debugger';
}
