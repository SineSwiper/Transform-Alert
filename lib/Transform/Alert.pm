package Transform::Alert;

our $VERSION = '0.90'; # VERSION
# ABSTRACT: Transform alerts from one type to another type

use sanity;
use Moo;
use MooX::Types::MooseLike::Base 0.15 qw(Str HashRef ScalarRef ArrayRef InstanceOf ConsumerOf);

with 'MooX::Singleton';

use Time::HiRes 'time';
use List::AllUtils 'min';
use File::Slurp 'read_file';
use Storable 'dclone';

### FIXME: Need logging prefixes ###

has config => (
   is       => 'ro',
   isa      => HashRef,
   required => 1,
);
has log => (
   is       => 'ro',
   isa      => InstanceOf['Log::Log4perl'],
   required => 1,
);

# added in via config and BUILDARGS
has basedir => (
   is       => 'ro',
   isa      => Str,
   default  => sub { '' },
);
has inputs => (
   is       => 'ro',
   isa      => HashRef[InstanceOf['Transform::Alert::InputGrp']],
   required => 1,
);
has outputs => (
   is       => 'ro',
   isa      => HashRef[ConsumerOf['Transform::Alert::Output']],
   required => 1,
);

around BUILDARGS => sub {
   my ($orig, $self) = (shift, shift);
   my $hash = shift;
   $hash = { $hash, @_ } unless ref $hash;

   my $conf    = $hash->{config};
   my $basedir = $hash->{basedir} = $conf->{basedir};
   
   chdir $basedir;  # just go there to make relative pathing easier

   # process outputs first (needed for Template sets)
   $hash->{outputs} = {};
   foreach my $out_key (keys %{ $conf->{output} }) {
      my $out_conf  = dclone $conf->{output}{$out_key};
      
      # create the new class
      my $type = delete $out_conf->{type} || die "Output '$out_key' requires a Type!";
      $hash->{outputs}{$out_key} = "Transform::Alert::Output::$type"->new($out_conf);
   }
   
   # now process inputs
   $hash->{inputs} = {};
   foreach my $in_key (keys %{ $conf->{input} }) {
      my $in_conf  = dclone $conf->{input}{$in_key};
      
      $in_conf->{name}        = $in_key;
      $in_conf->{output_objs} = $hash->{outputs};
      
      # create the input group
      $hash->{inputs}{$in_key} = Transform::Alert::InputGrp->new($in_conf);
   }
   
   $orig->($self, $hash);
};

# Tie new $self to inputs/outputs
after BUILD => sub {
   my $self = shift;
   $_->_set_daemon($self) for (values %{ $self->inputs }, values %{ $self->outputs });
};

sub heartbeat {
   my $self = shift;
   my $log  = $self->log;
   
   $log->debug('START Heartbeat');
   foreach my $in_key (keys %{ $self->inputs }) {
      $log->debug('Looking at Input "'.$in_key.'"...');
      my $in = $self->inputs->{$in_key};
   
      # are we ready for another run?
      if (time > $in->last_finished + $in->interval) {
         $in->process;
      }
   }
   $log->debug('END Heartbeat');
   
   # shut up until I'm ready...
   return min map { time - $_->last_finished + $_->interval } values %{ $self->inputs };
}

sub close_all {
   my $self = shift;
   my $log  = $self->log;
   $log->debug('Closing all I/O for ALL groups');

   $_->close_all for (values %{ $self->inputs });
   
   return 1;
}

42;



=pod

=encoding utf-8

=head1 NAME

Transform::Alert - Transform alerts from one type to another type

=head1 SYNOPSIS

    # In your configuration
    BaseDir /opt/trans_alert
 
    <Input test_in>
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
 
       <Template>
          TemplateFile  test_in/foo_sys_email.txt
          OutputName    test_out
       </Template>
       <Template>
          TemplateFile  test_in/server01_email.txt
          OutputName    test_out
       </Template>         
    </Input>
    <Output test_out>
       Type          Syslog
       TemplateFile  outputs/test.txt
 
       # See Net::Syslog->new
       <ConnOpts>
          Name       TransformAlert
          Facility   local4
          Priority   info
          SyslogHost syslog.foobar.org
          SyslogPort 514  # default
       </ConnOpts>
    </Output>

=head1 DESCRIPTION

Insert description here...

=head1 CAVEATS

Bad stuff...

=head1 SEE ALSO

Other modules...

=head1 ACKNOWLEDGEMENTS

Thanks and stuff...

=head1 AVAILABILITY

The project homepage is L<https://github.com/SineSwiper/Transform-Alert/wiki>.

The latest version of this module is available from the Comprehensive Perl
Archive Network (CPAN). Visit L<http://www.perl.com/CPAN/> to find a CPAN
site near you, or see L<https://metacpan.org/module/Transform::Alert/>.

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Internet Relay Chat

You can get live help by using IRC ( Internet Relay Chat ). If you don't know what IRC is,
please read this excellent guide: L<http://en.wikipedia.org/wiki/Internet_Relay_Chat>. Please
be courteous and patient when talking to us, as we might be busy or sleeping! You can join
those networks/channels and get help:

=over 4

=item *

irc.perl.org

You can connect to the server at 'irc.perl.org' and join this channel: #distzilla then talk to this person for help: SineSwiper.

=back

=head2 Bugs / Feature Requests

Please report any bugs or feature requests via L<L<https://github.com/SineSwiper/Transform-Alert/issues>|GitHub>.

=head1 AUTHOR

Brendan Byrd <BBYRD@CPAN.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2012 by Brendan Byrd.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut


__END__

