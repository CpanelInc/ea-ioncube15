#!/usr/local/cpanel/3rdparty/bin/perl

#
#                                      Copyright 2026 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use strict;
use warnings;

require './find-latest-version';

use HTTP::Tiny;
use File::Temp;
use File::Path qw(make_path remove_tree);
use File::Copy;
use File::Find;
use Cwd qw(abs_path getcwd);
use Getopt::Long;

my $nocleanup = 0;
GetOptions(
    'nocleanup' => \$nocleanup,
) or die "Usage: $0 [--nocleanup]\n";

my $http = HTTP::Tiny->new();

# Get stable version (15.0.0) - complete with all PHP versions
print "Fetching stable version info...\n";
my ($stable_version, $stable_url, $stable_name) = ea_ioncube15::find_latest_version::_get_required($http, undef);
print "Stable: $stable_version from $stable_url\n";

# Get beta version (15.5.0) - has PHP 8.5 support
print "Fetching beta version info...\n";
my ($beta_version, $beta_url, $beta_name) = ea_ioncube15::find_latest_version::_get_required($http, "15.5");
print "Beta: $beta_version from $beta_url\n";

# Create temporary working directory
my $cleanup = $nocleanup ? 0 : 1;
my $tempdir = File::Temp->newdir(CLEANUP => $cleanup);
my $workdir = $tempdir->dirname;
print "\n" . "="x70 . "\n";
print "ASSEMBLY DIRECTORY: $workdir\n";
if ($nocleanup) {
    print "NOTE: Temp directory will NOT be cleaned up (--nocleanup specified)\n";
} else {
    print "NOTE: Temp directory will be cleaned up on exit\n";
}
print "="x70 . "\n\n";

# Download stable tarball
print "Downloading stable tarball...\n";
my $stable_tarball = "$workdir/$stable_name";
my $res = $http->mirror($stable_url, $stable_tarball);
die "Failed to download stable tarball: $res->{status} $res->{reason}\n" unless $res->{success};

# Download beta tarball
print "Downloading beta tarball...\n";
my $beta_tarball = "$workdir/$beta_name";
$res = $http->mirror($beta_url, $beta_tarball);
die "Failed to download beta tarball: $res->{status} $res->{reason}\n" unless $res->{success};

# Extract stable tarball
print "Extracting stable tarball...\n";
my $stable_dir = "$workdir/stable";
mkdir $stable_dir or die "Cannot create stable dir: $!\n";
system("tar", "-xzf", $stable_tarball, "-C", $stable_dir) == 0 
    or die "Failed to extract stable tarball\n";

# Extract beta tarball
print "Extracting beta tarball...\n";
my $beta_dir = "$workdir/beta";
mkdir $beta_dir or die "Cannot create beta dir: $!\n";
system("tar", "-xzf", $beta_tarball, "-C", $beta_dir) == 0
    or die "Failed to extract beta tarball\n";

# Create merge directory
my $merge_dir = "$workdir/merged";
mkdir $merge_dir or die "Cannot create merge dir: $!\n";

# Copy ALL files from stable to merge directory
print "Copying all files from stable version...\n";
system("cp", "-a", "$stable_dir/.", $merge_dir) == 0
    or die "Failed to copy stable files\n";

# Find and copy ONLY .so files from beta to merge directory
print "Copying .so files from beta version...\n";
my @so_files;
File::Find::find(
    sub {
        if ($_ =~ /\.so$/) {
            push @so_files, $File::Find::name;
        }
    },
    $beta_dir
);

foreach my $so_file (@so_files) {
    my $relative_path = $so_file;
    $relative_path =~ s/^\Q$beta_dir\E\/?//;
    
    my $dest_file = "$merge_dir/$relative_path";
    my $dest_dir = $dest_file;
    $dest_dir =~ s/\/[^\/]+$//;
    
    make_path($dest_dir) unless -d $dest_dir;
    
    print "  Copying $relative_path\n";
    copy($so_file, $dest_file) or die "Failed to copy $so_file: $!\n";
}

# Create combined tarball
print "Creating combined tarball...\n";
my $combined_tarball = "$workdir/ioncube_loaders_lin_x86-64_combined.tar.gz";
my $original_dir = getcwd();
chdir($merge_dir) or die "Cannot chdir to merge dir: $!\n";

# Get the base directory name from the extracted tarball
opendir(my $dh, ".") or die "Cannot open merge dir: $!\n";
my @entries = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
closedir($dh);

if (@entries == 1 && -d $entries[0]) {
    # Everything is under one directory, tar it
    system("tar", "-czf", $combined_tarball, $entries[0]) == 0
        or die "Failed to create combined tarball\n";
} else {
    # Multiple entries at top level, tar them all
    system("tar", "-czf", $combined_tarball, @entries) == 0
        or die "Failed to create combined tarball\n";
}

chdir($original_dir) or die "Cannot chdir back: $!\n";

# Delete existing ioncube tarballs from SOURCES directory
my $sources_dir = "./SOURCES";
if (!-d $sources_dir) {
    die "SOURCES directory not found. You must run this script from the top directory of this repo.\n";
}
if (-d $sources_dir) {
    print "Cleaning existing ioncube tarballs from SOURCES directory...\n";
    opendir(my $sdh, $sources_dir) or die "Cannot open SOURCES dir: $!\n";
    my @old_tarballs = grep { /^ioncube.*\.tar\.gz$/ } readdir($sdh);
    closedir($sdh);
    
    foreach my $old_tarball (@old_tarballs) {
        my $old_path = "$sources_dir/$old_tarball";
        print "  Removing $old_tarball\n";
        unlink($old_path) or warn "Failed to remove $old_path: $!\n";
    }
}

# Copy combined tarball to SOURCES directory
my $dest_tarball = "$sources_dir/ioncube_loaders_lin_x86-64.tar.gz";
print "Copying combined tarball to SOURCES directory...\n";
copy($combined_tarball, $dest_tarball) or die "Failed to copy to SOURCES: $!\n";

print "\n" . "="x70 . "\n";
print "SUCCESS! Combined tarball created\n";
print "="x70 . "\n";
print "Tarball location: $dest_tarball\n";
print "Assembly directory: $workdir\n";
print "\nThis tarball contains:\n";
print "  - All PHP loaders from version $stable_version (stable)\n";
print "  - PHP 8.5 .so loaders from version $beta_version (beta)\n";
print "="x70 . "\n";
