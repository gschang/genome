#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DUMP_STATUS_MESSAGES} = 1;
};

use above 'Genome';

use Test::More tests => 11;
use Genome::Test::Factory::Model::ReferenceAlignment;
use Genome::Test::Factory::InstrumentData::Solexa;

use_ok('Genome::Project::Command::Update::Models') or die;

my $project = Genome::Project->create(name => 'test project for ' . __FILE__);
isa_ok($project, 'Genome::Project', 'created test project');

my @models;
my @instrument_data;
for(1..3) {
    my $m = Genome::Test::Factory::Model::ReferenceAlignment->setup_object(
        user_name => 'apipe-builder',
    );
    my $i = Genome::Test::Factory::InstrumentData::Solexa->setup_object();
    $m->add_instrument_data($i);
    push @models, $m;
    push @instrument_data, $i;
}

$project->add_part(entity => $models[0]->subject);
$project->add_part(entity => $instrument_data[1]);

my $instrument_data_match_cmd = Genome::Project::Command::Update::Models->create(
    projects => [$project],
    match_type => 'instrument_data',
);
isa_ok($instrument_data_match_cmd, 'Genome::Project::Command::Update::Models');
ok($instrument_data_match_cmd->execute, 'ran instrument data matching mode');

is(scalar($project->get_parts_of_class('Genome::Model')), 1, 'assigned matching model for instrument data');

my $sample_match_cmd = Genome::Project::Command::Update::Models->create(
    projects => [$project],
    match_type => 'sample',
);
isa_ok($sample_match_cmd, 'Genome::Project::Command::Update::Models');
ok($sample_match_cmd->execute, 'ran sample matching mode');

is(scalar($project->get_parts_of_class('Genome::Model')), 2, 'assigned matching model for sample');

my $repeated_sample_match_cmd = Genome::Project::Command::Update::Models->create(
    projects => [$project],
    match_type => 'sample',
);
isa_ok($repeated_sample_match_cmd, 'Genome::Project::Command::Update::Models');
ok($repeated_sample_match_cmd->execute, 'ran sample matching mode again');

is(scalar($project->get_parts_of_class('Genome::Model')), 2, 'models assigned are still the same on a re-run');

