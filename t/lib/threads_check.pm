package t::lib::threads_check;

sub _skip {
  print "1..0 # SKIP $_[0]\n";
  exit 0;
}

sub import {
  my ($class, $op) = @_;
  if ($0 eq '-' && $op) {
    if ($op eq 'installed') {
      eval { require threads } or exit 1;
    }
    elsif ($op eq 'create') {
      require threads;
      threads->create(sub{ 1 })->join;
    }
    exit 0;
  }
  require Config;
  if (! $Config::Config{useithreads}) {
    _skip "your perl does not support ithreads";
  }
  elsif (system "$^X", '-Mt::lib::threads_check=installed') {
    _skip "threads.pm not installed";
  }
  elsif (system "$^X", '-Mt::lib::threads_check=create') {
    _skip "threads are broken on this machine";
  }
}

1;
