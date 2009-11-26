package Ark::View::Email;

use Ark 'View';
our $VERSION = '0.01';

__PACKAGE__->config(
    stash_key   => 'email',
    default     => {
        content_type    => 'text/plain',
    },
);

has mailer => (
    is   => 'rw',
    isa  => 'Email::Send',
);

has mime => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => [],
);

has email => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => [],
)

sub Build {
    my $self = shift;
    my $sender = Email::Send->new;
    if ( my $mailer = $self->{sender}->{mailer} ) {
        croak "$mailer is not supported, see Email::Send"
            unless $sender->mailer_available($mailer);
        $sender->mailer($mailer);
    } else {
        for ( qw/SMTP Sendmail Qmail/ ) {
            $sender->mailer($_) and last if $sender->mailer_available($_);
        }
    }

    if ( my $args = $self->{sender}->{mailer_args} ) {
        if ( ref $args eq 'HASH' ) {
            $sender->mailer_args([ %$args ]);
        }
        elsif ( ref $args eq 'ARRAY' ) {
            $sender->mailer_args($args);
        } else {
            croak "Invalid mailer_args specified, check pod for Email::Send!";
        }
    }
    $self->mailer($sender);

    return $self;
}

sub process {
    my ( $self, $c ) = @_;

    croak "Unable to send mail, bad mail configuration" unless $self->mailer;
    my $email = $c->stash->{ $self->{stash_key} };
    croak "Can't send email without a valid email structure" unless $email;

    # Default content type
    if ( exists $self->{content_type} and not $email->{content_type} ) {
        $email->{content_type} = $self->{content_type};
    }

    my $header = $email->{header} || [];
    push( @$header, ( 'To'   => delete $email->{to} ) )   if $email->{to};
    push( @$header, ( 'Cc'   => delete $email->{cc} ) )   if $email->{cc};
    push( @$header, ( 'Bcc'  => delete $email->{bcc} ) )  if $email->{bcc};
    push( @$header, ( 'From' => delete $email->{from} ) ) if $email->{from};
    my $subject = Encode::encode( 'MIME-Header', delete $email->{subject} );
    push( @$header, ( 'Subject' => $subject ) ) if $email->{subject};
    push( @$header, ( 'Content-type' => $email->{content_type} ) )
      if $email->{content_type};

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

sub setup_attributes {
    my ( $self, $c, $attrs ) = @_;
    
    my $def_content_type    = $self->{default}->{content_type};
    my $def_charset         = $self->{default}->{charset};

    my $e_m_attrs = {};

    if (exists $attrs->{content_type} && defined $attrs->{content_type} && $attrs->{content_type} ne '') {
        $c->log->debug('A::V::Email uses specified content_type ' . $attrs->{content_type} . '.') if $c->debug;
        $e_m_attrs->{content_type} = $attrs->{content_type};
    }
    elsif (defined $def_content_type && $def_content_type ne '') {
        $c->log->debug("A::V::Email uses default content_type $def_content_type.") if $c->debug;
        $e_m_attrs->{content_type} = $def_content_type;
    }
   
    if (exists $attrs->{charset} && defined $attrs->{charset} && $attrs->{charset} ne '') {
        $e_m_attrs->{charset} = $attrs->{charset};
    }
    elsif (defined $def_charset && $def_charset ne '') {
        $e_m_attrs->{charset} = $def_charset;
    }

    return $e_m_attrs;
}

sub generate_message {
    my ( $self, $c, $attr ) = @_;

    # setup the attributes (merge with defaults)
    $attr->{attributes} = $self->setup_attributes( $c, $attr->{attributes} );
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
