use strict;
use warnings;
use Test::More;
use t::lib::capture;
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
  SKIP: {
    my ($class, $info) = splice @class, 0, 2;
    (my $module = "$class.pm") =~ s{::}{/}g;
    eval { require $module } or skip "$class not installed", 2;
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
    @CAPTURE_OPTS = ('-MDevel::Confess::Builtin');
    my $before = capture $code.'B::g();';
    @CAPTURE_OPTS = ();
    my $after = capture $code.'require Devel::Confess::Builtin;Devel::Confess::Builtin->import(); B::g();';
    like $before, qr/B::g/, "verbose when loaded before $class";
    like $after, qr/B::g/, "verbose when loaded after $class";
  }
}
