package Devel::Confess::Builtin;
use strict;
use warnings FATAL => 'all';
no warnings 'once';

our $VERSION = '0.005000';
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
    Devel::Confess::Builtin::_Guard;
  use overload bool => sub () { 0 };
  sub new { bless [@_[1 .. $#_]], $_[0] }
  sub DESTROY {
    return
      if Devel::Confess::Builtin::_global_destruction;
    $_->() for @{$_[0]}
  }
}

our %CLASS = (
  'Exception::Class::Base' => {
    enable => sub { Exception::Class::Base->Trace(1) },
    store => '$Exception::Class::BASE_EXC_CLASS',
    check => sub { $_[0]->Trace },
  },
  'Ouch' => {
    enable => sub { overload::OVERLOAD('Ouch', '""', 'trace') },
    store => '@Ouch::EXPORT_OK',
  },
  'Class::Throwable' => {
    enable => sub { $Class::Throwable::DEFAULT_VERBOSITY = 2 },
    store => '$Class::Throwable::DEFAULT_VERBOSITY',
    check => sub {
      my $class = ref shift;
      our $CT_VERBOSITY ||= do {
        my $v;
        my $pad = B::svref_2object(Class::Throwable->can('import'))->PADLIST;
        for (0..$pad->ARRAYelt(0)->MAX) {
          if ($pad->ARRAYelt(0)->ARRAYelt($_)->isa('B::PV')
            && $pad->ARRAYelt(0)->ARRAYelt($_)->PV eq '%VERBOSITY') {
            $v = $pad->ARRAYelt(1)->ARRAYelt($_)->object_2svref;
          }
        }
        $v;
      };
      return exists $CT_VERBOSITY->{$class}
        ? $CT_VERBOSITY->{$class}
        : $Class::Throwable::DEFAULT_VERBOSITY;
    },
  },
  'Exception::Base' => {
    enable => sub { Exception::Base->import(verbosity => 3) },
    store => sub {
      my $guard = shift;
      $Exception::Base::_qualify_to_ref
          = Devel::Confess::Builtin::_Guard->new(sub {
        $Exception::Base::VERSION = $guard;
      });
    },
    check => sub { $_[0]->verbosity >= 3 },
  },
);

sub import {
  my ($class, @enable) = @_;
  @enable = keys %CLASS
    unless @enable;

  for my $class (@enable) {
    my $class_data = $CLASS{$class} or die "invalid class $class!";
    next if $class_data->{enabled};

    (my $module = "$class.pm") =~ s{::}{/}g;
    if ($INC{$module}) {
      $class_data->{enable}->();
      $Devel::Confess::NoTrace{$class}++;
    }
    else {
      my $store = $class_data->{store};
      my $guard = Devel::Confess::Builtin::_Guard->new(
        $class_data->{enable},
        sub { $Devel::Confess::NoTrace{$class}++ },
      );

      if (ref $store) {
        $store->($guard);
      }
      else {
        eval $store . ' = $guard; 1' or die $@;
      }
    }

    $class_data->{enabled}++;
  }
}

sub unimport {
  my ($class, @disable) = @_;
  @disable = keys %CLASS
    unless @disable;

  for my $class (@disable) {
    my $class_data = $CLASS{$class} or die "invalid class $class!";
    next unless $class_data->{enabled};

    (my $module = "$class.pm") =~ s{::}{/}g;
    if ($INC{$module}) {
      # can't really disable if it's already been loaded, so just do nothing
    }
    else {
      my $store = $class_data->{store};
      if (ref $store) {
        $class_data->{disable}->();
      }
      else {
        eval q{
          my ($guard) = }.$store.q{;
          @$guard = ();
          }.$store.q{ = ();
          1;
        } or die $@;
      }
      $class_data->{enabled}--;
      $Devel::Confess::NoTrace{$class}--;
    }
  }
}

sub check {
  my ($class, $ex) = @_;
  my $does = $ex->can('does') || $ex->can('DOES') || sub () { 0 };
  for (grep { $HACKS{$_}{check} and $ex->isa($_) || $ex->$does($_) } keys %HACKS) {
    return 1
      if $HACKS{$_}{check}->($_);
  }
  return;
}

1;
__END__

=head1 NAME

Devel::Confess::Builtin - Enable built in stack traces on exception objects

=head1 SYNOPSIS

  use Devel::Confess::Builtin;
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

=back

=head1 CAVEATS

This module relies partly on the internal implementation of the
modules it effects.  Future updates to the modules could break or
be broken by this module.

=cut
