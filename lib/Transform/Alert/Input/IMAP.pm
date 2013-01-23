package Transform::Alert::Input::IMAP;

# VERSION
# ABSTRACT: Transform alerts from IMAP messages

use sanity;
use Moo;
use MooX::Types::MooseLike::Base qw(Str ArrayRef InstanceOf Maybe);

use Mail::IMAPClient;
use Email::MIME;
use List::AllUtils 'first';

with 'Transform::Alert::Input';

# Stolen from connopts
has parsed_folder => (
   is        => 'ro',
   isa       => Str,
   predicate => 1,
);

has _conn => (
   is        => 'rw',
   isa       => Maybe[InstanceOf['Mail::IMAPClient']],
   lazy      => 1,
   default   => sub {
      my $self = shift;
      Mail::IMAPClient->new( %{$self->connopts} ) || do {
         $self->log->error('IMAP New/Connect/Login failed: '.$@);
         return;
      };
   },
   predicate => 1,
   clearer   => 1,
);
has _list => (
   is        => 'rw',
   isa       => ArrayRef[Str],
   predicate => 1,
   clearer   => 1,
);

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   $hash->{parsed_folder} = delete $hash->{connopts}{parsedfolder} if exists $hash->{connopts}{parsedfolder};

   $orig->($self, $hash);
};

sub open {
   my $self = shift;
   my $imap = $self->_conn ||
      # maybe+default+error still creates an undef attr, which would pass an 'exists' check on predicate
      do { $self->_clear_conn; return; };

   # figure out which state it's in
   unless ($imap->IsSelected) {
      if    (not $imap->IsConnected) {
         $imap->connect || do { $self->log->error('IMAP Connect/Login failed: '.$imap->LastError); return; };
      }
      elsif (not $imap->IsAuthenticated) {
         $imap->login   || do { $self->log->error('IMAP Login failed: '        .$imap->LastError); return; };
      }

      # might not have a folder set
      unless ($imap->IsSelected) {
         $imap->select('Inbox') || do { $self->log->error('IMAP Select failed: '.$imap->LastError); return; };
      }
   }

   my $msgs = ($self->has_parsed_folder ? $imap->messages : $imap->unseen) || do {
      $self->log->error('IMAP Messages failed: '.$imap->LastError);
      return;
   };
   $self->_list($msgs);

   return 1;
}

sub opened {
   my $self = shift;
   $self->_has_conn and $self->_conn->IsSelected;
}

sub get {
   my $self = shift;
   my $uid  = shift @{$self->_list};
   my $imap = $self->_conn;

   my $msg = $imap->message_string($uid) || do { $self->log->error('Error grabbing IMAP message '.$uid.': '.$imap->LastError); return; };
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

   # Move message
   if ($self->has_parsed_folder) {
      $imap->move( $self->parsed_folder, $uid ) || do { $self->log->error('Error moving IMAP message '.$uid.': '.$imap->LastError); return; };
   }
   # (if not, message_string will auto-set the Seen flag.)

   return (\$msg, $hash);
}

sub eof {
   my $self = shift;
   return not ($self->_has_list and @{$self->_list});
}

sub close {
   my $self = shift;
   my $imap = $self->_conn;

   $self->_clear_list;
   my $is_valid = $self->opened;

   # valid connection
   if ($is_valid) {
      $imap->close  || $self->log->warn('Error closing IMAP: '       .$imap->LastError);
   }
   # open or valid connection
   if ($imap->IsConnected) {
      $imap->logout || $self->log->warn('Error logging out of IMAP: '.$imap->LastError);
   }
   # invalid connection
   $self->_clear_conn unless ($is_valid);

   return 1;
}

42;

__END__

=begin wikidoc

= SYNOPSIS

   # In your configuration
   <Input test>
      Type      IMAP
      Interval  60  # seconds (default)

      <ConnOpts>
         ParsedFolder  Finished

         # See Mail::IMAPClient Parameters
         Server   mail.foobar.org
         User     bob
         Password mail4fun
         Folder   Inbox
         Uid      1
         # ...etc...
      </ConnOpts>
      # <Template> tags...
   </Input>

= DESCRIPTION

This input type will read a IMAP mailbox and process each message through the input template engine.  If it finds a match, the results of the
match are sent to one or more outputs, depending on the group configuration.

See [Mail::IMAPClient|Mail::IMAPClient#Parameters] for a list of the ConnOpts section parameters.

The {ParsedFolder} option is special.  If set, it will move all parsed messages to that folder.  If not, it will rely on the Unread flag to
figure out which messages have been parsed or not parsed.

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

You are responsible for setting up any archiving/deletion protocols for the mailbox, as this module will save everything (and potentially
fill up the box).

The raw message isn't kept for the Munger.  If you really need it, you can implement an input RE template of {(?<RAWMSG>[\s\S]+)}, and parse
out the email message yourself.

This class is persistent, keeping the [Mail::IMAPClient] object until shutdown.  However, it will still disconnect on close, and will clear
the object on error.

=end wikidoc
