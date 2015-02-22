#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above "Genome";

require Cwd;
use Data::Dumper;
require Digest::MD5;
require Genome::Utility::Test;
use Test::More;
use Test::Exception;

use_ok('Genome::InstrumentData::Command::Import::Manager') or die;

my $cwd = Cwd::getcwd();
my $test_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import::Manager', 'v3');
chdir $test_dir;
my $source_files_tsv = $test_dir.'/source-files.tsv';

my $analysis_project = Genome::Config::AnalysisProject->create(name => '__TEST_AP__');
ok($analysis_project, 'create analysis project');

# Library needed
my $manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $source_files_tsv,
    list_config => "printf %s NOTHING_TO_SEE_HERE;1;2",
    launch_config => "echo %{job_name} LAUNCH!",
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');

my $imports_aryref = $manager->_imports;
is_deeply([ map { $_->{status} } @$imports_aryref ], [qw/ no_library no_library no_library no_library /], 'imports aryref status');
is_deeply([ map { $_->{library_name} } @$imports_aryref ], [qw/ TeSt-0000-00-extlibs TeSt-0000-00-extlibs TeSt-0000-01-extlibs TeSt-0000-01-extlibs /], 'imports aryref library_name');
is_deeply([ map { $_->{source_files} } @$imports_aryref ], [qw/ bam1.bam bam2.bam bam3.bam bam3.bam /], 'imports aryref source_files');
is_deeply([ map { $_->{instrument_data_properties} } @$imports_aryref ], [ {lane => '8'}, {lane => '8'}, {lane => 7, downsample_ratio => '.25'}, {lane => 7, downsample_ratio => '.1'}, ], 'imports aryref instrument_data_properties');
is_deeply([ map { $_->{job_name} } @$imports_aryref ], [qw/ 6c445b 592f97 260cb0 844eb6 /], 'imports aryref job_name');
ok(!grep({ $_->{libraries} } @$imports_aryref), 'imports aryref does not have library');
ok(!grep({ $_->{job_status} } @$imports_aryref), 'imports aryref does not have job_status');
ok(!grep({ $_->{instrument_data} } @$imports_aryref), 'imports aryref does not have instrument_data');
ok(!grep({ $_->{instrument_data_file} } @$imports_aryref), 'imports aryref does not have instrument_data_file');

# Define libraries
my $base_sample_name = 'TeSt-0000-0';
my @libraries;
for (0..1) { 
    push @libraries, Genome::Library->__define__(
        id => -222 + $_,
        name => $base_sample_name.$_.'-extlibs',
        sample => Genome::Sample->__define__(
            id => -111 + $_,
            name => $base_sample_name.$_,
            nomenclature => 'TeSt',
        ),
    );
}
is(@libraries, 2, 'define 2 libraries');

# Import needed
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $source_files_tsv,
    list_config => "printf %s NOTHING_TO_SEE_HERE;1;2",
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');

$imports_aryref = $manager->_imports;
is_deeply([ map { $_->{status} } @$imports_aryref ], [qw/ needed needed needed needed /], 'imports aryref status');
is_deeply([ map { @{$_->{library}} } @$imports_aryref ], [$libraries[0], $libraries[0], $libraries[1], $libraries[1]], 'imports aryref library');
ok(!grep({ $_->{job_status} } @$imports_aryref), 'imports aryref does not have job_status');
ok(!grep({ $_->{instrument_data} } @$imports_aryref), 'imports aryref does not have instrument_data');
ok(!grep({ $_->{instrument_data_file} } @$imports_aryref), 'imports aryref does not have instrument_data_file');

is($manager->_list_command, 'printf %s NOTHING_TO_SEE_HERE', '_list_command');
is($manager->_list_job_name_column, 0, '_list_job_name_column');
is($manager->_list_status_column, 1, '_list_status_column');

# One has import running, others are needed
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $source_files_tsv,
    list_config => 'printf "%s %s\\n%s %s\\n%s %s\\n%s %s" 6c445b pend 592f97 run 260cb0 run 844eb6 pend;1;2',
    launch_config => "echo %{job_name} LAUNCH!",
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');

$imports_aryref = $manager->_imports;
is_deeply([ map { $_->{status} } @$imports_aryref ], [qw/ pend run run pend /], 'imports aryref status');
is_deeply([ map { $_->{job_status} } @$imports_aryref ], [qw/ pend run run pend /], 'imports aryref job_status');
ok(!grep({ $_->{instrument_data} } @$imports_aryref), 'imports aryref does not have instrument_data');
ok(!grep({ $_->{instrument_data_file} } @$imports_aryref), 'imports aryref does not have instrument_data_file');

