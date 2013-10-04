use strict;
use warnings;
use Test::More tests => 20;
use t::capture;

@t::capture::OPTS = ('-MDevel::Confess');

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

for my $type (qw(die croak confess)) {

  is capture <<"END_CODE" , <<'END_OUTPUT', "$type at root";
use Carp;
#line 1 test-block.pl
$type "foo at bar";
END_CODE
foo at bar at test-block.pl line 1.
END_OUTPUT

  is capture <<"END_CODE" , <<'END_OUTPUT', "$type in sub";
use Carp;
sub foo {
#line 1 test-block.pl
  $type "foo at bar";
}
#line 2 test-block.pl
foo();
END_CODE
foo at bar at test-block.pl line 1.
	main::foo() called at test-block.pl line 2
END_OUTPUT

  is capture <<"END_CODE" , <<'END_OUTPUT', "$type with newline";
use Carp;
sub foo {
#line 1 test-block.pl
  $type "foo at bar\n";
}
#line 2 test-block.pl
foo();
END_CODE
foo at bar
 at test-block.pl line 1.
	main::foo() called at test-block.pl line 2
END_OUTPUT

  like capture <<"END_CODE", qr/${\<<'END_OUTPUT'}/, "$type with object";
use Carp;
sub foo {
#line 1 test-block.pl
  $type bless {}, 'NoOverload';
}
#line 2 test-block.pl
foo();
END_CODE
NoOverload=HASH\(0x\w+\) at test-block\.pl line 1\.
	main::foo\(\) called at test-block\.pl line 2
END_OUTPUT

  is capture <<"END_CODE", <<'END_OUTPUT', "$type with object with overload";
use Carp;
{
  package HasOverload;
  use overload '""' => sub { "message" };
}
sub foo {
#line 1 test-block.pl
  $type bless {}, 'HasOverload';
}
#line 2 test-block.pl
foo();
END_CODE
message at test-block.pl line 1.
	main::foo() called at test-block.pl line 2
END_OUTPUT

  like capture <<"END_CODE", qr/${\<<'END_OUTPUT'}/, "$type with non-object ref";
use Carp;
sub foo {
#line 1 test-block.pl
  $type [1];
}
#line 2 test-block.pl
foo();
END_CODE
^ARRAY\(0x\w+\) at test-block\.pl line 1\.
	main::foo\(\) called at test-block\.pl line 2
END_OUTPUT

}
