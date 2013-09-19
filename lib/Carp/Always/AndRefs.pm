package Carp::Always::AndRefs;
use 5.006;
use strict;
use warnings FATAL => 'all';

use Carp ();
use overload ();
use Scalar::Util qw(blessed refaddr);
BEGIN {
  # fake weaken if it isn't available.  will cause leaks, but this
  # is a brute force debugging tool, so we can deal with it.
  *weaken = defined &Scalar::Util::weaken
    ? \&Scalar::Util::weaken : sub ($) { 0 };
};
BEGIN {
  *_CARP_DOT = $Carp::VERSION >= 1.25 ? sub () {1} : sub () {0};
}

our $VERSION = '0.001000';
$VERSION = eval $VERSION;

$Carp::Internal{+__PACKAGE__}++;

our %NoTrace;
$NoTrace{'Throwable::Error'}++;
$NoTrace{'Moose::Error::Default'}++;
$NoTrace{'Ouch'}++;

my %OLD_SIG;
my $old_verbose;

my %options = (
  objects => 1,
  hacks => 1,
);

sub import {
  my $class = shift;

  my @opts = map { /^-?(no_)?(.*)/; [ $_, $2, !$1 ] } @_;
  if (my @bad = grep { !exists $options{$_->[1]} } @opts) {
    Carp::croak "invalid options: " . join(', ', map { $_->[0] } @bad);
  }

  $options{$_->[1]} = $_->[2]
    for @opts;

  if (exists $options{hacks}) {
    require Carp::Always::AndRefs::Hacks;
    my $do = $options{hacks} ? 'import' : 'unimport';
    Carp::Always::AndRefs::Hacks->$do;
  }

  return
    if keys %OLD_SIG;

  @OLD_SIG{qw(__DIE__ __WARN__)} = @SIG{qw(__DIE__ __WARN__)};
  $SIG{__DIE__} = \&_die;
  $SIG{__WARN__} = \&_warn;

  $old_verbose = $Carp::Verbose;
  $Carp::Verbose = 1;
}

sub unimport {
  return
    unless keys %OLD_SIG;
  @SIG{qw(__DIE__ __WARN__)} = delete @OLD_SIG{qw(__DIE__ __WARN__)};

  $Carp::Verbose = $old_verbose;
}
END {
  __PACKAGE__->unimport;
}

sub _warn {
  my @convert = _convert(@_);
  if (my $warn = $OLD_SIG{__WARN__}) {
    $warn->(@convert);
  }
  else {
    warn @convert;
  }
}
sub _die {
  my @convert = _convert(@_);
  if (my $sig = $OLD_SIG{__DIE__}) {
    $sig->(@convert);
  }
  else {
    die @convert;
  }
}

my $pack_suffix = 'A000';
my %attached;

sub CLONE {
  %attached = map { $_->[0] ? (refaddr($_->[0]) => $_) : () } values %attached;
}

sub _convert {
  if (my $class = blessed $_[0]) {
    return @_
      unless $options{objects};
    my $ex = $_[0];
    my $id = refaddr($ex);
    return @_
      if $attached{$id};

    my $does = $ex->can('DOES') || sub () { 0 };
    if (
      grep {
        $NoTrace{$_}
        && $ex->isa($_)
        || $ex->$does($_)
      } keys %NoTrace
    ) {
      return @_;
    }

    my $message = Carp::longmess();
    $message =~ s/\.?$/./m;

    $attached{$id} = [ $ex, $class, $message ];
    weaken $attached{$id}[0];

    my $newclass = __PACKAGE__ . '::__ANON_' . $pack_suffix++ . '__';

    {
      no strict 'refs';
      @{$newclass . '::ISA'} = ('Carp::Always::AndRefs::Attached', $class);
    }

    bless $ex, $newclass;
    $ex;
  }
  elsif (ref(my $ex = $_[0])) {
    my $id = refaddr($ex);
    my $info = $attached{$id} ||= do {
      my $message = Carp::longmess();
      $message =~ s/\.?$/./m;
      my $info = [ $_[0], undef, $message ];
      weaken $info->[0];
      $info;
    };

    return($^S ? @_ : "@_$info->[1]");
  }
  elsif ((caller(1))[0] eq 'Carp') {
    if (_CARP_DOT) {
      return @_;
    }
    else {
      my $message = Carp::longmess();
      my $out = join('', @_);
      if ($out =~ s/\Q$message\E\z//) {
        $message =~ s/\.?$/./m;
        $out .= $message;
      }
      return $out;
    }
  }
  else {
    my $message = Carp::longmess();
    $message =~ s/^(.*\n)//;
    my $where = $1;
    $where =~ s/\.?$/./m;
    my $out = join('', @_);
    $out =~ s/(?:\Q$where\E)?\z/$where/;
    $out .= $message;
    return $out;
  }
}

