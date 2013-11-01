#!/usr/bin/env genome-perl

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More; #skip_all => 'archiving not fully implemented yet';
use File::Temp 'tempdir';
use Filesys::Df qw();

use_ok('Genome::Disk::Allocation') or die;
use_ok('Genome::Disk::Volume') or die;

use Genome::Disk::Allocation;
$Genome::Disk::Allocation::CREATE_DUMMY_VOLUMES_FOR_TESTING = 0;
#$Genome::Disk::Allocation::TESTING_DISK_ALLOCATION = 1;

# Temp testing directory, used as mount path for test volumes and allocations
my $test_dir = tempdir(
    'allocation_testing_XXXXXX',
    TMPDIR => 1,
    UNLINK => 1,
    CLEANUP => 1,
);

# Create test group
my $group = Genome::Disk::Group->create(
    disk_group_name => 'test',
    subdirectory => 'info',
    permissions => '775',
    setgid => 1,
    unix_uid => '1',
    unix_gid => '1',
);
ok($group, 'created test disk group');

# Create temp archive volume
my $archive_volume_path = tempdir(
    "test_volume_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $archive_volume = Genome::Disk::Volume->create(
    hostname => 'test',
    physical_path => 'test',
    mount_path => $archive_volume_path,
    disk_status => 'active',
    can_allocate => 1,
    total_kb => Filesys::Df::df($archive_volume_path)->{blocks},
);
ok($archive_volume, 'created test volume');

# Create temp active volume
my $volume_path = tempdir(
    "test_volume_XXXXXXX",
    DIR => $test_dir,
    CLEANUP => 1,
    UNLINK => 1,
);
my $volume = Genome::Disk::Volume->create(
    hostname => 'test',
    physical_path => 'test',
    mount_path => $volume_path,
    disk_status => 'active',
    can_allocate => 1,
    total_kb => Filesys::Df::df($volume_path)->{blocks},
);
ok($volume, 'created test volume');

my $assignment = Genome::Disk::Assignment->create(
    group => $group,
    volume => $volume,
);
ok($assignment, 'added volume to test group successfully');
Genome::Sys->create_directory(join('/', $volume->mount_path, $group->subdirectory));

my $archive_assignment = Genome::Disk::Assignment->create(
    group => $group,
    volume => $archive_volume
);
ok($archive_assignment, 'added archiev volume to test group successfully');
Genome::Sys->create_directory(join('/', $archive_volume->mount_path, $group->subdirectory));

# Make test allocation
my $allocation_path = tempdir(
    "allocation_test_1_XXXXXX",
    CLEANUP => 1,
    UNLINK => 1,
    DIR => $test_dir,
);
my $allocation = Genome::Disk::Allocation->create(
    disk_group_name => $group->disk_group_name,
    allocation_path => $allocation_path,
    kilobytes_requested => 100,
    owner_class_name => 'UR::Value',
    owner_id => 'test',
    mount_path => $volume->mount_path,
);
ok($allocation, 'created test allocation');
system("touch " . $allocation->absolute_path . "/a.out");

# Override these methods so archive/active volume linking works for our test volumes
no warnings 'redefine';
*Genome::Disk::Volume::archive_volume_prefix = sub { return $archive_volume->mount_path };
*Genome::Disk::Volume::active_volume_prefix = sub { return $volume->mount_path };
use warnings;

# Create command object and execute it
my $cmd = Genome::Disk::Command::Allocation::Archive->create(
    allocations => [$allocation],
);
ok($cmd, 'created archive command');
ok($cmd->execute, 'successfully executed archive command');
is($allocation->volume->id, $archive_volume->id, 'allocation moved to archive volume');
ok($allocation->is_archived, 'allocation is now archived');

# Make another allocation
$allocation_path = tempdir(
    "allocation_test_1_XXXXXX",
    CLEANUP => 1,
    UNLINK => 1,
);
$allocation = Genome::Disk::Allocation->create(
    disk_group_name => $group->disk_group_name,
    allocation_path => $allocation_path,
    kilobytes_requested => 100,
    owner_class_name => 'UR::Value',
    owner_id => 'test',
    mount_path => $volume->mount_path,
);
ok($allocation, 'created test allocation');
system("touch " . $allocation->absolute_path . "/a.out");

# Now simulate the command being run from the CLI
my @args = ($allocation->id);
my $rv = Genome::Disk::Command::Allocation::Archive->_execute_with_shell_params_and_return_exit_code(@args);
ok($rv == 0, 'successfully executed command using simulated command line arguments');
is($allocation->volume->id, $archive_volume->id, 'allocation updated as expected after archive');

done_testing();


1;
