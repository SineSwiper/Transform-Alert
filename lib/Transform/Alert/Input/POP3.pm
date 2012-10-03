package Transform::Alert::Input::POP3;

# VERSION
# ABSTRACT: Transform alerts from POP3 messages

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str Int ArrayRef HashRef InstanceOf);

use Net::POP3;

with 'Transform::Alert::IO';

has options => (
   is       => 'ro',
   isa      => HashRef,
   required => 1,
);
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

sub open {
   my $self = shift;
   my $pop  = $self->_conn(
      Net::POP3->new( %{$self->options} )
   );
   
   unless ( $pop->login($self->username, $self->password) ) {
      $self->log('POP3 Login failed: '.$pop->message);
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
   
   unless (my $amsg = $pop->get($num)) {
      $self->log('Error grabbing POP3 message #'.$num.': '.$pop->message);
      return;
   }
   $pop->delete($num);
   
   my $msg = join '', @$amsg;   
   return \$msg;
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
      Username  bob
      Password  mail4fun
      
      # See Net::POP3->new
      <Options>
         Host     mail.foobar.org
         Port     110  # default
         Timeout  120  # default
      </Options>
      <Outputs>
         # ...
      </Outputs>
   </Input>
 
= DESCRIPTION
 
This input type will read a POP3 mailbox and process each message through the 
input template engine.  If it finds a match, the results of the match are sent
to one or more outputs, depending on the group configuration.

See [Net::POP3] for a list of the Options section parameters.

= CAVEATS

All messages are deleted from the system, whether it was matched or not.

=end wikidoc