sub _ex_info {
  @{$attached{refaddr $_[0]}};
}

{
  package Carp::Always::AndRefs::Attached;
  use overload
    fallback => 1,
    'bool' => sub {
      my ($ex, $class) = Carp::Always::AndRefs::_ex_info(@_);
      my $newclass = ref $ex;
      bless $ex, $class;
      my $out = !!$ex;
      bless $ex, $newclass;
      return $out;
    },
    '0+' => sub {
      my ($ex, $class) = Carp::Always::AndRefs::_ex_info(@_);
      my $newclass = ref $ex;
      bless $ex, $class;
      my $out = 0+$ex;
      bless $ex, $newclass;
      return $out;
    },
    '""' => sub {
      my ($ex, $class, $message) = Carp::Always::AndRefs::_ex_info(@_);
      my $newclass = ref $ex;
      bless $ex, $class;
      my $out = "$ex" . $message;
      bless $ex, $newclass;
      return $out;
    },
  ;

  sub DESTROY {
    my ($ex, $class) = Carp::Always::AndRefs::_ex_info(@_);
    my $newclass = ref $ex;
    my ($post) = $newclass =~ s/([^:]+)$//;

    bless $ex, $class;

    no strict 'refs';
    delete ${$newclass}{$post.'::'};

    my $destroy = $ex->can('DESTROY');
    goto &$destroy
      if $destroy;
    ();
  }
}


1;
__END__

=encoding utf8

=head1 NAME

Carp::Always::AndRefs - Warns and dies noisily with stack backtraces

=head1 SYNOPSIS

  use Carp::Always::AndRefs;

makes every C<warn()> and C<die()> complains loudly in the calling package 
and elsewhere. More often used on the command line:

  perl -MCarp::Always::AndRefs script.pl

=head1 DESCRIPTION

This module is meant as a debugging aid. It can be
used to make a script complain loudly with stack backtraces
when warn()ing or die()ing.

Here are how stack backtraces produced by this module
looks:

  # it works for explicit die's and warn's
  $ perl -MCarp::Always::AndRefs -e 'sub f { die "arghh" }; sub g { f }; g'
  arghh at -e line 1
          main::f() called at -e line 1
          main::g() called at -e line 1

  # it works for interpreter-thrown failures
  $ perl -MCarp::Always::AndRefs -w -e 'sub f { $a = shift; @a = @$a };' \
                           -e 'sub g { f(undef) }; g'
  Use of uninitialized value in array dereference at -e line 1
          main::f('undef') called at -e line 2
          main::g() called at -e line 2

In the implementation, the C<Carp> module does
the heavy work, through C<longmess()>. The
actual implementation sets the signal hooks
C<$SIG{__WARN__}> and C<$SIG{__DIE__}> to
emit the stack backtraces.

Oh, by the way, C<carp> and C<croak> when requiring/using
the C<Carp> module are also made verbose, behaving
like C<cluck> and C<confess>, respectively.

Stack traces will also be included for exception objects.

Currently, stack traces are not included for non-object references
thrown as exceptions.

=head2 EXPORT

Nothing at all is exported.

=head1 ACKNOWLEDGMENTS

The idea, part of the code, and most of the documentation are taken
from L<Carp::Always>.

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

=back

Please report bugs via CPAN RT 
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Carp-Always-AndRefs.

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

Graham Knop, E<lt>haarg@haarg.orgE<gt>

=item *

Adriano Ferreira, E<lt>ferreira@cpan.orgE<gt>

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
