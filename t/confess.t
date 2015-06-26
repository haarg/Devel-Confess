use strict;
use warnings;
BEGIN {
  $ENV{DEVEL_CONFESS_OPTIONS} = '';
}
use Test::More tests => 32;
use t::lib::capture capture => ['-MDevel::Confess'];

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
sub bar {
#line 2 test-block.pl
  foo();
}
#line 3 test-block.pl
bar();
END_CODE
foo at bar
 at test-block.pl line 1.
	main::foo() called at test-block.pl line 2
	main::bar() called at test-block.pl line 3
END_OUTPUT

  like capture <<"END_CODE", qr/\A${\<<'END_OUTPUT'}\z/, "$type with object";
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

  {
    local $ENV{DEVEL_CONFESS_OPTIONS} = 'dump';

    like capture <<"END_CODE", qr/\A${\<<'END_OUTPUT'}\z/, "$type with object + dump";
use Carp;
sub foo {
#line 1 test-block.pl
  $type bless {}, 'NoOverload';
}
#line 2 test-block.pl
foo();
END_CODE
bless\( \{\}, 'NoOverload' \) at test-block\.pl line 1\.
	main::foo\(\) called at test-block\.pl line 2
END_OUTPUT

    is capture <<"END_CODE", <<'END_OUTPUT', "$type with object with overload + dump";
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
  }


  like capture <<"END_CODE", qr/\A${\<<'END_OUTPUT'}\z/, "$type with non-object ref";
use Carp;
sub foo {
#line 1 test-block.pl
  $type [1];
}
#line 2 test-block.pl
foo();
END_CODE
ARRAY\(0x\w+\) at test-block\.pl line 1\.
	main::foo\(\) called at test-block\.pl line 2
END_OUTPUT

  local $ENV{DEVEL_CONFESS_OPTIONS} = 'dump';
  like capture <<"END_CODE", qr/\A${\<<'END_OUTPUT'}\z/, "$type with non-object ref + dump";
use Carp;
sub foo {
#line 1 test-block.pl
  $type [1];
}
#line 2 test-block.pl
foo();
END_CODE
\[1\] at test-block\.pl line 1\.
	main::foo\(\) called at test-block\.pl line 2
END_OUTPUT

  like capture <<"END_CODE", qr/\A${\<<'END_OUTPUT'}\z/, "$type rethrowing non-object ref + dump";
use Carp;
sub foo {
#line 1 test-block.pl
  $type [1];
}
#line 2 test-block.pl
eval { foo() };
print STDERR \$@ . "\n";
die;
END_CODE
ARRAY\(0x\w+\)
\[1\] at test-block\.pl line 1\.
	main::foo\(\) called at test-block\.pl line 2
	eval \{...\} called at test-block.pl line 2
END_OUTPUT

}
