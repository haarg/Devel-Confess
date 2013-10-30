use strict;
use warnings;
use Test::More tests => 8;

use Devel::Confess ();

ok !$SIG{__DIE__}, 'not activated without import';
my $called;
sub CALLED { $called++ };
$SIG{__DIE__} = \&CALLED;
Devel::Confess->import;
isnt $SIG{__DIE__}, \&CALLED, 'import overwrites existing __DIE__ handler';
eval { die };
is $called, 1, 'calls outer __DIE__ handler';
Devel::Confess->unimport;
is $SIG{__DIE__}, \&CALLED, 'unimport restores __DIE__ handler';

sub IGNORE { $called++ }
sub DEFAULT { $called++ }
sub other::sub { $called++ }

$SIG{__DIE__} = 'IGNORE';
Devel::Confess->import;
eval { die };
is $called, 1, 'no dispatching to IGNORE';
Devel::Confess->unimport;

$SIG{__DIE__} = 'DEFAULT';
Devel::Confess->import;
eval { die };
is $called, 1, 'no dispatching to DEFAULT';
Devel::Confess->unimport;

$SIG{__DIE__} = 'CALLED';
Devel::Confess->import;
eval { die };
is $called, 2, 'dispatches by name';
Devel::Confess->unimport;

$SIG{__DIE__} = 'other::sub';
Devel::Confess->import;
eval { die };
is $called, 3, 'dispatches by name to package sub';
Devel::Confess->unimport;
