use strict;
use warnings;

package XHTML::Instrumented;

use XHTML::Instrumented::Entry;
use XHTML::Instrumented::Context;

use Carp qw (croak verbose);
use XML::Parser;

our $VERSION = '0.00';

our @CARP_NOT = ( 'XML::Parser::Expat' );

use Params::Validate qw( validate SCALAR SCALARREF BOOLEAN HASHREF OBJECT UNDEF CODEREF );

our $path = '.';
our $outpath = '/tmp/xhtmli/';

sub path
{
    $path;
}

sub outpath
{
    $outpath;
}

sub outfile
{
    my $self = shift;
    my $file = $self->outpath;

    if ($self->{type}) {
	$file .= '/' . $self->{type};
	$file .= '/' . $self->{name};
	$file .= '.cxi';
    } else {
        $file = $self->{filename} . '.cxi';
    }
    return $file;
}

sub import
{
    my $class = shift;

    my $tag = shift;
    if (defined $tag && $tag eq 'path') {
        $path = shift;
    } else {
        die "Unknow key: " . $tag if $tag;
    }
}

sub new
{
    my $class = shift;
    my $self = bless { validate(@_, {
        'name' => {
	    type => SCALAR | SCALARREF,
	    optional => 1,
	},
        'type' => {
	    type => SCALAR,
	    optional => 1,
        },
        'default_type' => {
	    type => SCALAR,
	    optional => 1,
        },
        'filename' => {
	    type => SCALAR,
	    optional => 1,
        },
        'filter' => {
	    optional => 1,
	    type => CODEREF,
	},
        'replace_name' => {
	    optional => 1,
	    type => SCALAR,
	},
    })}, $class;

    my $path = $self->path();
    my $type = $self->{type} || '';
    my $name = $self->{name};
    my $filename = $self->{filename};
    my $alt_filename = $self->{filename};

    unless ($filename or ref($name) eq 'SCALAR') {
	$filename = $self->{filename} = "$path/$type/$name";
	my $type = $self->{default_type} || '';
	unless (-f "$filename.html") {
	    $filename = $self->{filename} = "$path/$type/$name";
	}
    }

    if ($filename) {
	my $outfile = $self->outfile;
	my @path = split('/', $outfile);
	pop @path;

        if (-r $outfile and ( -M $outfile < -M  $filename . '.html')) {
            require Storable;
	    $self->{parsed} = Storable::retrieve($outfile);
	} elsif ( -r $filename . '.html') {
	    $self->{parsed} = $self->parse(
		$filename . '.html',
		name => $name,
		type => $self->{type},
		default_type => $self->{default_type},
		replace_name => $self->{replace_name} || 'home',
	    );
	    my $path = '';
	    while (@path) {
	       $path .= shift(@path) . '/';
	       unless ( -d $path ) {
		   mkdir $path or die 'Bad path ' . $path .  " $outfile @path";
	       }
	    }
	    require Storable;
	    Storable::store($self->{parsed}, $outfile );
	} else {
	    die "File not found: $filename";
	}
    } else {
	unless (ref($name) eq 'SCALAR') {
	    croak "no template for $name [$path/$type/$name.tmpl]" unless (-f "$path/$type/$name.tmpl");
	}
	$self->{parsed} = $self->parse(
	    $name
	);
    }

    $self;
}

# helper functions

sub loop
{
    my $self = shift;
    my %p = validate(@_, {
       headers => 0,
       data => 0,
       inclusive => 0,
       default => 0,
    });
    require XHTML::Instrumented::Loop;

    XHTML::Instrumented::Loop->new(%p);
}

sub get_form
{
    my $self = shift;

    require XHTML::Instrumented::Form;
    XHTML::Instrumented::Form->new(@_);
}

sub replace
{
    my $self = shift;
    my %p = validate(@_, {
       args => 0,
       text => 0,
       src => 0,
       replace => 0,
       remove => 0,
       remove_tag => 0,
    });
    require XHTML::Instrumented::Control;
    XHTML::Instrumented::Control->new(%p);
}

sub args
{
    my $self = shift;

    $self->replace(args => { @_ });
}

our @unused;

# the main function
sub _filename
{
    my $self = shift;
    my ($path, $type, $name);
    unless (-f "$path/$type/$name.tmpl") {
	$type = $self->{default_type} || 'default';
    }
    die "no template for $name [$path/$type/$name.tmpl]" unless (-f "$path/$type/$name.tmpl");
    my $file = "$path/$type/$name.tmpl";
}	

