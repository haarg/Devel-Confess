use strict;
use warnings;
use Test::More;
use t::lib::capture
  'capture',
  capture_builtin => ['-MDevel::Confess::Builtin'],
;
use Devel::Confess::Builtin ();

my @class = (
  'Exception::Class' => {
    declare => 'use Exception::Class qw(MyException);',
    throw   => 'MyException->throw("nope");',
  },
  'Ouch' => {
    throw   => 'Ouch::ouch(100, "nope");',
  },
  'Class::Throwable' => {
    throw   => 'Class::Throwable->throw("nope");',
  },
  'Exception::Base' => {
    declare => 'use Exception::Base qw(MyException);',
    throw   => 'MyException->throw("nope");',
  },
);

plan tests => scalar @class;

while (@class) {
  my ($class, $info) = splice @class, 0, 2;
  (my $module = "$class.pm") =~ s{::}{/}g;
  require $module;
  my $declare = $info->{declare} || "use $class;";
  my $code = <<END;
$declare

package A;
sub f {
$info->{throw}
}
package B;
sub g {
A::f();
}
END
  my $before = capture_builtin $code.'B::g();';
  my $after = capture $code.'require Devel::Confess::Builtin;Devel::Confess::Builtin->import(); B::g();';
  like $before, qr/B::g/, "verbose when loaded before $class";
  like $after, qr/B::g/, "verbose when loaded after $class";
}
