use strict;
use warnings;
BEGIN {
  $ENV{DEVEL_CONFESS_OPTIONS} = '';
}
use UNIVERSAL::isa;
use UNIVERSAL::can;
use Carp ();
use Carp::Heavy ();
use Test::More tests => 1;

use Devel::Confess qw(nowarnings);

{
  package Thing1;
  sub isa { UNIVERSAL::isa(@_) }
  sub can { UNIVERSAL::can(@_) }
}

my @warnings;
my $o = bless {}, 'Thing1';
local $SIG{__WARN__} = sub { push @warnings, $_[0] };
eval {
  die $o;
};
eval {
  die $o;
};

is join('', @warnings), '',
  "no warnings produced from error class with overridden can";
