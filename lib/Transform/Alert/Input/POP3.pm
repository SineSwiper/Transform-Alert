package Transform::Alert::Input::POP3;

our $VERSION = '0.90_002'; # VERSION
# ABSTRACT: Transform alerts from POP3 messages

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(Str Int ArrayRef HashRef InstanceOf);

use Net::POP3;
use Email::Simple;

with 'Transform::Alert::Input';

# Stolen from connopts
has username => (
   is       => 'ro',
   isa      => Str,
   required => 1,
);
has password => (
   is       => 'ro',
   isa      => Str,
   required => 1,
);

has _conn => (
   is        => 'rw',
   isa       => InstanceOf['Net::POP3'],
   predicate => 1,
   clearer   => 1,
);
has _list => (
   is        => 'rw',
   isa       => ArrayRef[Int],
   predicate => 1,
   clearer   => 1,
);

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   $hash->{username} = delete $hash->{connopts}{username};
   $hash->{password} = delete $hash->{connopts}{password};
   
   $orig->($self, $hash);
};

sub open {
   my $self = shift;
   my $pop  = $self->_conn(
      Net::POP3->new( %{$self->connopts} )
   );
   
   unless ( $pop->login($self->username, $self->password) ) {
      $self->log->error('POP3 Login failed: '.$pop->message);
      return;
   }
   
   my $msgnums = $pop->list;
   $self->_list([
      sort { $a <=> $b } keys %$msgnums
   ]);
   
   return 1;
}

sub opened {
   my $self = shift;
   return $self->_has_conn && $self->_conn->opened;
}

sub get {
   my $self = shift;
   my $num = shift @{$self->_list};
   my $pop = $self->_conn;
   
   my $amsg = $pop->get($num);
   unless ($amsg) {
      $self->log->error('Error grabbing POP3 message #'.$num.': '.$pop->message);
      return;
   }
   $pop->delete($num);
   
   my $msg = join '', @$amsg;
   my $pmsg = Email::Simple->new($msg);
   my $hash = {
      $pmsg->header_obj->header_pairs,
      BODY => $pmsg->body,
   };
   
   return (\$msg, $hash);
}

sub eof {
   my $self = shift;
   return not ($self->_has_list and @{$self->_list});
}

sub close {
   my $self = shift;
   my $pop  = $self->_conn;

   $pop->quit if $self->opened;
   $self->_clear_list;
   $self->_clear_conn;
   return 1;
}

42;



=pod

=encoding utf-8

=head1 NAME

Transform::Alert::Input::POP3 - Transform alerts from POP3 messages

=head1 SYNOPSIS

    # In your configuration
    <Input test>
       Type      POP3
       Interval  60  # seconds (default)
 
       <ConnOpts>
          Username  bob
          Password  mail4fun
 
          # See Net::POP3->new
          Host     mail.foobar.org
          Port     110  # default
          Timeout  120  # default
       </ConnOpts>
       # <Template> tags...
    </Input>

=head1 DESCRIPTION

This input type will read a POP3 mailbox and process each message through the 
input template engine.  If it finds a match, the results of the match are sent
to one or more outputs, depending on the group configuration.

See L<Net::POP3> for a list of the ConnOpts section parameters.  The C<<< Username >>>
and C<<< Password >>> options are included in this set, but not used in the POP3
object's construction.

=head1 OUTPUTS

=head2 Text

Full text of the message, including headers.

=head2 Preparsed Hash

    {
       # Header pairs, as per Email::Simple::Header
       Email::Simple->new($msg)->header_obj->header_pairs,
 
       BODY => $str,
    }

=head1 CAVEATS

All messages are deleted from the system, whether it was matched or not.

=head1 AVAILABILITY

The project homepage is L<https://github.com/SineSwiper/Transform-Alert/wiki>.

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<https://metacpan.org/module/Transform::Alert/>.

=head1 AUTHOR

Brendan Byrd <BBYRD@CPAN.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Brendan Byrd.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut


__END__

