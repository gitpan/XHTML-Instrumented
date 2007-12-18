use Test::More tests => 1;

eval 'use Test::Pod 1.00';
plan( skip_all => 'Test::Pod 1.00 required for testing POD' ) if $@;

eval 'use Test::Pod::Coverage 1.00';
plan( skip_all => 'Test::Pod::Coverage 1.00 required for testing POD coverage' ) if $@;

ok(1, "use Build testpod and Build testpodcoverage");
