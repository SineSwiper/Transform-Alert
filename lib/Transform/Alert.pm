package Transform::Alert;

# VERSION
# ABSTRACT: Transform alerts from one type to another type

use sanity 0.94;
use Moo 1.000000;
use MooX::Types::MooseLike 0.15;  # ::Base got no $VERSION
use MooX::Types::MooseLike::Base qw(Str HashRef ScalarRef ArrayRef InstanceOf ConsumerOf);

#with 'MooX::Singleton';

use Transform::Alert::InputGrp;

use Time::HiRes    'time';
use List::AllUtils 'min';
use File::Slurp    'read_file';
use Storable       'dclone';
use Class::Load    0.17 ('load_class');  # 0.17 = wheezy's version

use namespace::clean;

has config => (
   is       => 'ro',
   isa      => HashRef,
   required => 1,
);
has log => (
   is       => 'ro',
   isa      => InstanceOf['Log::Log4perl::Logger'],
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

# Punk to funk (recursively)
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
      my $class = "Transform::Alert::Output::$type";
      load_class $class;
      $hash->{outputs}{$out_key} = $class->new($out_conf);
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
sub BUILD {
   my $self = shift;
   $_->_set_daemon($self) for (values %{ $self->inputs }, values %{ $self->outputs });
};

sub heartbeat {
   my $self = shift;
   my $log  = $self->log;

   $log->debug('START Heartbeat');
   foreach my $in_key (sort {
      # sorting these by time_left, so that (hopefully) as much as possible is processed in one heartbeat
      $self->inputs->{$a}->time_left <=> $self->inputs->{$b}->time_left
   } keys %{ $self->inputs }) {
      $log->debug('Looking at Input "'.$in_key.'"...');
      my $in = $self->inputs->{$in_key};

      # are we ready for another run?
      if (time > $in->last_finished + $in->interval) {
         $in->process;
      }
   }
   $log->debug('END Heartbeat');

   # shut up until I'm ready...
   return min map { $_->time_left } values %{ $self->inputs };
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

=encoding utf-8

=begin wikidoc

= SYNOPSIS

   # In your configuration
   BaseDir /opt/transalert

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
         TemplateFile  test_in/foo_sys_email.re
         OutputName    test_out
      </Template>
      <Template>
         TemplateFile  test_in/server01_email.re
         Munger        test_in/Munger.pm MyMunger->munge
         OutputName    test_out
      </Template>
   </Input>
   <Output test_out>
      Type          Syslog
      TemplateFile  outputs/test.tt

      # See Net::Syslog->new
      <ConnOpts>
         Name       TransformAlert
         Facility   local4
         Priority   info
         SyslogHost syslog.foobar.org
         SyslogPort 514  # default
      </ConnOpts>
   </Output>

   # On a prompt
   > transalert_ctl -c file.conf -l file.log -p file.pid

= DESCRIPTION

Ever have a need to transform one kind of alert/message into another?  For example:

* Taking a bunch of alert emails and converting them into Syslogs
* Converting Syslog alerts to SNMP traps
* Converting SNMP traps to Syslogs
* Traps to email
* Anything to anything

Then this platform delivers.

Transform::Alert is a highly extensible platform to transform alerts from anything to anything else.  Everything is ran through a configuration
file, a couple of templates, and [Transform::Alert's daemon app|transalert_ctl].

Or to show it with a UTF8 drawing, the platform works like this:

   Input ──┬── InTemplate ────────────── Output + OutTemplate
           ├── InTemplate + Munger ──┬── Output + OutTemplate
           │                         └── Output + OutTemplate
           ├── InTemplate + Munger ──┬── Output + OutTemplate
           └── InTemplate ───────────┘
   Input ──┬── InTemplate ────────────── Output + OutTemplate
           └── InTemplate + Munger ───── Output + OutTemplate

All [inputs|Transform::Alert::Input] and [outputs|Transform::Alert::Output] are separate modules, so if there isn't a protocol available, they
are easy to make.  Input templates use a multi-line regular expression with named captures to categorize the variables.  Output templates are
[TT|Template::Toolkit] templates with a {[% var %]} syntax.  If you need to transform the data after it's been captured, you can use a "munger"
module to play with the variables any way you see fit.

= DETAILS

== Configuration Format

The configuration uses an Apache-based format (via [Config::General]).  There's a number of elements required within the config file:

=== BaseDir

   BaseDir [dir]

The base directory is used as a starting point for the daemon and any of the relative paths in the config file.  The {BaseDir} option itself
can use a relative path, in which case will start at the config path.

=== Input

   <Input [name]>  # one or more
      Type      [type]
      Interval  [seconds]  # optional; default is 60s

      # <ConnOpts> section; module-specific
      # <Template> sections
   </Input>

The {Input} section specifies a single input source.  All {Input} sections must be named.  Multiple {Input} sections can be specified, but the
name must be unique.  (Currently, the input name isn't used, but this may change in the future.)

The {Type} specifies the type of input used.  This maps to a {Transform::Alert::Input::*} class.  More information about the different modules
be found with the corresponding documentation.

The {Interval} specifies how frequently the input should be checked (in seconds).  Server-based input shouldn't be checked too often, as it
might be considered abusive.  To prevent overruns, the input will only be re-checked after the interval is complete.  (In other words, the
"last finished" time is recorded, not the "last start".)

There is one {ConnOpts} section in each input.  The options will be specific to each type, so look there for documentation.

The engine may someday be changed to have multi-processed inputs, but the need isn't immediate right now.  (Patches welcome.)

=== Template

   <Input ...>
      <Template>  # one or more
         # Template/File can be optional
         TemplateFile  [file]      # not used with Template
         Template      "[String]"  # not used with TemplateFile

         Munger        [file] [class]->[method]  # optional
         OutputName    test_out    # one or more
      </Template>
   </Input>

All {Input} sections must have one or more {Template} sections.  As messages are being processed, each message is tested on all of the
templates.  Input messages will be ran through *all* templates tied to that input, even if that message matched a previous template.  To prevent
a message from matching multiple templates, make sure they are reasonably unique.

All templates must either have a {TemplateFile} or {Template} option.  In most cases, you should stick with file-based templates, as inline
templates are whitespace sensitive, and should only be used for single line REs.

If you don't set a Template option, a template file is not used.  Without a Munger to validate the hash, these templates will be accepted (and
sent to the outputs), as long as it passes data.

The optional {Munger} option can be used to specify a module used in changing the variables between the input and output.  (More details about
[Mungers further down|/Mungers].)  The option itself can be expressed in a number of ways:

   Munger  File.pm
   Munger  File.pm->method
   Munger  File.pm My::Munger
   Munger  My::Munger
   Munger  My::Munger->method
   Munger  File.pm My::Munger->method  # preferred

If a class isn't specified, the first package name found in the file is used.  If the method is missing, the default is {munge}.  If there
isn't a file specified, it will try to load the class like {use/require}.  (Technically, you could take advantage of the {.} path in {%INC},
but it's better to just provide the filename.)

If both {Template/File} & {Munger} options are passed, it will test both forms as an AND-based match, testing the text form via template
first.  This has the benefit of using the input templates as a "gatekeeper", and can be used to delegate different templates to different
Mungers.  Any named captures from the input template will be passed as a {t} hash in the variables to the Munger.

The {OutputName} options provide the name of the Output sources to use after a template match is found.  (These sources are defined below.)
More that one option means that the alert will be sent to multiple sources.

=== Output

   <Output [name]>  # one or more
      Type          [type]
      TemplateFile  [file]      # not used with Template
      Template      "[String]"  # not used with TemplateFile

      # <ConnOpts> section; module-specific
   </Output>

Like {Input}, {Output} sections need to be uniquely named.  This name is used with the {OutputName} option above.  Also like {Input}, the
{Type} functions the same way (mapping to a {Transform::Alert::Output::*} class), and {ConnOpts} contains all of the module-specific options.

Similar to {Template} sections, the {Output} section must either have a {TemplateFile} or a {Template} option.  However, you can only use a
single template per {Output}.  If you need more, use another section with most of the same options.

== Directory Structure

Depending on how large your setup is, you may want to create a directory structure like this:

   /opt/transalert          # config, log, PID
   /opt/transalert/input1   # various input template directories
   /opt/transalert/input2
   /opt/transalert/input3
   /opt/transalert/outputs  # single directory for output templates

If your set up is small, you can get away with a single directory, or at least single input/output directories.  Just be sure to use the log/PID
options in [transalert_ctl], so that they are put in the right directory.

== Input Templates

Input templates are basically big multi-line regular expressions.  These are NOT {/x} whitespace-insensitive regular expressions, as those
would make copy/pasting large bodies of text more difficult.  (There's an assumption that most input templates will have more static text than
freeform RE parts.)  Besides, you can still use a {(?x...)} construct for whitespace-insensitivity and comments.  Also, leading and trailing
whitespace is removed, so stray whitespace should not be an issue there.  RE templates are also put into a {^$re$}, with begin/end symbols,
which can easily be overriden with {.*}.

Please note that a matched template doesn't stop the matching process, so make sure the templates are unique enough if you don't want to
match multiple templates.

Here's an example using an email template:

   [\s\S]*\QTo: <alert@foobar.org>
   From: <alert@foobar.org>
   Subject: Email Alert - \E(?<subject>[^\n]+)
   Date: (?<date>[^\n]+)
   [\s\S]+

   We found a problem on this device:

   \QName    :\E (?<name>\w+)
   \QProblem :\E (?<problem>[^\n]+)
   \QTicket #:\E (?<ticket>\w+)
   .*

Of course, this is taking some assumptions about the order and format of headers, but if this is coming from an automated platform that uses
the same mail server, there really shouldn't be much change at all.  If you need finer control of the verification process, you can make use
of [Mungers|/Mungers].

== Output Templates

Output templates use [Template::Toolkit].  If you want a quick and dirty lesson on how they work, check out [Template::Manual::Syntax].  If
*that* is too wordy for you, then just remember that variables are replaced with a {[% t.var %]} syntax.

The variables passed to the Output (or Munger, if specified) will look like this:

   {
      t => {
         # text form variables acquired from the input RE template
      },
      p => {
         # preparsed hash variables, sent by the Input module
      }
   }

For a structure of the {p} hash passed, look at the documentation for that input module (under {Preparsed Hash}).  Note that Munger mangling
could totally change the structure of the hash passed to the Outputs, depending on what it returns.

Here's an example output template that looks similar to the input one above:

   To: [% t.to %]
   From: [% t.from %]
   Subject: Email Alert - [% t.subject %]
   Date: [% t.date %]

   We found a problem on this device:

   Name    : [% t.name %]
   Problem : [% t.problem %]
   Ticket #: [% t.ticket %]

== Mungers

Mungers are an optional second piece to the input template structure.  Regular expressions, as powerful as they are with finding and capturing
information, only do just that.  Sometimes you need to warp the information you've captured to fit the mold that the output can use.  Or
sometimes you need to validate the input in a better fashion than REs can provide.  Mungers fit both of those roles.

Mungers are basically freeform Perl modules that transform and/or validate the input data passed to it.  Here's an example munger, straight
from the test platform:

   package TestMunger;

   sub munge {
      my ($class, $vars, $tmpl_grp) = @_;

      $vars->{t}{thingy} = delete $vars->{t}{item};

      return int rand(2) ? $vars : undef;
   }

   1;

This munger does two (useless) things: change the name of the {item} variable to {thingy}, and randomly reject the input.  But, this munger
could just as easily do anything Perl can do to transform and validate the data.

All mungers are called by their class (ie: {TestMunger->munge}), so all of them should have a package name.  They should also return either
{undef} (as a rejection) or the variable list (as a hashref).  If the input ends up with multiple alerts, a munger can also pass an arrayref
(of hashrefs), and they will be sent to the outputs individually.

A munger could also become the *primary* piece for input transformation/validation by not specifying a Template option.

Mungers are also passed the [TemplateGrp|Transform::Alert::TemplateGrp] object.  This is mostly used as a way to hook into the log, like:

   $tmpl_grp->log->debug("Munger didn't like Message Body");

== Variable Passing

If you're still confused on the variable passing, look at it this way:

   Input ──┬── $text ───── InTemplate ───── t => { %+ } ──┬── Munger ───── { ??? } ───── Out...
           └── $hash ────────────────────── p => $hash  ──┘

   Input ──┬── $text ────────────────────── t => {    } ──┬── Munger ───── { ??? } ───── Out...
           └── $hash ────────────────────── p => $hash  ──┘

   Input ──┬── $text ───── InTemplate ───── t => { %+ } ──┬───────────────────────────── Out...
           └── $hash ────────────────────── p => $hash  ──┘

   Input ──┬── $text ────────────────────── t => {    } ──┬── Munger ───── [ { ??? }, ── Out...
           └── $hash ────────────────────── p => $hash  ──┘                  { ??? }, ── Out...
                                                                             { ??? } ] ─ Out...

   ...OutTemplate ───── $str ───── Output

= CAVEATS

* This doesn't work on Windows.  Blame [Proc::ProcessTable].  Or rather, [this bug|https://rt.cpan.org/Ticket/Display.html?id=75931].

* One would consider this a grand feat of over-engineering, which doesn't apply to every single protocol cleanly.  For example,
email input templates alone probably shouldn't be used, as header order might change, and the SNMP I/O doesn't translate to text
very well.  YMMV.

= TODO

* Moar I/O:

   Inputs            Outputs
   ------            -------
   HTTP::Atom
   HTTP::RSS
   File::CSV         File::CSV
   File::Text        File::Text
                     IRC

* [Pegex] support for input templates, maybe when we stop playing with the syntax :)
* Multi-threaded and/or -processed inputs/outputs

=end wikidoc
