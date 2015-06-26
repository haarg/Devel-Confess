package Devel::Confess;
BEGIN {
  my $can_use_informative_names = $] >= 5.008;
  # detect -d:Confess.  disable debugger features for now.  we'll
  # enable them when we need them.
  if (!defined &DB::DB && $^P & 0x02) {
    $can_use_informative_names = 1;
    $^P = 0;
  }
  *_CAN_USE_INFORMATIVE_NAMES
    = $can_use_informative_names ? sub () { 1 } : sub () { 0 };
}

use 5.006;
use strict;
use warnings;
no warnings 'once';

our $VERSION = '0.007012';
$VERSION = eval $VERSION;

use Carp ();
use Symbol ();
use Devel::Confess::_Util qw(blessed refaddr weaken longmess _str_val _in_END _can_stringify);
use Config ();
BEGIN {
  *_can = \&UNIVERSAL::can;

  *_BROKEN_CLONED_DESTROY_REBLESS
    = ($] >= 5.008009 && $] < 5.010000) ? sub () { 1 } : sub () { 0 };
  *_BROKEN_CLONED_GLOB_UNDEF
    = ($] > 5.008009 && $] <= 5.010000) ? sub () { 1 } : sub () { 0 };
  *_BROKEN_SIG_DELETE
    = ($] < 5.008008) ? sub () { 1 } : sub () { 0 };
  *_DEBUGGING
    = (
      defined &Config::non_bincompat_options
        ? (grep $_ eq 'DEBUGGING', Config::non_bincompat_options())
        : ($Config::Config{ccflags} =~ /-DDEBUGGING\b/)
    ) ? sub () { 1 } : sub () { 0 };
}

$Carp::Internal{+__PACKAGE__}++;

our %NoTrace;
$NoTrace{'Throwable::Error'}++;
$NoTrace{'Moose::Error::Default'}++;

our %OPTIONS;

sub _parse_options {
  my @opts = map { /^-?(no[_-])?(.*)/; [ $_, $2, $1 ? 0 : 1 ] } @_;
  if (!keys %OPTIONS) {
    %OPTIONS = (
      objects   => 1,
      builtin   => undef,
      dump      => 0,
      color     => 0,
      source    => 0,
      errors    => 1,
      warnings  => 1,
      better_names => 1,
    );
    local $@;
    eval {
      _parse_options(
        grep length, split /[\s,]+/, $ENV{DEVEL_CONFESS_OPTIONS}||''
      );
    } or warn "DEVEL_CONFESS_OPTIONS: $@";
  }
  for my $opt (@opts) {
    if ($opt->[1] =~ /^dump(\d*)$/) {
      $opt->[1] = 'dump';
      $opt->[2] = length $1 ? ($1 || 'inf') : 3;
    }
  }
  if (my @bad = grep { !exists $OPTIONS{$_->[1]} } @opts) {
    local $SIG{__DIE__};
    Carp::croak("invalid options: " . join(', ', map { $_->[0] } @bad));
  }
  $OPTIONS{$_->[1]} = $_->[2]
    for @opts;
  1;
}

our %OLD_SIG;

sub import {
  my $class = shift;

  _parse_options(@_);

  if (defined $OPTIONS{builtin}) {
    require Devel::Confess::Builtin;
    my $do = $OPTIONS{builtin} ? 'import' : 'unimport';
    Devel::Confess::Builtin->$do;
  }
  if ($OPTIONS{source}) {
    require Devel::Confess::Source;
  }
  if ($OPTIONS{color} && $^O eq 'MSWin32') {
    if (eval { require Win32::Console::ANSI }) {
      Win32::Console::ANSI->import;
    }
    else {
      local $SIG{__WARN__};
      Carp::carp
        "Devel::Confess color option requires Win32::Console::ANSI on Windows";
      $OPTIONS{color} = 0;
    }
  }

  if ($OPTIONS{errors} && !$OLD_SIG{__DIE__}) {
    $OLD_SIG{__DIE__} = $SIG{__DIE__}
      if $SIG{__DIE__} && $SIG{__DIE__} ne \&_die;
    $SIG{__DIE__} = \&_die;
  }
  if ($OPTIONS{warnings} && !$OLD_SIG{__WARN__}) {
    $OLD_SIG{__WARN__} = $SIG{__WARN__}
      if $SIG{__WARN__} && $SIG{__WARN__} ne \&_warn;
    $SIG{__WARN__} = \&_warn;
  }

  # enable better names for evals and anon subs
  $^P |= 0x100 | 0x200
    if _CAN_USE_INFORMATIVE_NAMES && $OPTIONS{better_names};
}

