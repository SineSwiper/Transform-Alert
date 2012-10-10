
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Transform alerts from one type to another type",
  "AUTHOR" => "Brendan Byrd <BBYRD\@CPAN.org>",
  "BUILD_REQUIRES" => {
    "Devel::SimpleTrace" => "0.07",
    "Net::Syslog" => "0.04",
    "Test::CheckDeps" => "0.002",
    "Test::LeakTrace" => "0.01",
    "Test::Most" => "0.01",
    "Test::UseAllModules" => "0.10"
  },
  "CONFIGURE_REQUIRES" => {},
  "DISTNAME" => "Transform-Alert",
  "EXE_FILES" => [
    "bin/transalert_ctl"
  ],
  "LICENSE" => "artistic_2",
  "NAME" => "Transform::Alert",
  "PREREQ_PM" => {
    "App::Daemon" => "0.01",
    "Class::Load" => "0.01",
    "Config::General" => "2.38",
    "Data::Dump" => "1.10",
    "Email::Abstract" => "3.000",
    "Email::Sender::Simple" => "0.000",
    "Email::Simple" => "2.004",
    "File::Slurp" => "9999.14",
    "List::AllUtils" => "0.01",
    "Log::Log4perl" => "1.15",
    "Mail::IMAPClient" => "3.03",
    "Module::Metadata" => "1.000000",
    "Moo" => "0.009001",
    "MooX::Types::MooseLike" => "0.15",
    "Net::SNMP" => "v6.0.0",
    "Net::SNMPTrapd" => "0.01",
    "Net::Syslog" => "0.04",
    "Net::Syslogd" => "0.01",
    "Path::Class" => "0.17",
    "String::Escape" => "2010.002",
    "Template" => "2.20",
    "namespace::clean" => "0.06",
    "sanity" => "0.91"
  },
  "VERSION" => "0.90",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