sub parse
{
    my $self = shift;
    my $data = shift;

    @unused = ();
    my $parser = new XML::Parser::Expat(
	NoExpand => 1,
	ErrorContext => 1,
	ProtocolEncoding => 'utf-8',
    );
    $parser->setHandlers('Start' => \&_sh,
			 'End'   => \&_eh,
			 'Char'  => \&_ch,
			 'Attlist'  => \&_ah,
			 'Entity' => \&_ah,
			 'Element' => \&_ah,
			 'Default' => \&_ex,
			 'Unparsed' => \&_cm,
			);
    $parser->{_OFF_} = 0;
    $parser->{__filter__} = $self->{filter};
    $parser->{__ids__} = {};
    $parser->{__idr__} = {};
    $parser->{__args__} = { @_ };

    $self->{_parser} = $parser;

    my $type = $self->{type};
    my $name = $self->{name};
    my %hash = (@_);

    $parser->{__data__} = {};  # FIXME this may need to be set
    $parser->{__top__} = XHTML::Instrumented::Entry->new(
	tag => '__global__',
	flags => {},
	args => {},
    );
    $parser->{__context__} = [ $parser->{__top__} ];

    if (ref($data) eq 'SCALAR') {
        my $html = ${$data};
	eval {
	    $parser->parse($html);
	};
	if ($@) {
	    die "$@";
	}
    } else {
        my $filename = $data;
	eval {
	    $parser->parsefile($filename);
	};
	if ($@) {
	    die "$@ $filename";
	}
    }
    bless({
        idr => $parser->{__idr__},
	data => $parser->{__top__}->{data}
    }, 'XHTML::Intramented::Parsed');
}

sub _get_tag
{
    my $tag = shift;
    my $start = shift;
    my $data = $start;

    for my $element (@$data) {
	next unless ref($element);

	return $element if $element->{tag} eq $tag;

	my $data = _get_tag($tag, $element->{data});
	return $data if $data;
    }
    undef;
}

sub instrument
{
    my $self = shift;
    my %p = validate(@_, {
        content_tag => 1,
        control => {
	},
    });
    my $data = {};
    my $ret;

    $data->{data} = [ $self->{parsed}{data} ];

    if (my $tag = $p{content_tag}) {
        $data = _get_tag($tag, $self->{parsed}{data});
	$data->{data} = [ @{$self->{parsed}{data}} ] unless $data;
    }
    my $hash = $p{control} || {};

    for my $element ( @{$data->{data}} ) {
        if (ref($element)) {
	    $ret .= $element->expand(
	        context => XHTML::Instrumented::Context->new(
		    hash => $hash,
		),
	    );
	} else {
	    $ret .= $element;
	}
    }

    $ret;
}

sub output
{
    my $self = shift;
    my %hash = (@_);

    return $self->instrument(
        content_tag => 'body',
	control => { %hash },
    );
}

our $level = 0;

use Encode;

sub _fixup
{
    my @ret;
    for my $data (@_) {
        $data =~ s/&/&amp;/g;
        my $x = $data;

	push @ret, $data;
    }
    @ret;
}

sub _ex
{
    my $self = shift;

    push(@{$self->{__context__}[-1]->{data}}, @_);
}

sub _cm
{
    die "Don't know how to handle Unparsed Data";
}

