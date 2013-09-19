package Carp::Always::WithRefs::Hacks;
use strict;
use warnings FATAL => 'all';
no warnings 'once';

{
  package #hide
    Carp::Always::WithRefs::Hacks::_Guard;
  use overload bool => sub () { 0 };
  sub new { bless [$_[1]], $_[0] }
  sub DESTROY { $_[0][0]->() if @{$_[0]} }
}

sub guard (&) {
  Carp::Always::WithRefs::Hacks::_Guard->new(@_);
}

$Carp::Always::WithRefs::NoTrace{'Exception::Class::Base'}++;
{
  my $guard = guard { Exception::Class::Base->Trace(1) };
  if (!$INC{'Exception/Class/Base.pm'}) {
    $Exception::Class::BASE_EXC_CLASS = $guard;
  }
}

$Carp::Always::WithRefs::NoTrace{'Ouch'}++;
{
  my $guard = guard { overload::OVERLOAD('Ouch', '""', 'trace') };
  if (!$INC{'Ouch.pm'}) {
    $Ouch::EXPORT_OK = ($guard);
  }
}

$Carp::Always::WithRefs::NoTrace{'Class::Throwable'}++;
{
  my $guard = guard { $Class::Throwable::DEFAULT_VERBOSITY = 2 };
  if (!$INC{'Class/Throwable.pm'}) {
    $Class::Throwable::DEFAULT_VERBOSITY = $guard;
  }
}

$Carp::Always::WithRefs::NoTrace{'Exception::Base'}++;
{
  my $guard = guard { Exception::Base->import(verbosity => 3) };
  if (!$INC{'Exception/Base.pm'}) {
    overload::OVERLOAD('Exception::Base', '""', sub { $guard });
  }
}

$Carp::Always::WithRefs::NoTrace{'Error'}++;
{
  my $guard = guard { $Error::Debug = 1 };
  if (!$INC{'Error.pm'}) {
    $Error::Debug = $guard;
  }
}

1;
__END__

=head1 NAME

Carp::Always::WithRefs::Hacks - Enable built in stack traces on exception objects

=head1 SYNOPSIS

  use Carp::Always::WithRefs::Hacks;
  use Exception::Class 'MyException';

  MyException->throw; # includes stack trace

=head1 DESCRIPTION

Many existing exception module can provide stack traces, but this
is often not the default setting.  This module will force as many
modules as possible to include stack traces by default.  It can be
loaded before or after the exception modules, and it will still
function.

=head1 SUPPORTED MODULES

=over 4

=item *

L<Exception::Class>

=item *

L<Ouch>

=item *

L<Class::Throwable>

=item *

L<Exception::Base>

=item *

L<Error>

=back

=head1 CAVEATS

This module relies partly on the internal implementation of the
modules it effects.  Future updates to the modules could break or
be broken by this module.

=cut