sub unimport {
  for my $sig (
    [ __DIE__ => \&_die ],
    [ __WARN__ => \&_warn ],
  ) {
    my ($name, $sub) = @$sig;
    my $now = $SIG{$name} or next;
    my $old = $OLD_SIG{$name};
    if ($now ne $sub && $old) {
      local $SIG{__WARN__};
      warn "Can't restore $name handler!\n";
      delete $SIG{$sig};
    }
    elsif ($old) {
      $SIG{$name} = $old;
      delete $OLD_SIG{$name};
    }
    else {
      no warnings 'uninitialized'; # bogus warnings on perl < 5.8.8
      undef $SIG{$name}
        if _BROKEN_SIG_DELETE;
      delete $SIG{$name};
    }
  }
}

sub _find_sig {
  my $sig = $_[0];
  return undef
    if !defined $sig;
  return $sig
    if ref $sig && eval { \&{$sig} };
  return undef
    if $sig eq 'DEFAULT' || $sig eq 'IGNORE';
  package #hide
    main;
  no strict 'refs';
  defined &{$sig} ? \&{$sig} : undef;
}

sub _warn {
  local $SIG{__WARN__};
  my @convert = _convert(@_);
  if (my $warn = _find_sig($OLD_SIG{__WARN__})) {
    $warn->(join('', @convert));
  }
  else {
    @convert = _ex_as_strings(@convert);
    @convert = _colorize(33, @convert) if $OPTIONS{color};
    warn @convert;
  }
}
sub _die {
  local $SIG{__DIE__};
  my @convert = _convert(@_);
  if (my $sig = _find_sig($OLD_SIG{__DIE__})) {
    $sig->(join('', @convert));
  }
  @convert = _can_stringify ? _ex_as_strings(@convert) : @convert;
  @convert = _colorize(31, @convert) if $OPTIONS{color} && _can_stringify;
  if (_DEBUGGING && _in_END) {
    local $SIG{__WARN__};
    warn @convert;
    $! ||= 1;
    return;
  }
  die @convert unless ref $convert[0];
}

sub _colorize {
  my ($color, @convert) = @_;
  if ($ENV{DEVEL_CONFESS_FORCE_COLOR} || -t *STDERR) {
    if (@convert == 1) {
      $convert[0] = s/(.*)//;
      unshift @convert, $1;
    }
    $convert[0] = "\e[${color}m$convert[0]\e[m";
  }
  return @convert;
}

sub _ref_formatter {
  require Data::Dumper;
  local $SIG{__WARN__} = sub {};
  local $SIG{__DIE__} = sub {};
  no warnings 'once';
  local $Data::Dumper::Indent = 0;
  local $Data::Dumper::Purity = 0;
  local $Data::Dumper::Terse = 1;
  local $Data::Dumper::Useqq = 1;
  local $Data::Dumper::Maxdepth = $OPTIONS{dump} eq 'inf' ? 0 : $OPTIONS{dump};
  Data::Dumper::Dumper($_[0]);
}

