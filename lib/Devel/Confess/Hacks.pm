package Devel::Confess::Hacks;
use strict;
use warnings FATAL => 'all';
no warnings 'once';

our $VERSION = '0.003001';
$VERSION = eval $VERSION;

{
  our $gd;
  sub _global_destruction () {
    if (!$gd) {
      local $SIG{__WARN__} = sub { $gd = $_[0] =~ /global destruction\.\n\z/ };
      warn 1;
    }
    $gd;
  }
}

{
  package #hide
    Devel::Confess::Hacks::_Guard;
  use overload bool => sub () { 0 };
  sub new { bless [@_[1 .. $#_]], $_[0] }
  sub DESTROY {
    return
      if Devel::Confess::Hacks::_global_destruction;
    $_->() for @{$_[0]}
  }
}

our %HACKS = (
  'Exception::Class::Base' => {
    enable => sub { Exception::Class::Base->Trace(1) },
    store => '$Exception::Class::BASE_EXC_CLASS',
  },
  'Ouch' => {
    enable => sub { overload::OVERLOAD('Ouch', '""', 'trace') },
    store => '@Ouch::EXPORT_OK',
  },
  'Class::Throwable' => {
    enable => sub { $Class::Throwable::DEFAULT_VERBOSITY = 2 },
    store => '$Class::Throwable::DEFAULT_VERBOSITY',
  },
  'Exception::Base' => {
    enable => sub { Exception::Base->import(verbosity => 3) },
    store => '$Exception::Base::_qualify_to_ref'
  },
  'Error' => {
    enable => sub { $Error::Debug = 1 },
    store => '$Error::Debug',
  },
);

sub import {
  my ($class, @enable) = @_;
  @enable = keys %HACKS
    unless @enable;

  for my $class (@enable) {
    my $hack = $HACKS{$class} or die "invalid class $class!";
    next if $hack->{enabled};

    (my $module = "$class.pm") =~ s{::}{/}g;
    if ($INC{$module}) {
      $hack->{enable}->();
      $Devel::Confess::NoTrace{$class}++;
    }
    else {
      my $store = $hack->{store};
      my $guard = Devel::Confess::Hacks::_Guard->new(
        $hack->{enable},
        sub { $Devel::Confess::NoTrace{$class}++ },
      );

      if (ref $store) {
        $store->($guard);
      }
      else {
        eval $store . ' = $guard; 1' or die $@;
      }
    }

    $hack->{enabled}++;
  }
}

sub unimport {
  my ($class, @disable) = @_;
  @disable = keys %HACKS
    unless @disable;

  for my $class (@disable) {
    my $hack = $HACKS{$class} or die "invalid class $class!";
    next unless $hack->{enabled};

    (my $module = "$class.pm") =~ s{::}{/}g;
    if ($INC{$module}) {
      # can't really disable if it's already been loaded, so just do nothing
    }
    else {
      my $store = $hack->{store};
      if (ref $store) {
        $hack->{disable}->();
      }
      else {
        eval q{
          my ($guard) = }.$store.q{;
          @$guard = ();
          }.$store.q{ = ();
          1;
        } or die $@;
      }
      $hack->{enabled}--;
      $Devel::Confess::NoTrace{$class}--;
    }
  }
}

1;
__END__

=head1 NAME

Devel::Confess::Hacks - Enable built in stack traces on exception objects

=head1 SYNOPSIS

  use Devel::Confess::Hacks;
  use Exception::Class 'MyException';

  MyException->throw; # includes stack trace

=head1 DESCRIPTION

Many existing exception module can provide stack traces, but this
is often not the default setting.  This module will force as many
modules as possible to include stack traces by default.  It can be
loaded before or after the exception modules, and it will still
function.

For supported modules, it will also prevent L<Devel::Confess>
from attaching its own stack traces.

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
