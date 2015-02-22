#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT}               = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

#$::RD_TRACE = 1;
#$::RD_HINT = 1;

use Test::More;

use above "Genome";

use_ok('Genome::InstrumentData::Composite::Strategy')
  or die('test cannot continue');

my $strategy_fail = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data 
     aligned to contamination_ref using bwa 0.5.5 [-t 4] v1'
);
isa_ok($strategy_fail, 'Genome::InstrumentData::Composite::Strategy', 'created strategy');
$strategy_fail->dump_status_messages(1);
ok(!$strategy_fail->execute, 'strategy parsing failed as expected');

my $strategy = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data 
     aligned to contamination_ref using bwa 0.5.5 [-t 4] api v1'
);
isa_ok($strategy, 'Genome::InstrumentData::Composite::Strategy', 'created strategy');
ok($strategy->execute, 'parsed strategy');
is_deeply(
    $strategy->tree,
    {
        'action' => [
            {
                'params'    => '-t 4',
                'reference' => 'contamination_ref',
                'version'   => '0.5.5',
                'name'      => 'bwa',
                'type'      => 'align'
            }
        ],
        'data' => 'instrument_data',
        'api_version' => 'v1',
    },
    'parsed strategy as expected'
) or diag Data::Dumper::Dumper($strategy->tree);

my $strategy2 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data '
    . 'aligned to contamination_ref using bwa 0.5.5 [-t 4] '
    . 'then filtered using dusting v1 '
    . 'api v1' );
isa_ok($strategy2, 'Genome::InstrumentData::Composite::Strategy', 'created second strategy');

my $tree2 = $strategy2->execute();
ok($tree2, 'parsed second strategy');
is_deeply(
    $tree2,
    {
        'action' => [
            {
                'params' => '',
                'parent' => {
                    'params'    => '-t 4',
                    'reference' => 'contamination_ref',
                    'version'   => '0.5.5',
                    'name'      => 'bwa',
                    'type'      => 'align'
                },
                'version' => 'v1',
                'name'    => 'dusting',
                'type'    => 'filter'
            }
        ],
        'data' => 'instrument_data',
        'api_version' => 'v1',
    },
    'parsed second second as expected'
) or diag Data::Dumper::Dumper($tree2);

my $strategy3 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data 
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
        then (
                filtered using unaligned v1 then aligned to protein using rtg-mapx 1.2.3 then filtered using aligned v1
                and
                filtered using aligned v1
            )
            then aligned to virome_reference using rtg-map 1.2.3
     api v1'
);
isa_ok($strategy3, 'Genome::InstrumentData::Composite::Strategy', 'created third strategy');

ok($strategy3->execute, 'parsed third strategy');
is_deeply(
    $strategy3->tree,
    {
        'action' => [
            {
                'params' => '',
                'parent' => {
                    'params' => '',
                    'parent' => {
                        'params' => '',
                        'parent' => {
                            'params' => '',
                            'parent' => {
                                'params'    => '-t 4',
                                'reference' => 'contamination_ref',
                                'version'   => '0.5.5',
                                'name'      => 'bwa',
                                'type'      => 'align'
                            },
                            'version' => 'v1',
                            'name'    => 'unaligned',
                            'type'    => 'filter'
                        },
                        'reference' => 'protein',
                        'version'   => '1.2.3',
                        'name'      => 'rtg-mapx',
                        'type'      => 'align'
                    },
                    'version' => 'v1',
                    'name'    => 'aligned',
                    'type'    => 'filter'
                },
                'reference' => 'virome_reference',
                'version'   => '1.2.3',
                'name'      => 'rtg-map',
                'type'      => 'align'
            },
            {
                'params' => '',
                'parent' => {
                    'params' => '',
                    'parent' => {
                        'params'    => '-t 4',
                        'reference' => 'contamination_ref',
                        'version'   => '0.5.5',
                        'name'      => 'bwa',
                        'type'      => 'align'
                    },
                    'version' => 'v1',
                    'name'    => 'aligned',
                    'type'    => 'filter'
                },
                'reference' => 'virome_reference',
                'version'   => '1.2.3',
                'name'      => 'rtg-map',
                'type'      => 'align'
            }
        ],
        'data' => 'instrument_data',
        'api_version' => 'v1',
    },
    'parsed third strategy as expected'
) or diag Data::Dumper::Dumper($strategy3->tree);

my $strategy4 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data 
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
        then (
                filtered using unaligned v1 then aligned to protein using rtg-mapx 1.2.3 then filtered using aligned v1
            )
            then aligned to virome_reference using rtg-map 1.2.3
     api v1'
);
isa_ok($strategy4, 'Genome::InstrumentData::Composite::Strategy', 'created fourth strategy');

