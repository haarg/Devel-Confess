use strict;
use warnings;
use Test::More tests => 7;
use File::Temp qw(tempfile);
use IPC::Open3;
use File::Spec;

my @PERL5OPTS = ((map "-I$_", @INC), '-MCarp::Always::AndRefs');

sub capture ($) {
    my ($code) = @_;

    my ($fh, $filename) = tempfile()
      or die "can't open temp file: $!";
    print { $fh } $code;
    close $fh;

    open3( my $in, my $out, undef, $^X, @PERL5OPTS, $filename)
      or die "Couldn't open subprocess: $!\n";
    my $output = do { local $/; <$out> };
    close $in;
    close $out;

    unlink $filename
      or die "Couldn't unlink $filename: $!\n";

    $output =~ s/\.?$/./m;
    return $output;
}

is capture <<'END_CODE', <<'END_OUTPUT', 'basic test';
package A;

sub f {
#line 1 test-block.pl
    warn  "Beware!";
}

sub g {
#line 2 test-block.pl
    f();
}

package main;

#line 3 test-block.pl
A::g();
END_CODE
Beware! at test-block.pl line 1.
	A::f() called at test-block.pl line 2
	A::g() called at test-block.pl line 3
END_OUTPUT

is capture <<'END_CODE', <<'END_OUTPUT', 'interpreter-thrown warnings';
package A;

sub f {
	use strict;
	my $a;
#line 1 test-block.pl
	my @a = @$a;
}

sub g {
#line 2 test-block.pl
	f();
}

package main;

#line 3 test-block.pl
A::g();

END_CODE
Can't use an undefined value as an ARRAY reference at test-block.pl line 1.
	A::f() called at test-block.pl line 2
	A::g() called at test-block.pl line 3
END_OUTPUT

is capture <<'END_CODE' , <<'END_OUTPUT', 'foo at bar';
#line 1 test-block.pl
die "foo at bar"
END_CODE
foo at bar at test-block.pl line 1.
END_OUTPUT

is capture <<'END_CODE' , <<'END_OUTPUT', 'croak';
use Carp;
#line 1 test-block.pl
croak "foo at bar"
END_CODE
foo at bar at test-block.pl line 1.
END_OUTPUT

is capture <<'END_CODE', <<'END_OUTPUT', 'confess';
use Carp;
#line 1 test-block.pl
confess "foo at bar"
END_CODE
foo at bar at test-block.pl line 1.
END_OUTPUT

like capture <<'END_CODE', qr/${\<<'END_OUTPUT'}/, 'object';
#line 1 test-block.pl
die bless {}, 'NoOverload';
END_CODE
^NoOverload=HASH\(0x\w+\) at test-block.pl line 1.
END_OUTPUT

is capture <<'END_CODE', <<'END_OUTPUT', 'object with overload';
{
  package HasOverload;
  use overload '""' => sub { "message" };
}
#line 1 test-block.pl
die bless {}, 'HasOverload';
END_CODE
message at test-block.pl line 1.
END_OUTPUT