# Print commands
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $source_files_tsv,
    launch_config => "echo %{job_name} LAUNCH! GTMP=%{gtmp}", # successful imports, will not launch
    show_import_commands => 1,
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');

# Create inst data
my @inst_data;
for my $import_hashref ( @$imports_aryref ) {
    my $inst_data = Genome::InstrumentData::Imported->__define__(
        original_data_path => $import_hashref->{source_files},
        library => $import_hashref->{library}->[0],
        subset_name => '1-XXXXXX',
        sequencing_platform => 'solexa',
        import_format => 'bam',
        description => 'import test',
    );
    $inst_data->add_attribute(attribute_label => 'bam_path', attribute_value => $source_files_tsv);
    my $downsample_ratio = $import_hashref->{instrument_data_properties}->{downsample_ratio};
    $inst_data->add_attribute(attribute_label => 'downsample_ratio', attribute_value => $downsample_ratio) if $downsample_ratio;
    push @inst_data, $inst_data;
}
is(@inst_data, 4, 'define 4 inst data');

# Fake successful imports by pointing bam_path to existing source_files.tsv
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $source_files_tsv,
    list_config => "printf %s NOTHING_TO_SEE_HERE;1;2",
    launch_config => "echo %{job_name} LAUNCH! GTMP=%{gtmp} MTMP=%{mtmp} KBTMP=%{kbtmp}", # successful imports, will not launch
);
ok($manager, 'create manager');
ok($manager->execute, 'execute');

$imports_aryref = $manager->_imports;
is_deeply([ map { $_->{status} } @$imports_aryref ], [qw/ success success success success /], 'imports aryref status');
is_deeply([ sort { $a->id cmp $b->id } map { @{$_->{instrument_data}} } @$imports_aryref ], [ sort { $a->id cmp $b->id } @inst_data], 'imports aryref instrument_data');
ok(!grep({ $_->{job_status} } @$imports_aryref), 'imports aryref does not have job_status');

is_deeply(
    [ map { $manager->_resolve_launch_command_for_import($_) } @$imports_aryref ],
    [
    "echo 6c445b LAUNCH! GTMP=1 MTMP=1024 KBTMP=1048576 genome instrument-data import basic --library name=TeSt-0000-00-extlibs --source-files bam1.bam --import-source-name 'TeSt' --instrument-data-properties lane='8' --analysis-project id=".$analysis_project->id,
    "echo 592f97 LAUNCH! GTMP=1 MTMP=1024 KBTMP=1048576 genome instrument-data import basic --library name=TeSt-0000-00-extlibs --source-files bam2.bam --import-source-name 'TeSt' --instrument-data-properties lane='8' --analysis-project id=".$analysis_project->id,
    "echo 260cb0 LAUNCH! GTMP=1 MTMP=1024 KBTMP=1048576 genome instrument-data import basic --library name=TeSt-0000-01-extlibs --source-files bam3.bam --import-source-name 'TeSt' --instrument-data-properties downsample_ratio='.25',lane='7' --analysis-project id=".$analysis_project->id. ' --downsample-ratio .25',
    "echo 844eb6 LAUNCH! GTMP=1 MTMP=1024 KBTMP=1048576 genome instrument-data import basic --library name=TeSt-0000-01-extlibs --source-files bam3.bam --import-source-name 'TeSt' --instrument-data-properties downsample_ratio='.1',lane='7' --analysis-project id=".$analysis_project->id. ' --downsample-ratio .1',
    ],
    'launch commands',
);

# fail - no name column in csv
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $test_dir.'/invalid-no-library-name-column.tsv',
);
ok($manager, 'create manager');
ok(!$manager->execute, 'execute failed for no library column in file');
is($manager->error_message, 'Property \'source_files_tsv\': No "library_name" column in source files tsv! '.$manager->source_files_tsv, 'correct error');

# fail - extra column name column in csv
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $test_dir.'/invalid-format.tsv',
);
ok($manager, 'create manager');
throws_ok(sub {$manager->execute}, qr/Expected 3 values, got 4 on line 3 in/, 'execute failed for invalid format');

# fail - source file does not exist
$manager = Genome::InstrumentData::Command::Import::Manager->create(
    analysis_project => $analysis_project,
    source_files_tsv => $test_dir.'/source-file-does-not-exist.tsv',
);
ok($manager, 'create manager');
ok(!$manager->execute, 'execute failed w/ non existing source file');
is( Genome::InstrumentData::Command::Import::WorkFlow::Helpers->error_message, 'Source file does not have any size! bam4.bam', 'correct error');

chdir $cwd;
done_testing();
