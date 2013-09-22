use strict;
use warnings;
use Test::More tests => 8;

use Carp::Always::EvenObjects ();

is $SIG{__DIE__}, undef, 'not activated without import';
my $called;
sub CALLED { $called++ };
$SIG{__DIE__} = \&CALLED;
Carp::Always::EvenObjects->import;
isnt $SIG{__DIE__}, \&CALLED, 'import overwrites existing __DIE__ handler';
eval { die };
is $called, 1, 'dispatches to outer __DIE__ handler';
Carp::Always::EvenObjects->unimport;
is $SIG{__DIE__}, \&CALLED, 'unimport restores __DIE__ handler';

sub IGNORE { $called++ }
sub DEFAULT { $called++ }
sub other::sub { $called++ }

$SIG{__DIE__} = 'IGNORE';
Carp::Always::EvenObjects->import;
eval { die };
is $called, 1, 'no dispatching to IGNORE';
Carp::Always::EvenObjects->unimport;

$SIG{__DIE__} = 'DEFAULT';
Carp::Always::EvenObjects->import;
eval { die };
is $called, 1, 'no dispatching to DEFAULT';
Carp::Always::EvenObjects->unimport;

$SIG{__DIE__} = 'CALLED';
Carp::Always::EvenObjects->import;
eval { die };
is $called, 2, 'dispatches by name';
Carp::Always::EvenObjects->unimport;

$SIG{__DIE__} = 'other::sub';
Carp::Always::EvenObjects->import;
eval { die };
is $called, 3, 'dispatches by name to package sub';
Carp::Always::EvenObjects->unimport;
