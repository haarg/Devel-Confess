package Devel::Confess::_Util;
use 5.006;
use strict;
use warnings;
no warnings 'once';

use Exporter (); BEGIN { *import = \&Exporter::import }

our @EXPORT = qw(
  blessed
  refaddr
  weaken
  longmess
  _str_val
  _in_END
  _can_stringify
  _can
  _isa
);

use Carp ();
use Carp::Heavy ();
use Scalar::Util qw(blessed refaddr reftype);

# fake weaken if it isn't available.  will cause leaks, but this
# is a brute force debugging tool, so we can deal with it.
sub weaken ($);
*weaken = defined &Scalar::Util::weaken
  ? \&Scalar::Util::weaken
  : sub ($) { 0 };

sub longmess;
if (!Carp->VERSION) {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    package
      Carp;
    our (%CarpInternal, %Internal, $CarpLevel);
    $CarpInternal{'Carp'} ||= 1;
    $CarpInternal{'warnings'} ||= 1;
    $Internal{'Exporter'} ||= 1;
    $Internal{'Exporter::Heavy'} ||= 1;

    sub Devel::Confess::_Util::longmess {
      my $level = 0;
      while (1) {
        my $p = (caller($level))[0] || last;
        last
          unless $CarpInternal{$p} || $Internal{$p};
        $level++;
      }
      local $CarpLevel = $CarpLevel + $level;
      no strict 'refs';
      local *{"threads::tid"} = \&threads::tid
        if defined &threads::tid && !defined &{"threads::tid"};
      &longmess;
    }

    1;
  } or die $@;
}
else {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    package
      Carp;

    sub Devel::Confess::_Util::longmess {
      local $INC{'Carp/Heavy.pm'} = $INC{'Carp/Heavy.pm'} || 1;
      no strict 'refs';
      local *{"threads::tid"} = \&threads::tid
        if defined &threads::tid && !defined &{"threads::tid"};
      &longmess;
    }

    1;
  } or die $@;
}

if (defined &Carp::format_arg && $Carp::VERSION < 1.32) {
  my $format_arg = \&Carp::format_arg;
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    package
      Carp;
    our $in_recurse;
    $format_arg if 0; # capture for 5.6
    no warnings 'redefine';
    sub format_arg {
      if (! $in_recurse) {
        local $SIG{__DIE__} = sub {};
        local $in_recurse = 1;
        local $@;

        my $arg;
        if (
          Devel::Confess::_Util::blessed($_[0])
          && eval { $_[0]->can('CARP_TRACE') }
        ) {
          return $_[0]->CARP_TRACE;
        }
        elsif (
          ref $_[0]
          and our $RefArgFormatter
          and eval { $arg = $RefArgFormatter->(@_); 1 }
        ) {
          return $arg;
        }
      }
      &$format_arg;
    }

    1;
  } or die $@;
}

sub _str_val;
if ("$]" >= 5.010_001) {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    sub _str_val {
      no overloading;
      "$_[0]";
    }

    1;
  } or die $@;
}
else {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    sub _str_val {
      my $class = &blessed;
      return "$_[0]" unless defined $class;
      return sprintf("%s=%s(0x%x)", $class, &reftype, &refaddr);
    }

    1;
  } or die $@;
}

sub _global_destruction ();
sub _in_END ();
if ("$]" >= 5.014_000) {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    sub _global_destruction () { ${^GLOBAL_PHASE} eq "DESTRUCT" }
    sub _in_END             () { ${^GLOBAL_PHASE} eq "END" }

    1;
  } or die $@;
}
else {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    # this is slightly a lie, but accurate enough for our purposes
    our $global_phase = 'RUN';

    sub _global_destruction () {
      if ($global_phase ne 'DESTRUCT') {
        local $SIG{__WARN__} = sub {
          $global_phase = 'DESTRUCT'
            if $_[0] =~ /global destruction\.\n\z/;
        };
        warn 1;
      }
      $global_phase eq 'DESTRUCT';
    }

    sub _in_END () {
      if ($global_phase eq 'RUN' && $^S) {
        # END blocks are FILO so we can't install one to run first.
        # only way to detect END reliably seems to be by using caller.
        # I hate this but it seems to be the best available option.
        # The top two frames will be an eval and the END block.
        my $i;
        1 while CORE::caller(++$i);
        if ($i > 2) {
          my @top = CORE::caller($i - 1);
          my @next = CORE::caller($i - 2);
          if (
            $top[3] eq '(eval)'
            && $next[3] =~ /::END$/
            && $top[2] == $next[2]
            && $top[1] eq $next[1]
            && $top[0] eq 'main'
            && $next[0] eq 'main'
          ) {
            $global_phase = 'END';
          }
        }
      }
      $global_phase eq 'END';
    }

    END {
      $global_phase = 'END';
    }

    1;
  } or die $@;
}

sub _can_stringify ();
if ("$]" < 5.008) {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    sub _can_stringify () {
      my $i = 0;
      while (my @caller = caller($i++)) {
        if ($caller[3] eq '(eval)') {
          return 0;
        }
        elsif ($caller[7]) {
          return 0;
        }
      }
      return 1;
    }

    1;
  } or die $@;
}
else {
  eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
    sub _can_stringify () {
      defined $^S && !$^S;
    }

    1;
  } or die $@;
}

sub _isa;
if ($INC{'UNIVERSAL/isa.pm'}) {
  require B;
  my $pad = B::svref_2object(\&UNIVERSAL::isa)->PADLIST;
  my ($n, $v) = $pad->ARRAY;
  my @names = $n->ARRAY;
  for my $i (0 .. $#names) {
    if ($names[$i]->can('PV') && $names[$i]->PV eq '$orig') {
      eval { *_isa = $v->ARRAYelt($i)->object_2svref };
      last;
    }
  }
  if (!defined &_isa) {
    my $isa = \&UNIVERSAL::isa;
    eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
      $isa if 0; # capture for 5.6
      sub _isa {
        local $UNIVERSAL::isa::recursing = 1;
        local $UNIVERSAL::isa::_recursing = 1;
        &$isa;
      }

      1;
    } or die $@;
  }
}
else {
  *_isa = \&UNIVERSAL::isa;
}

sub _can;
if ($INC{'UNIVERSAL/can.pm'}) {
  require B;
  my $pad = B::svref_2object(\&UNIVERSAL::can)->PADLIST;
  my ($n, $v) = $pad->ARRAY;
  my @names = $n->ARRAY;
  for my $i (0 .. $#names) {
    if ($names[$i]->can('PV') && $names[$i]->PV eq '$orig') {
      eval { *_can = $v->ARRAYelt($i)->object_2svref };
      last;
    }
  }

  if (!defined &_can) {
    my $can = \&UNIVERSAL::can;
    eval sprintf('#line %s "%s"', __LINE__+1, __FILE__) . q{
      $can if 0; # capture for 5.6
      sub _can {
        local $UNIVERSAL::can::recursing = 1;
        &$can;
      }
      1;
    } or die $@;
  }
}
else {
  *_can = \&UNIVERSAL::can;
}

1;
