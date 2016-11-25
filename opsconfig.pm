package opsconfig;

use strict;
use warnings;
use vars qw($VERSION);

$VERSION = "0.1";

sub new
{
    my $class = shift;
    my $filename = shift;
    my $self = {};
    bless $self, $class;
    $self->load($filename) if $filename;
    return $self;
}

sub fromString
{
    my $self = shift;
    my $string = shift;
    $string =~ s/\r//g;
    while($string =~ s/(.*?) = (.*)//)
    {
        $self->{$1} = $2;
    }
}

sub toString
{
    my $self = shift;
    my $string;
    foreach my $key (keys %$self)
    {
        my $value = $self->{$key};
        $string .= "$key = $value\n" unless $key eq "filename";
    }
    return $string;
}

sub load
{
    my $self = shift;
    my $filename = shift or die "opsconfig load: no filename given";
    if(open my $fh, $filename)
    {
        local $/ = undef;
        my $string = <$fh>;
        close $fh;
        $self->fromString($string);
    }
    $self->{filename} = $filename;
}

sub save
{
    my $self = shift;
    open my $fh, ">", $self->{filename} or die "opsconfig save: could not open ".$self->{filename}.": $!";
    print $fh $self->toString();
    close $fh;
}

sub clear
{
    my $self = shift;
    foreach my $key (keys %$self)
    {
        delete $self->{$key} unless $key eq "filename";
    }
}

1;
__END__
