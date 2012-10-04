package Transform::Alert;

# VERSION
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

__END__

=begin wikidoc

= SYNOPSIS
 
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
 
= DESCRIPTION
 
Insert description here...

= CAVEATS

Bad stuff...

= SEE ALSO

Other modules...

= ACKNOWLEDGEMENTS

Thanks and stuff...

=end wikidoc
