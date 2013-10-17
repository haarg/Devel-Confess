package Devel::Confess::Source;
use 5.006;
use strict;
use warnings FATAL => 'all';

$^P |= 0x100 | 0x400;

sub source_trace {
  my ($skip, $context) = @_;
  $skip ||= 1;
  $skip += $Carp::CarpLevel;
  $context ||= 3;
  my $i = $skip;
  my @out;
  while (my ($pack, $file, $line) = (caller($i++))[0..2]) {
    next
      if $Carp::Internal{$pack} || $Carp::CarpInternal{$pack};
    my $lines = _get_content($file) || next;

    my $start = $line - $context;
    $start = 1 if $start < 1;
    $start = $#$lines if $start > $#$lines;
    my $end = $line + $context;
    $end = $#$lines if $end > $#$lines;

    my $context = "context for $file line $line:\n";
    for my $read_line ($start..$end) {
      my $code = $lines->[$read_line];
      $code =~ s/\n\z//;
      if ($read_line == $line) {
        $code = "\e[30;43m$code\e[m";
      }
      $context .= sprintf "%5s : %s\n", $read_line, $code;
    }
    push @out, $context;
  }
  return join(('=' x 75) . "\n",
    '',
    join(('-' x 75) . "\n", @out),
    '',
  );
}

sub _get_content {
  my $file = shift;
  no strict 'refs';
  if (exists $::{'_<'.$file} && @{ '::_<'.$file }) {
    return \@{ '::_<'.$file };
  }
  elsif ($file =~ /^\(eval \d+\)$/) {
    return ["Can't get source of evals unless debugger available!"];
  }
  elsif (open my $fh, '<', $file) {
    my @lines = ('', <$fh>);
    return \@lines;
  }
  else {
    return ["Source not available!"];
  }
}

1;
