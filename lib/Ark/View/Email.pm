package Ark::View::Email;

use Ark 'View';
our $VERSION = '0.01';

has email_mime => (
    is => 'rw',
    isa => 'Object',
    lazy => 1,
    
);

has header => (
    is => 'rw',
    isa => 'HashRef',
    lazy => 1,
    default => [],
);

has email => (
    is => 'rw',
    isa => 'HashRef',
    default => [],
    trigger => sub {
 
    }
)

sub process {
    my ( $self, $c ) = @_;

    croak "Unable to send mail, bad mail configuration"
      unless $self->mailer;

    my $email = $c->stash->{ $self->{stash_key} };
    croak "Can't send email without a valid email structure"
      unless $email;
    $self->email($email);

    # Default content type
    if ( exists $self->{content_type} and not $email->{content_type} ) {
        $self->email->{content_type} = $self->{content_type};
    }

    my $header = $email->{header} || [];
    if ( defined $email->{to} ) {
        push( @{$self->header}, ( 'To' => delete $email->{to} ) );
    }
    if ( defined $email->{cc} ) {
        push( @$header, ( 'Cc' => delete $email->{cc} ) );
    }
    if ( defined $email->{bcc} ) {
        push( @$header, ( 'Bcc' => delete $email->{bcc} ) );
    }
    if ( defined $email->{from} ) {
        push( @$header, ( 'From' => delete $email->{from} ) );
    }
    my $subject = Encode::encode( 'MIME-Header', delete $email->{subject} );
    if ( defined $email->{subject} ) {
        push( @$header, ( 'Subject' => $subject ) );
    }
    if ( defined $email->{content_type} ) {
        push( @$header, ( 'Content-type' => $email->{content_type} ) );
    }

    my $parts = $email->{parts};
    my $body  = $email->{body};

    unless ( $parts or $body ) {
        croak "Can't send email without parts or body, check stash";
    }

    my %mime = ( header => $header, attributes => {} );

    if ( $parts and ref $parts eq 'ARRAY' ) {
        $mime{parts} = $parts;
    }
    else {
        $mime{body} = $body;
    }

    if ( $email->{content_type} ) {
        $mime{attributes}->{content_type} = $email->{content_type};
    }
    if (   $mime{attributes}
        && not $mime{attributes}->{charset}
        && $self->{default}->{charset} )
    {
        $mime{attributes}->{charset} = $self->{default}->{charset};
    }

    my $message = $self->generate_message( $c, \%mime );

    if ($message) {
        my $return = $self->mailer->send($message);

        # return is a Return::Value object, so this will stringify as the error
        # in the case of a failure.
        croak "$return" unless $return;
    }
    else {
        croak "Unable to create message";
    }
}

sub generate_message {
    my ( $self, $c, $attr ) = @_;

    # setup the attributes (merge with defaults)
    $attr->{attributes} = $self->setup_attributes($c, $attr->{attributes});
    return Email::MIME->create(%$attr);
}

1;
__END__

=head1 NAME

Ark::View::Email -

=head1 SYNOPSIS

  use Ark::View::Email;

=head1 DESCRIPTION

Ark::View::Email is

=head1 AUTHOR

haoyayoi E<lt>st.hao.yayoi@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