sub _stack_trace {
  no warnings 'once';
  local $Carp::RefArgFormatter
    = $OPTIONS{dump} ? \&_ref_formatter : \&_str_val;
  my $message = &longmess;
  $message =~ s/\.?$/./m;
  if ($OPTIONS{source}) {
    $message .= Devel::Confess::Source::source_trace(1);
  }
  $message;
}

our $PACK_SUFFIX = 'A000';

our %EXCEPTIONS;
our %PACKAGES;
our %MESSAGES;
our %CLONED;

sub CLONE {
  my %id_map = map {
    my $ex = $EXCEPTIONS{$_};
    defined $ex ? ($_ => refaddr($ex)) : ();
  } keys %EXCEPTIONS;

  %EXCEPTIONS = map {; $id_map{$_} => $EXCEPTIONS{$_}} keys %id_map;
  %PACKAGES = map {; $id_map{$_} => $PACKAGES{$_}} keys %id_map;
  %MESSAGES = map {; $id_map{$_} => $MESSAGES{$_}} keys %id_map;
  %CLONED = map {; $_ => 1 } values %id_map
    if _BROKEN_CLONED_DESTROY_REBLESS || _BROKEN_CLONED_GLOB_UNDEF;
  weaken($_)
    for values %EXCEPTIONS;
}

sub _update_ex_refs {
  for my $id ( keys %EXCEPTIONS ) {
    next
      if $EXCEPTIONS{$id};
    delete $EXCEPTIONS{$id};
    delete $PACKAGES{$id};
    delete $MESSAGES{$id};
    delete $CLONED{$id}
      if _BROKEN_CLONED_DESTROY_REBLESS || _BROKEN_CLONED_GLOB_UNDEF;
  }
}

sub _convert {
  _update_ex_refs;
  if (my $class = blessed(my $ex = $_[0])) {
    return @_
      unless $OPTIONS{objects};
    return @_
      if ! do {no strict 'refs'; defined &{"Devel::Confess::_Attached::DESTROY"} };
    my $message;
    my $id = refaddr($ex);
    if ($EXCEPTIONS{$id}) {
      return @_
        if $ex->isa("Devel::Confess::_Attached");

      # something is going very wrong.  possibly from a Safe compartment.
      # we probably broke something, but do the best we can.
      if ((ref $ex) =~ /^Devel::Confess::__ANON_/) {
        my $oldclass = $PACKAGES{$id};
        $message = $MESSAGES{$id};
        bless $ex, $oldclass;
      }
      else {
        # give up
        return @_;
      }
    }

    my $does = _can($ex, 'can') && ($ex->can('does') || $ex->can('DOES')) || sub () { 0 };
    if (
      grep {
        $NoTrace{$_}
        && _can($ex, 'isa')
        && $ex->isa($_)
        || $ex->$does($_)
      } keys %NoTrace
    ) {
      return @_;
    }

    $message ||= _stack_trace();

    weaken($EXCEPTIONS{$id} = $ex);
    $PACKAGES{$id} = $class;
    $MESSAGES{$id} = $message;

    my $newclass = __PACKAGE__ . '::__ANON_' . $PACK_SUFFIX++ . '__';

    {
      no strict 'refs';
      @{$newclass . '::ISA'} = ('Devel::Confess::_Attached', $class);
    }

    bless $ex, $newclass;
    return $ex;
  }
  elsif (ref($ex = $_[0])) {
    my $id = refaddr($ex);

    my $message = _stack_trace;

    weaken($EXCEPTIONS{$id} = $ex);
    $PACKAGES{$id} = undef;
    $MESSAGES{$id} ||= $message;

    return $ex;
  }
  elsif ((caller(1))[0] eq 'Carp') {
    my $out = join('', @_);

    my $long = longmess();
    my $long_trail = $long;
    $long_trail =~ s/.*?\n//;
    $out =~ s/\Q$long\E\z|\Q$long_trail\E\z//
      or $out =~ s/(.*) at .*? line .*?\n\z/$1/;

    return ($out, _stack_trace());
  }
  else {
    my $message = _stack_trace();
    $message =~ s/^(.*\n?)//;
    my $where = $1;
    my $find = $where;
    $find =~ s/(\.?\n?)\z//;
    $find = qr/\Q$find\E(?: during global destruction)?(\.?\n?)/;
    my $out = join('', @_);
    $out =~ s/($find)\z//
      and $where = $1;
    return ($out, $where . $message);
  }
}