sub _sh
{
    my $self = shift;
    my $tag = shift;
    my %args = @_;

    my $top = $self->{__context__}->[-1];

    if (my $code = $self->{__filter__}) {
        $code->(
	   tag => $tag,
	   args => \%args,
	);
    }

    for my $key (keys %args) {
	my %hash = %{$self->{__data__}};
	if ($args{$key} =~ /\@\@([A-Za-z][A-Za-z0-9_-][^.@]*)\.?([^@]*)\@\@/) {
	    die q(Can't do this);
	}
	$args{$key} =~ s/\@\@([A-Za-z][A-Za-z0-9_-][^.@]*)\.?([^@]*)\@\@/
	    my @extra = split('\.', $2);
	    my $name = $1;
	    my $extra = $2;
	    my $type = $hash{$1};
	    if (defined $type) {
	       $type;
	    } else {
	       qq(-- $1 --);
	    }
	    /xge;
    }
    my %local = ();

    my $child = $top->child(
	tag => $tag,
	args => \%args,
    );
    if (my $id = $child->id) {
	warn "Duplicate id: $id" if exists $self->{__ids__}{$id};
        $self->{__ids__}{$args{id}}++;
        $self->{__idr__}{$id} = $child;
    }
    if (exists($self->{_inform_}) && $child->name && $child->id) {
        $self->{_inform_}->{_ids_}{$child->id} = $child->name;
        $self->{_inform_}->{_names_}{$child->name} = $child->id;
    }
    if (exists($self->{_inform_}) && $child->name) {
	my $form_id = $self->{_inform_id_};
	$self->{_inform_ids_}{$form_id}{$child->name} = $tag;
    }
    push(@{$self->{__context__}},
        $child,    
    );
    if ($tag eq 'form') {
	$self->xpcroak('embeded form') if ($self->{_inform_});
	$self->{_inform_} = $child;
	if (my $id = $args{id} || $args{name}) {
	    $self->{_inform_id_} = $id;
	    $self->{_inform_ids_}{$id} = {};
	}
    }
    return undef;
}

{
    package
        XML::Parser::Expat;

    sub clone {
        my $self = shift;
	my $parser = new XML::Parser::Expat(
	    NoExpand => $self->{'NoExpand'},
	    ErrorContext => $self->{'ErrorContext'},
	    ProtocolEncoding => $self->{'ProtocolEncoding'},
	);
	$parser->{__data__} = {};
	$parser->{__top__} = XHTML::Instrumented::Entry->new(
	    tag => 'div',
	    flags => {},
	    args => {},
	);
	$parser->{__context__} = [ $parser->{__top__} ];
        return $parser;
    }
}

sub _eh
{
    my $self = shift;
    my $tag = shift;
    my $current = pop(@{$self->{__context__}});
    my $parent = $self->{__context__}->[-1];

    my $args = { $current->args };

    die "mismatched tags $tag " . $current->tag unless $tag eq $current->tag;

    if ($args->{class} && grep(/:removetag/, split('\s+', $args->{class}))) {
	$parent->append(@{$current->{data} || []});
	return;
    }
    if ($args->{class} && grep(/:remove/, split('\s+', $args->{class}))) {
	return;
    }

    if ($args->{class} && grep(/:replace/, split('\s+', $args->{class}))) {
	my $out;
	my $gargs = $self->{__args__};
	my $default = $gargs->{default_replace};
	my ($name, $file) = split('.', $args->{id});

	die if $file;

use Data::Dumper;
warn Dumper $self->{__args__};

	if ($self->{__args__}{name} ne 'home') {
	    $out = XHTML::Instrumented->new(
	       %{$gargs},
	       name => 'home',
	    );
	} else {
	}

if ($out) {
    my $id = $args->{id};
warn "replaced: $id";
    $current = $out->{parsed}{idr}{$id};
}
    }

    $parent->append($current);

    if ($tag eq 'form') {
	delete $self->{_inform_};
    }
}

sub _ah
{
    my $self = shift;
    $self->xpcroak(@_);
    die;
}

sub _ch
{
    my $self = shift;
    my $context = $self->{__context__}->[-1];
    my $data = shift;
    my %hash = %{$self->{__data__}};

    my @ret;

    $data = join('', _fixup($data));

    if ($context->{flags} & 1) {
        ;
    } else {
        my @x = split(/(\@\@[A-Za-z][A-Za-z0-9_-][^.@]*\.?[^@]*\@\@)/, $data);
	if (@x > 1) {
	    for my $p (@x) {
		if ($p =~ m/\@\@([A-Za-z][A-Za-z0-9_-][^.@]*)\.?([^@]*)\@\@/) {
		    push @ret,
		    XHTML::Instrumented::Entry->new(
			tag => '__special__',
			flags => {rs => 1},
			args => {},
			data => [ "-- $p --" ],
			id => $1,
		    );
		} else {
		    push @ret, $p;
		}
	    }
	} else {
	    push @ret, $data;
	}
	$data =~ s/\@\@([A-Za-z][A-Za-z0-9_-][^.@]*)\.?([^@]*)\@\@/
	    my @extra = split('\.', $2);
	    my $name = $1;
	    my $extra = $2;
	    my $type = $hash{$1};
	    XHTML::Instrumented::Entry->new(
		tag => '__special__',
		flags => {},
		args => {},
		id => $name,
	    );
	    /xge;
    }
    push(@{$context->{data}}, @ret);
}

1;
__END__

=head1 NAME

XHTML::Instrumented - packages to control XHTML

=head1 DESCRIPTION

This package takes valid XHTML as input and outputs valid XHTML that may
be changed in several ways.

=head1 SYNOPSIS

=head1 API

=head2 Constructor

=over

=item new(file => [I<filename> | SCALAR ])

Get a XHTML::Instrumented object.

=back

=head2 Functions

=over

=item parse(input)

This causes the input to be parsed.

if I<input> is string it is assumed to be a filename.
If I<input> is a SCALAR is is treated as HTML;

=item instrument

This function take the template and the control structure and returns a block of XHTML.

=back

=head2 Methods

=over

=item output

This returns the modified xhtml.

=item get_form

This returns a form object.

=item loop

   headers => [array of headers]
   data => [arrays of data]
   default => default value for any undefined data
   inclusive => include the tag that started the loop

inclusive is normally controlled in the template.

=item replace

=item args

same as replace(args => { @_ });

=back

=head2 Functions

=over

=item path

Get the default path to the templates

=item outpath

Get the default path to the compiled templates

=item outfile

Get the full path and filename of the compiled template.

=back

=head1 AUTHOR

"G. Allen Morris III" <gam3@gam3.net>

=cut