my $tree4 = $strategy4->execute();
ok($tree4, 'parsed fourth strategy');
is_deeply(
    $tree4,
    {
        'action' => [
        {
            'params' => '',
            'parent' => {
                'params' => '',
                'parent' => {
                    'params' => '',
                    'parent' => {
                        'params' => '',
                        'parent' => {
                            'params' => '-t 4',
                            'reference' => 'contamination_ref',
                            'version' => '0.5.5',
                            'name' => 'bwa',
                            'type' => 'align'
                        },
                        'version' => 'v1',
                        'name' => 'unaligned',
                        'type' => 'filter'
                    },
                    'reference' => 'protein',
                    'version' => '1.2.3',
                    'name' => 'rtg-mapx',
                    'type' => 'align'
                },
                'version' => 'v1',
                'name' => 'aligned',
                'type' => 'filter'
            },
            'reference' => 'virome_reference',
            'version' => '1.2.3',
            'name' => 'rtg-map',
            'type' => 'align'
        }
        ],
        'data' => 'instrument_data',
        'api_version' => 'v1',
    },
    'parsed fourth strategy as expected',
) or diag Data::Dumper::Dumper($tree4);

my $strategy5 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data 
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
        then (
                filtered using unaligned v1 then aligned to protein using rtg-mapx 1.2.3 then filtered using aligned v1
                and
                filtered using aligned v1
                and
                filtered using dusting v1
            )
            then aligned to virome_reference using rtg-map 1.2.3
     api v1'
);
isa_ok($strategy5, 'Genome::InstrumentData::Composite::Strategy', 'created fifth strategy');

ok($strategy5->execute, 'parsed fifth strategy');

my $parent5 = {
    'params' => '-t 4',
    'reference' => 'contamination_ref',
    'version' => '0.5.5',
    'name' => 'bwa',
    'type' => 'align'
};

is_deeply(
    $strategy5->tree,
    {
        'action' => [
        {
            'params' => '',
            'parent' => {
                'params' => '',
                'parent' => {
                    'params' => '',
                    'parent' => {
                        'params' => '',
                        'parent' => $parent5,
                        'version' => 'v1',
                        'name' => 'unaligned',
                        'type' => 'filter'
                    },
                    'reference' => 'protein',
                    'version' => '1.2.3',
                    'name' => 'rtg-mapx',
                    'type' => 'align'
                },
                'version' => 'v1',
                'name' => 'aligned',
                'type' => 'filter'
            },
            'reference' => 'virome_reference',
            'version' => '1.2.3',
            'name' => 'rtg-map',
            'type' => 'align'
        },
        {
            'params' => '',
            'parent' => {
                'params' => '',
                'parent' => $parent5,
                'version' => 'v1',
                'name' => 'aligned',
                'type' => 'filter'
            },
            'reference' => 'virome_reference',
            'version' => '1.2.3',
            'name' => 'rtg-map',
            'type' => 'align'
        },
        {
            'params' => '',
            'parent' => {
                'params' => '',
                'parent' => $parent5,
                'version' => 'v1',
                'name' => 'dusting',
                'type' => 'filter'
            },
            'reference' => 'virome_reference',
            'version' => '1.2.3',
            'name' => 'rtg-map',
            'type' => 'align'
        }
        ],
        'data' => 'instrument_data',
        'api_version' => 'v1',
    },
    'parsed expression as expected'
) or diag Data::Dumper::Dumper($strategy5->tree);

my $strategy6 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data 
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
     then merged using picard 1.29 then deduplicated using picard 1.29
     api v1'
);
isa_ok($strategy6, 'Genome::InstrumentData::Composite::Strategy', 'created merge strategy');
ok($strategy6->execute, 'parsed merge strategy');
is_deeply(
    $strategy6->tree,
    {
        'action' => [
            {
                'params'    => '-t 4',
                'reference' => 'contamination_ref',
                'version'   => '0.5.5',
                'name'      => 'bwa',
                'type'      => 'align'
            }
        ],
        'then' => {
            'params' => '',
            'then' => {
                'params' => '',
                'version' => '1.29',
                'name' => 'picard',
                'type' => 'deduplicate'
            },
            'version' => '1.29',
            'name' => 'picard',
            'type' => 'merge'
        },
        'data' => 'instrument_data',
        'api_version' => 'v1',
    },
    'parsed merge strategy as expected'
) or diag Data::Dumper::Dumper($strategy6->tree);

my $strategy7 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
     then merged using picard 1.29 then deduplicated using picard 1.29
     then refined to variant_list using gatk-read-calibrator 0.01 [-et NO_ET]
     api v2'
);
isa_ok($strategy7, 'Genome::InstrumentData::Composite::Strategy', 'created merge strategy');
ok($strategy7->execute, 'parsed merge strategy');
is_deeply(
    $strategy7->tree,
    {
        'action' => [
            {
                'params'    => '-t 4',
                'reference' => 'contamination_ref',
                'version'   => '0.5.5',
                'name'      => 'bwa',
                'type'      => 'align'
            }
        ],
        'then' => {
            'params' => '',
            'then' => {
                'params' => '',
                'version' => '1.29',
                'name' => 'picard',
                'type' => 'deduplicate',
                then => {
                    params => '-et NO_ET',
                    version => '0.01',
                    name => 'gatk-read-calibrator',
                    type => 'refine',
                    known_sites => 'variant_list'
                }
            },
            'version' => '1.29',
            'name' => 'picard',
            'type' => 'merge'
        },
        'data' => 'instrument_data',
        'api_version' => 'v2',
    },
    'parsed merge strategy as expected'
) or diag Data::Dumper::Dumper($strategy7->tree);