sub _ex_as_strings {
  my $ex = $_[0];
  return @_
    unless ref $ex;
  my $id = refaddr($ex);
  my $class = $PACKAGES{$id};
  my $message = $MESSAGES{$id};
  my $out;
  if (blessed $ex) {
    my $newclass = ref $ex;
    bless $ex, $class if $class;
    if ($OPTIONS{dump} && !overload::OverloadedStringify($ex)) {
      $out = _ref_formatter($ex);
    }
    else {
      $out = "$ex";
    }
    bless $ex, $newclass if $class;
  }
  elsif ($OPTIONS{dump}) {
    $out = _ref_formatter($ex);
  }
  else {
    $out = "$ex";
  }
  return ($out, $message);
}

{
  package #hide
    Devel::Confess::_Attached;
  use overload
    fallback => 1,
    'bool' => sub {
      my $ex = $_[0];
      my $class = $PACKAGES{Devel::Confess::refaddr($ex)};
      my $newclass = ref $ex;
      bless $ex, $class;
      my $out = !!$ex;
      bless $ex, $newclass;
      return $out;
    },
    '0+' => sub {
      my $ex = $_[0];
      my $class = $PACKAGES{Devel::Confess::refaddr($ex)};
      my $newclass = ref $ex;
      bless $ex, $class;
      my $out = 0+sprintf '%f', $ex;
      bless $ex, $newclass;
      return $out;
    },
    '""' => sub {
      return join('', Devel::Confess::_ex_as_strings(@_));
    },
  ;

  sub DESTROY {
    my $ex = $_[0];
    my $id = Devel::Confess::refaddr($ex);
    my $class = delete $PACKAGES{$id} or return;
    delete $MESSAGES{$id};
    delete $EXCEPTIONS{$id};

    my $newclass = ref $ex;

    my $cloned;
    # delete_package is more complete, but can explode on some perls
    if (Devel::Confess::_BROKEN_CLONED_GLOB_UNDEF && delete $Devel::Confess::CLONED{$id}) {
      $cloned = 1;
      no strict 'refs';
      @{"${newclass}::ISA"} = ();
      my $stash = \%{"${newclass}::"};
      delete @{$stash}{keys %$stash};
    }
    else {
      Symbol::delete_package($newclass);
    }

    if (Devel::Confess::_BROKEN_CLONED_DESTROY_REBLESS && $cloned || delete $Devel::Confess::CLONED{$id}) {
      my $destroy = $class->can('DESTROY') || return;
      goto $destroy;
    }

    bless $ex, $class;

    # after reblessing, perl will re-dispatch to the class's own DESTROY.
    ();
  }
}

1;
__END__

=encoding utf8

=head1 NAME

Devel::Confess - Include stack traces on all warnings and errors

=head1 SYNOPSIS

Use on the command line:

  # Make every warning and error include a full stack trace
  perl -d:Confess script.pl

  # Also usable as a module
  perl -MDevel::Confess script.pl

  # display warnings in yellow and errors in red
  perl -d:Confess=color script.pl

  # set options by environment
  export DEVEL_CONFESS_OPTIONS='color dump'
  perl -d:Confess script.pl

Can also be used inside a script:

  use Devel::Confess;

  use Devel::Confess 'color';

  # disable stack traces
  no Devel::Confess;

=head1 DESCRIPTION

This module is meant as a debugging aid. It can be used to make a script
complain loudly with stack backtraces when warn()ing or die()ing.  Unlike other
similar modules (e.g. L<Carp::Always>), it includes stack traces even when
exception objects are thrown.

