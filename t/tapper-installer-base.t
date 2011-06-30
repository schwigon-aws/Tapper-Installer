#! /usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::MockModule;
use File::Temp qw/tempdir/;
use Data::Dumper;


BEGIN { 
        use_ok('Tapper::Installer::Base');
        use_ok('Tapper::Installer::Precondition');
}

# setup l4p
use Log::Log4perl;
my $string = "
log4perl.rootLogger           = INFO, root
log4perl.appender.root        = Log::Log4perl::Appender::Screen
log4perl.appender.root.stderr = 1
log4perl.appender.root.layout = SimpleLayout";
Log::Log4perl->init(\$string);

my $tempdir = tempdir( CLEANUP => 1 );

my @commands;
my $mock_base = Test::MockModule->new('Tapper::Base');
$mock_base->mock('log_and_exec', sub{ shift @_;push @commands, \@_; return 0});


my $base         = Tapper::Installer::Base->new;
my $package_file = 't/misc/packages/debian_package_test.deb';
my $destfile     = '/somefile';
my $config       = {paths => {
                              guest_mount_dir => $tempdir, 
                              base_dir        => '/basedir',
                             }};
my $precondition = {precondition_type => 'copyfile', 
                    name => $package_file,
                    dest => $destfile,
                    protocol => 'local',
                    mountfile => '/tmp/directory/'}; 



my $copyfile=Tapper::Installer::Precondition::Copyfile->new($config);
my $retval = $base->precondition_install($precondition, $copyfile);
is($retval, 0, 'Installation into flat image without errors');

is_deeply(\@commands, [
                       ["mount -o loop /basedir/tmp/directory/ $tempdir"],
                       ["cp", "--sparse=always", "-r", "-L", $package_file, "$tempdir$destfile"],
                       ["umount $tempdir"],
                       ["kpartx -d /dev/loop0"],
                       ["losetup -d /dev/loop0"],
                      ], "Guest install into flat image");
                      
@commands = ();
# last installation may have changed precondition so we need to set it again
$precondition = {
                 precondition_type => 'copyfile', 
                 name => $package_file,
                 dest => $destfile,
                 protocol => 'local',
                 mountfile => '/tmp/directory/',
                 mountpartition => 'p1'
                }; 
$retval = $base->precondition_install($precondition, $copyfile);
is($retval, 0, 'Installation into image partition without errors');
is_deeply(\@commands, 
          [
           ["losetup -d /dev/loop0"],
           ["losetup /dev/loop0 /basedir/tmp/directory/"],
           ["kpartx -a /dev/loop0"],
           ["mount /dev/mapper/loop0p1 $tempdir"],
           ["cp","--sparse=always","-r","-L","t/misc/packages/debian_package_test.deb","$tempdir/somefile"],
           ["umount /dev/mapper/loop0p1"],
           ["kpartx -d /dev/loop0"],
           ["losetup -d /dev/loop0"],
          ], "Guest install into image partition"
         );


@commands = ();
# last installation may have changed precondition so we need to set it again
$precondition = {
                 precondition_type => 'copyfile', 
                 name => $package_file,
                 dest => $destfile,
                 protocol => 'local',
                 mountpartition => '/does/not/exist',
                }; 
$retval = $base->precondition_install($precondition, $copyfile);
is($retval, 0, 'Installation into partition without errors');
is_deeply(\@commands, 
          [
           ["mount /does/not/exist $tempdir"],
           ["cp","--sparse=always","-r","-L","t/misc/packages/debian_package_test.deb","$tempdir/somefile"],
           ["umount $tempdir"],
          ], "Guest install into partition"
         );

@commands = ();
# last installation may have changed precondition so we need to set it again
$precondition = {
                 precondition_type => 'copyfile', 
                 name => $package_file,
                 dest => $destfile,
                 protocol => 'local',
                 mountdir => '/non/exist',
                }; 
$retval = $base->precondition_install($precondition, $copyfile);
is($retval, 0, 'Installation into partition without errors');
is_deeply(\@commands, 
          [
           ["cp","--sparse=always","-r","-L",$package_file,"$tempdir/non/exist$destfile"],
          ], "Guest install into directory"
         );

done_testing();
