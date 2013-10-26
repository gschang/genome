#!/usr/bin/env genome-perl
use above "Genome";
use Test::More;

use Genome::Model::TestHelpers qw(
    create_test_sample
);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

define_test_classes();

my $sample = create_test_sample('test_sample');
my ($build_can, $build_cant) = create_test_builds("test", $sample);

my $class = "Genome::Model::Build::Command::Validate";
use_ok($class);

test_builds_can();
test_statuses();
test_reference_sequences();
test_processing_profile();

done_testing();

sub test_builds_can {
    my $command_fails = $class->create(builds => [$build_can, $build_cant], builds_can => ["test_property"]);
    my $rv;
    eval {$rv = $command_fails->execute};
    ok($@ =~ m/One or more builds failed validation/, 'Command Failed as expected');

    my $command_succeeds = $class->create(builds => [$build_can, $build_cant], builds_can => ["id"]);
    ok($command_succeeds->execute, "Command succeeded");
}

sub test_statuses {
    $build_can->status('Succeeded');
    $build_cant->status('Failed');
    my $command_fails = $class->create(builds => [$build_can, $build_cant], status => ['Succeeded']);
    my $rv;
    eval {$rv = $command_fails->execute};
    ok($@ =~ m/One or more builds failed validation/, 'Command Failed as expected');

    my $command_succeeds = $class->create(builds => [$build_can, $build_cant], status => ["Succeeded", "Failed"]);
    ok($command_succeeds->execute, "Command succeeded");
}

sub test_reference_sequences {
    my $ref_pp = Genome::ProcessingProfile::ReferenceSequence->create(name => 'test_ref_seq_pp');
    my $ref_seq_model = Genome::Model::ReferenceSequence->create(processing_profile => $ref_pp, subject => $sample,
        name => 'test_reference_sequence');
    my $ref_seq1 = Genome::Model::Build::ReferenceSequence->create(model => $ref_seq_model);
    my $ref_seq2 = Genome::Model::Build::ReferenceSequence->create(model => $ref_seq_model);

    $build_can->reference_sequence_build($ref_seq1);
    $build_cant->reference_sequence_build($ref_seq2);
    my $command_fails = $class->create(builds => [$build_can, $build_cant], reference_sequence => [$ref_seq1]);
    my $rv;
    eval {$rv = $command_fails->execute};
    ok($@ =~ m/One or more builds failed validation/, 'Command Failed as expected');

    my $command_succeeds = $class->create(builds => [$build_can, $build_cant],
        reference_sequence => [$ref_seq1, $ref_seq2]);
    ok($command_succeeds->execute, "Command succeeded");
}

sub test_processing_profile {
    my $command_fails = $class->create(builds => [$build_can, $build_cant],
        processing_profile => [$build_can->processing_profile]);
    my $rv;
    eval {$rv = $command_fails->execute};
    ok($@ =~ m/One or more builds failed validation/, 'Command Failed as expected');

    my $command_succeeds = $class->create(builds => [$build_can, $build_cant],
        processing_profile => [$build_can->processing_profile, $build_cant->processing_profile]);
    ok($command_succeeds->execute, "Command succeeded");
}

sub define_test_classes {
    class Genome::Model::TestCan {
        is => 'Genome::ModelDeprecated',
    };

    class Genome::ProcessingProfile::TestCan {
        is => 'Genome::ProcessingProfile',
    };
    class Genome::Model::Build::TestCan {
        is => 'Genome::Model::Build',
        has => [
            test_property => {
                is => 'String',
                default => "test",
            },
            reference_sequence_build => {
                is => 'Genome::Model::Build::ReferenceSequence',
                is_optional => 1,
            },
        ],
    };

    class Genome::Model::TestCant {
        is => 'Genome::ModelDeprecated',
    };

    class Genome::ProcessingProfile::TestCant {
        is => 'Genome::ProcessingProfile',
    };
    class Genome::Model::Build::TestCant {
        is => 'Genome::Model::Build',
        has => [
            reference_sequence_build => {
                is => 'Genome::Model::Build::ReferenceSequence',
                is_optional => 1,
            },
        ],
    };
}

sub create_test_builds {
    my ($base_name, $subject) = @_;

    my @pps, @models, @builds;
    for my $type ("TestCan", "TestCant") {
        my $pp_class = "Genome::ProcessingProfile::$type";
        my $pp = $pp_class->create(
            name => $base_name . $type,
        );
        ok($pp, sprintf('created test pp with name: %s, id: %s',
                $pp->name, $pp->id)) or die;
        push @pps, $pp;

        my $model_class = "Genome::Model::$type";
        my $model = $model_class->create(
            name => $base_name . $type,
            processing_profile => $pp,
            subject => $subject,
        );
        push @models, $model;
        ok($model, sprintf('created test model with name: %s, id: %s',
                $model->name, $model->id)) or die;

        my $build_class = "Genome::Model::Build::$type";
        my $build = $build_class->create(
            model => $model,
        );
        push @builds, $build;
        ok($build, sprintf('created test build id: %s', $build->id)) or die;
    }

    return (@builds);
}