The stack traces are generated using L<Carp>, and will look work for all types
of errors.  L<Carp>'s C<carp> and C<confess> functions will also be made to
include stack traces.

  # it works for explicit die's and warn's
  $ perl -d:Confess -e 'sub f { die "arghh" }; sub g { f }; g'
  arghh at -e line 1.
          main::f() called at -e line 1
          main::g() called at -e line 1

  # it works for interpreter-thrown failures
  $ perl -d:Confess -w -e 'sub f { $a = shift; @a = @$a };' \
                                        -e 'sub g { f(undef) }; g'
  Use of uninitialized value $a in array dereference at -e line 1.
          main::f(undef) called at -e line 2
          main::g() called at -e line 2

Internally, this is implemented with C<$SIG{__WARN__}> and C<$SIG{__DIE__}>
hooks.

Stack traces are also included if raw non-object references are thrown.

=head1 METHODS

=head2 import( @options )

Enables stack traces and sets options.  A list of options to enable can be
passed in.  Prefixing the options with C<no_> will disable them.

=over 4

=item C<objects>

Enable attaching stack traces to exception objects.  Enabled by default.

=item C<builtin>

Load the L<Devel::Confess::Builtin> module to use built in
stack traces on supported exception types.  Disabled by default.

=item C<dump>

Dumps the contents of references in arguments in stack trace, instead
of only showing their stringified version.  Shows up to three references deep.
Disabled by default.

=item C<dump0>, C<dump1>, C<dump2>, etc

The same as the dump option, but with a different max depth to dump.  A depth
of 0 is treated as infinite.

=item C<color>

Colorizes error messages in red and warnings in yellow.  Disabled by default.

=item C<source>

Includes a snippet of the source for each level of the stack trace. Disabled
by default.

=item C<better_names>

Use more informative names to string evals and anonymous subs in stack
traces.  Enabled by default.

=item C<errors>

Add stack traces to errors.  Enabled by default.

=item C<warnings>

Add stack traces to warnings.  Enabled by default.

=back

The default options can be changed by setting the C<DEVEL_CONFESS_OPTIONS>
environment variable to a space separated list of options.

=head1 CONFIGURATION

=head2 C<%Devel::Confess::NoTrace>

Classes or roles added to this hash will not have stack traces
attached to them.  This is useful for exception classes that provide
their own stack traces, or classes that don't cope well with being
re-blessed.  If L<Devel::Confess::Builtin> is loaded, it will
automatically add its supported exception types to this hash.

Default Entries:

=over 4

=item L<Throwable::Error>

Provides a stack trace

=item L<Moose::Error::Default>

Provides a stack trace

=back

=head1 ACKNOWLEDGMENTS

The idea and parts of the code and documentation are taken from L<Carp::Always>.

=head1 SEE ALSO

=over 4

=item *

L<Carp::Always>

=item *

L<Carp>

=item *

L<Acme::JavaTrace> and L<Devel::SimpleTrace>

=item *

L<Carp::Always::Color>

=item *

L<Carp::Source::Always>

=item *

L<Carp::Always::Dump>

=back

Please report bugs via CPAN RT
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Devel-Confess.

=head1 BUGS

This module uses several ugly tricks to do its work and surely has bugs.

=over 4

=item *

This module does not play well with other modules which fusses
around with C<warn>, C<die>, C<$SIG{'__WARN__'}>,
C<$SIG{'__DIE__'}>.

=back

=head1 AUTHORS

=over

=item *

Graham Knop <haarg@haarg.org>

=item *

Adriano Ferreira <ferreira@cpan.org>

=back

=head1 CONTRIBUTORS

None yet.

=head1 COPYRIGHT

Copyright (c) 2005-2013 the L</AUTHORS> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<http://dev.perl.org/licenses/>.

=cut
