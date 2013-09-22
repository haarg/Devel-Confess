package t::capture;
use strict;
use warnings;

use File::Temp qw(tempfile);
use IPC::Open3;
use File::Spec;
use base qw(Exporter);

our @EXPORT = qw(capture);

our @OPTS;
my @PERL5OPTS = map "-I$_", @INC;

sub capture ($) {
    my ($code) = @_;

    my ($fh, $filename) = tempfile()
      or die "can't open temp file: $!";
    print { $fh } $code;
    close $fh;

    open my $in, '<', File::Spec->devnull or die "can't open null: $!";
    open3( $in, my $out, undef, $^X, @PERL5OPTS, @OPTS, $filename)
      or die "Couldn't open subprocess: $!\n";
    my $output = do { local $/; <$out> };
    close $in;
    close $out;

    $output =~ s/\r\n?/\n/g;

    unlink $filename
      or die "Couldn't unlink $filename: $!\n";

    return $output;
}

1;