# Test new clip-overlap refiner
my $strategy8 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
     then merged using picard 1.29 then deduplicated using picard 1.29
     then refined using clip-overlap 1.0.11
     api v2'
);
isa_ok($strategy8, 'Genome::InstrumentData::Composite::Strategy', 'created merge strategy');
ok($strategy8->execute, 'parsed merge strategy');
is_deeply(
    $strategy8->tree,
    {
        'action' => [
            {
                'params'    => '-t 4',
                'reference' => 'contamination_ref',
                'version'   => '0.5.5',
                'name'      => 'bwa',
                'type'      => 'align'
            }
        ],
        'then' => {
            'params' => '',
            'then' => {
                'params' => '',
                'version' => '1.29',
                'name' => 'picard',
                'type' => 'deduplicate',
                then => {
                    'params' => '',
                    'version' => '1.0.11',
                    'name' => 'clip-overlap',
                    'type' => 'refine',
                },
            },
            'version' => '1.29',
            'name' => 'picard',
            'type' => 'merge'
        },
        'data' => 'instrument_data',
        'api_version' => 'v2',
    },
    'parsed merge strategy as expected'
) or diag Data::Dumper::Dumper($strategy8->tree);

# Test new and multiple refiners
my $strategy9 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
     then merged using picard 1.29 then deduplicated using picard 1.29
     then refined to variant_list using gatk-read-calibrator 0.01 [-et NO_ET]
     then refined using clip-overlap 1.0.11
     api v2'
);
isa_ok($strategy9, 'Genome::InstrumentData::Composite::Strategy', 'created merge strategy');
ok($strategy9->execute, 'parsed merge strategy');
is_deeply(
    $strategy9->tree,
    {
        'action' => [
            {
                'params'    => '-t 4',
                'reference' => 'contamination_ref',
                'version'   => '0.5.5',
                'name'      => 'bwa',
                'type'      => 'align'
            }
        ],
        'then' => {
            'params' => '',
            'then' => {
                'params' => '',
                'version' => '1.29',
                'name' => 'picard',
                'type' => 'deduplicate',
                then => {
                    params => '-et NO_ET',
                    version => '0.01',
                    name => 'gatk-read-calibrator',
                    type => 'refine',
                    known_sites => 'variant_list',
                    then => {
                        'params' => '',
                        'version' => '1.0.11',
                        'name' => 'clip-overlap',
                        'type' => 'refine',
                    },
                }
            },
            'version' => '1.29',
            'name' => 'picard',
            'type' => 'merge'
        },
        'data' => 'instrument_data',
        'api_version' => 'v2',
    },
    'parsed merge strategy as expected'
) or diag Data::Dumper::Dumper($strategy9->tree);

# Test new and multiple refiners in reverse order
my $strategy10 = Genome::InstrumentData::Composite::Strategy->create(strategy =>
    'instrument_data
     aligned to contamination_ref using bwa 0.5.5 [-t 4]
     then merged using picard 1.29 then deduplicated using picard 1.29
     then refined using clip-overlap 1.0.11
     then refined to variant_list using gatk-read-calibrator 0.01 [-et NO_ET]
     api v2'
);
isa_ok($strategy10, 'Genome::InstrumentData::Composite::Strategy', 'created merge strategy');
ok($strategy10->execute, 'parsed merge strategy');
is_deeply(
    $strategy10->tree,
    {
        'action' => [
            {
                'params'    => '-t 4',
                'reference' => 'contamination_ref',
                'version'   => '0.5.5',
                'name'      => 'bwa',
                'type'      => 'align'
            }
        ],
        'then' => {
            'params' => '',
            'then' => {
                'params' => '',
                'version' => '1.29',
                'name' => 'picard',
                'type' => 'deduplicate',
                then => {
                    'params' => '',
                    'version' => '1.0.11',
                    'name' => 'clip-overlap',
                    'type' => 'refine',
                    then => {
                        params => '-et NO_ET',
                        version => '0.01',
                        name => 'gatk-read-calibrator',
                        type => 'refine',
                        known_sites => 'variant_list',
                    },
                }
            },
            'version' => '1.29',
            'name' => 'picard',
            'type' => 'merge'
        },
        'data' => 'instrument_data',
        'api_version' => 'v2',
    },
    'parsed merge strategy as expected'
) or diag Data::Dumper::Dumper($strategy10->tree);
done_testing();
