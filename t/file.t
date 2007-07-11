use Test::More;
use Test::XML;

plan tests => 6;

require_ok( 'XHTML::Instrumented' );

my $x = XHTML::Instrumented->new(
    filename => 'examples/test'
);

is($x->path(), '.', 'path');

my $output = $x->instrument(
    content_tag => 'body',
    control => {},
);

my $cmp = <<DATA;
<div id="all">
test
</div>
DATA

is_xml($output, $cmp, 'test');

my $outfile = $x->outfile;

ok(-r $outfile, 'file created');

my $y = XHTML::Instrumented->new(
    filename => 'examples/test',
#    outfile => 'examples/test.cxi',
);

$output = $y->instrument(
    content_tag => 'body',
    control => {},
);

is_xml($output, $cmp, 'test');

unlink 'examples/test.cxi' or die $!;

ok(!-r 'examples/test.cxi', 'file deleted');
