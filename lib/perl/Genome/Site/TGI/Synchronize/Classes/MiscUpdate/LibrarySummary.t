#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
};

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Site::TGI::Synchronize::Classes::MiscUpdate') or die;

my $cnt = 0;

# Valid
my $sample = Genome::Sample->create(id => -100, name => '__TEST_SAMPLE__');
ok($sample, 'Create sample');
my $library = Genome::Library->create(id => -101, name => '__TEST_LIBRARY__', sample => $sample);
ok($library, 'Create library');
my $misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->create(
    subject_class_name => 'test.library_summary',
    subject_id => $library->id,
    subject_property_name => 'protocol',
    editor_id => 'lims',
    edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
    old_value => undef,
    new_value => 'awesome',
    description => 'UPDATE',
    is_reconciled => 0,
);
ok($misc_update, 'Create misc update');
isa_ok($misc_update, 'Genome::Site::TGI::Synchronize::Classes::MiscUpdate::LibrarySummary');
is($misc_update->lims_table_name, 'library_summary', 'Correct lims table name');
my $genome_class_name = $misc_update->genome_class_name;
is($genome_class_name, 'Genome::Library', 'Correct genome class name');
my $genome_entity = $misc_update->genome_entity;
ok($genome_entity, 'Got genome entity');
is($genome_entity->class, $genome_class_name, 'Correct genome entity class name');
is($genome_entity->id, $library->id, 'Correct genome entity id');
ok($misc_update->perform_update, 'Perform update');
is($misc_update->result, 'PASS', 'Correct result after update');
is($misc_update->status, "PASS	UPDATE	test.library_summary	-101	protocol	'NA'	'NULL'	'awesome'", 'Correct status after update');
ok($misc_update->is_reconciled, 'Is reconciled');
ok(!$misc_update->error_message, 'No error after update');
is($library->protocol, 'awesome', 'Set protocol on library');

# Property not updated
$misc_update = Genome::Site::TGI::Synchronize::Classes::MiscUpdate->__define__(
    subject_class_name => 'test.library_summary',
    subject_id => $library->id,
    subject_property_name => 'full_name',
    editor_id => 'lims',
    edit_date => '2000-01-01 00:00:'.sprintf('%02d', $cnt++),
    old_value => $library->name,
    new_value => '__NEW_NAME__',
    description => 'UPDATE',
    is_reconciled => 0,
);
ok($misc_update, 'Create misc update for library name');
isa_ok($misc_update, 'Genome::Site::TGI::Synchronize::Classes::MiscUpdate::LibrarySummary');
is($misc_update->lims_table_name, 'library_summary', 'Correct lims table name');
$genome_class_name = $misc_update->genome_class_name;
is($genome_class_name, 'Genome::Library', 'Correct genome class name');
$genome_entity = $misc_update->genome_entity;
ok($genome_entity, 'Got genome entity');
is($genome_entity->class, $genome_class_name, 'Correct genome entity class name');
is($genome_entity->id, $library->id, 'Correct genome entity id');
ok(!$misc_update->perform_update, 'Perform update');
is($misc_update->result, 'SKIP', 'Correct result after update');
is($misc_update->status, "SKIP	UPDATE	test.library_summary	-101	full_name	'__TEST_LIBRARY__'	'__TEST_LIBRARY__'	'__NEW_NAME__'", 'Correct status after update');
ok(!$misc_update->is_reconciled, 'Is reconciled');
my $status_message = $misc_update->status_message;
is($status_message, 'Update for genome property name not supported => name', 'Correct status message');
is($library->name, '__TEST_LIBRARY__', 'Did not set name on library');

done_testing();
