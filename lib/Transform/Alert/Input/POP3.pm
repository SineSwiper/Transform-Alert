package Transform::Alert::Input::POP3;

# VERSION
# ABSTRACT: Transform alerts from POP3 messages

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(Str Int ArrayRef HashRef InstanceOf Maybe);

use Net::POP3;
use Email::MIME;
use List::AllUtils 'first';

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
   isa       => Maybe[InstanceOf['Net::POP3']],
   lazy      => 1,
   default   => sub {
      my $self = shift;
      Net::POP3->new( %{$self->connopts} ) || do {
         $self->log->error('POP3 New failed: '.$@);
         return;
      };
   },
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

   # Net::POP3 is a bit picky about its case-sensitivity
   foreach my $keyword (qw{ Host ResvPort Timeout Debug }) {
      $hash->{connopts}{$keyword} = delete $hash->{connopts}{lc $keyword} if (exists $hash->{connopts}{lc $keyword});
   }

   $orig->($self, $hash);
};

sub open {
   my $self = shift;
   my $pop  = $self->_conn ||
      # maybe+default+error still creates an undef attr, which would pass an 'exists' check on predicate
      do { $self->_clear_conn; return; };

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
   $msg =~ s/\r//g;
   my $pmsg = Email::MIME->new($msg);
   my $body = eval { $pmsg->body_str } || do {
      my $part = first { $_ && $_->content_type =~ /^text\/plain/ } $pmsg->parts;
      $part ? $part->body_str : $pmsg->body_raw;
   };
   $body =~ s/\r//g;
   my $hash = {
      $pmsg->header_obj->header_pairs,
      BODY => $body,
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

__END__

=begin wikidoc

= SYNOPSIS

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

= DESCRIPTION

This input type will read a POP3 mailbox and process each message through the input template engine.  If it finds a match, the results of the
match are sent to one or more outputs, depending on the group configuration.

See [Net::POP3] for a list of the ConnOpts section parameters.  The {Username} and {Password} options are included in this set, but not used
in the POP3 object's construction.

= OUTPUTS

== Text

Full text of the raw message, including headers.  All CRs are stripped.

== Preparsed Hash

   {
      # Header pairs, as per Email::Simple::Header
      Email::Simple->new($msg)->header_obj->header_pairs,

      # decoded via Email::MIME->new($msg)
      # $pmsg->body_str, or body_str of the first text/plain part (if it croaks), or $pmsg->body_raw
      # (all \r are stripped)
      BODY => $str,
   }

= CAVEATS

Special care should be made when using input templates on raw email messages.  For one, header order may change, which is difficult to
manage with REs.  For another, the message is probably MIME-encoded and would contain 80-character splits.  Use of Mungers here is *highly*
recommended.

All messages are deleted from the system, whether it was matched or not.  If you need to save your messages, you should consider using
[IMAP|Transform::Alert::Input::IMAP].

The raw message isn't kept for the Munger.  If you really need it, you can implement an input RE template of {(?<RAWMSG>[\s\S]+)}, and parse
out the email message yourself.

=end wikidoc
