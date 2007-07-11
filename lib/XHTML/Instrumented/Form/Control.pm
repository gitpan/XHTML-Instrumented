use strict;

package
    XHTML::Instrumented::Form::Control;

use base 'XHTML::Instrumented::Control';

use Carp qw(croak);

sub args 
{
    my $self = shift;

    my %hash;
    $hash{action} = $self->{self}{action} if $self->{self}{action};
    $hash{method} = $self->{self}{method} if $self->{self}{method};
    ('method', 'post', @_, %hash );
}

sub expand_content
{
    my $self = shift;

    my @ret = @_;

    for my $hidden ($self->{self}->auto()) {
	warn 'need value for ' . $hidden->name unless $hidden->value;
	next unless $hidden->value;
	unshift(@ret, sprintf(qq(<input name="%s" type="hidden" value="%s"/>), $hidden->name, $hidden->value));
    }
    $self->SUPER::expand_content(@ret);
}

sub is_form
{
    1;
}

sub form
{
    shift->{self};
}

sub get_element
{
    my $self = shift;
    my $name = shift or croak('need a name');
    my $form = $self->{self};

    my $ret = $form->{elements}{$name};

    if ($ret) {
	if ($ret->is_multi) {
	    $ret->{default} = [ $form->element_values($name) ];
	} else {
	    $ret->{default} = $form->element_value($name);
	}
    }

    return $ret;
}

1;
__END__
