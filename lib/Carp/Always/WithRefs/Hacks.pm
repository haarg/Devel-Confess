package Carp::Always::WithRefs::Hacks;
use strict;
use warnings FATAL => 'all';
no warnings 'once';

{
  package #hide
    Carp::Always::WithRefs::_Guard;
  use overload bool => sub { 0 };
  sub new { bless [$_[1]], $_[0] }
  sub DESTROY { $_[0][0]->(); }
}

sub guard (&) {
  Carp::Always::WithRefs::_Guard->new(@_);
}

$Carp::Always::WithRefs::NoTrace{'Exception::Class::Base'}++;
{
  my $guard = guard { Exception::Class::Base->Trace(1) };
  if (!$INC{'Exception/Class/Base.pm'}) {
    $Exception::Class::BASE_EXC_CLASS = $guard;
  }
}

{
  my $guard = guard { overload::OVERLOAD('Ouch', '""', 'trace') };
  if (!$INC{'Ouch.pm'}) {
    $Ouch::EXPORT_OK = ($guard);
  }
}

1;

