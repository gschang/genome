#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok('Genome::Sample::Command::Import') or die;
ok(Genome::Sample::Command::Import::Tcga->__meta__, 'class meta for import tcga sample');

# basic import - no exsting patients/samples
my $taxon = Genome::Taxon->__define__(name => 'almost human');
ok($taxon, 'defined taxon');
my $name = 'TCGA-00-0000-01A-00R-0000-00';
my $import = Genome::Sample::Command::Import::Tcga->create(
    taxon => $taxon,
    name => $name,
);
ok($import, 'create');
$import->dump_status_messages(1);
ok($import->execute, 'execute');
is($import->_individual->name, 'TCGA-00-0000', 'individual name');
is($import->_individual->upn, 'TCGA-00-0000', 'individual upn');
is($import->_individual->nomenclature, 'TCGA', 'individual nomenclature');
is($import->_sample->name, $name, 'sample name');
is($import->_sample->common_name, 'tumor', 'sample common name');
is($import->_sample->nomenclature, 'TCGA', 'sample nomenclature');
is($import->_sample->extraction_label, $name, 'sample extraction label');
is($import->_sample->extraction_type, 'rna', 'sample extraction type');
is_deeply($import->_sample->source, $import->_individual, 'sample source');
is($import->_library->name, $name.'-extlibs', 'library name');
is_deeply($import->_library->sample, $import->_sample, 'library sample');

# import w/ existing patients/samples but the patient name is screwy
my $patient = Genome::Individual->create(
    name => 'H_00-D0000',
    upn => 'D0000',
    nomenclature => 'caTissue',
    taxon => $taxon,
);
ok($patient, 'create patient') or die;
my $sample = Genome::Sample->create(
    name => 'TCGA-11-1111-10A-00D-0000-00',
    extraction_label => 'TCGA-11-1111-10A-00D-0000-00',
    extraction_type => 'genomic dna',
    source => $patient,
    source_type => 'individual',
);
ok($sample, 'create sample') or die;
my $name2 = 'TCGA-11-1111-10A-00W-0000-00';
$import = Genome::Sample::Command::Import::Tcga->create(name => $name2);
ok($import, 'create');
$import->dump_status_messages(1);
ok($import->execute, 'execute');
is($import->_individual->name, 'H_00-D0000', 'individual name');
is($import->_individual->upn, 'D0000', 'individual upn');
is($import->_individual->nomenclature, 'caTissue', 'individual nomenclature');
is($import->_sample->name, $name2, 'sample name');
is($import->_sample->common_name, 'normal', 'sample common name');
is($import->_sample->nomenclature, 'TCGA', 'sample nomenclature');
is($import->_sample->extraction_label, $name2, 'sample extraction label');
is($import->_sample->extraction_type, 'ipr product', 'sample extraction type');
is_deeply($import->_sample->source, $import->_individual, 'sample source');
is($import->_library->name, $name2.'-extlibs', 'library name');
is_deeply($import->_library->sample, $import->_sample, 'library sample');

# fail
$import = Genome::Sample::Command::Import::Tcga->create(name => 'AGCT-00-0000-000-00R-0000-00');
ok($import, 'create');
$import->dump_status_messages(1);
ok(!$import->execute, 'execute failed for name that does not start w/ TCGA');
$import = Genome::Sample::Command::Import::Tcga->create(name => 'TCGA-00-0000-000-00R-0000');
ok($import, 'create');
$import->dump_status_messages(1);
ok(!$import->execute, 'execute failed for name w/o 7 parts');
$import = Genome::Sample::Command::Import::Tcga->create(name => 'TCGA-00-0000-000-00R-0000-00.5');
ok($import, 'create');
$import->dump_status_messages(1);
ok(!$import->execute, 'execute failed for name w/ a decimal');
$import = Genome::Sample::Command::Import::Tcga->create(name => 'TCGA-00-0000-000-00Z-0000-00');
ok($import, 'create');
$import->dump_status_messages(1);
ok(!$import->execute, 'execute failed for name w/ invalid extrraction type');

done_testing();
