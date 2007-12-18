use Test::More tests => 1;

eval 'use Test::Pod 1.00';
plan( skip_all => 'Test::Pod 1.00 required for testing POD' ) if $@;

ok(1, q(use "Build testpod" for this test));
