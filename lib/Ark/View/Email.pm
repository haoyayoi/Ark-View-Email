package Ark::View::Email;
use Ark 'View';

our $VERSION = '0.01';

has stash_key => (
    is      => 'rw',
    isa     => 'Str',
    default => 'email',
);

has content_type => (
    is      => 'rw',
    isa     => 'Str',
    default => 'text/plain',
);

has charset => (
    is      => 'rw',
    isa     => 'Str',
    default => 'iso-8859-2',
);

has sender => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;

        $self->ensure_class_loaded('Email::Sender::Simple');
        Email::Sender::Simple->import;
    }
);

has mailer => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        my $self = shift;

        $self->ensure_class_loaded('Email::MIME');
        Email::MIME->import;
    }
);

has mime => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { [] },
);

has email => (
    is      => 'rw',
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { [] },
);

sub process {
    my ( $self, $c ) = @_;
    
    if ( my $args = $self->{sender}->{mailer_args} ) {
        if ( ref $args eq 'HASH' ) {
            $self->mailer->mailer_args( [%$args] );
        }
        elsif ( ref $args eq 'ARRAY' ) {
            $self->mailer->mailer_args($args);
        }
        else {
            $c->log( warn =>
                  "Invalid mailer_args specified, check pod for Email::Sender!"
            );
        }
    }

    my $email = $c->stash->{ $self->stash_key };
    unless ($email) {
        $c->log( warn => "Can't send email without a valid email structure" );
    }

    # Default content type
    if ( not $email->{content_type} ) {
        $email->{content_type} = $self->content_type;
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
        $c->log(
            warn => "Can't send email without parts or body, check stash" );
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
        $mime{attributes}->{charset} = $self->charset;
    }

    my $message = $self->generate_message( $c, \%mime );
    if ($message) {
        eval { $self->sender->sendmail($message); };
        if ($@) {
            $c->log( $@->message );
        }
    }
}

sub setup_attributes {
    my ( $self, $c, $attrs ) = @_;

    my $content_type = $self->content_type;
    my $charset      = $self->charset;

    my $e_m_attrs = {};

    if (   exists $attrs->{content_type}
        && defined $attrs->{content_type}
        && $attrs->{content_type} ne '' )
    {
        $c->log->debug( 'Ark::View::Email uses specified content_type '
              . $attrs->{content_type}
              . '.' )
          if $c->debug;
        $e_m_attrs->{content_type} = $attrs->{content_type};
    }
    else {
        $c->log->debug(
            "Ark::View::Email uses default content_type $content_type.")
          if $c->debug;
        $e_m_attrs->{content_type} = $content_type;
    }

    if (   exists $attrs->{charset}
        && defined $attrs->{charset}
        && $attrs->{charset} ne '' )
    {
        $e_m_attrs->{charset} = $attrs->{charset};
    }
    else {
        $e_m_attrs->{charset} = $charset;
    }

    return $e_m_attrs;
}

sub generate_message {
    my ( $self, $c, $attr ) = @_;

    # setup the attributes (merge with defaults)
    $attr->{attributes} = $self->setup_attributes( $c, $attr->{attributes} );
    return $self->mailer->create(%$attr);
}

1;
__END__

=head1 NAME

Ark::View::Email - Email view class

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
