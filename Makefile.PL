
use strict;
use warnings;

use 5.010001;

use ExtUtils::MakeMaker 6.30;



my %WriteMakefileArgs = (
  "ABSTRACT" => "Transform alerts from one type to another type",
  "AUTHOR" => "Brendan Byrd <BBYRD\@CPAN.org>",
  "BUILD_REQUIRES" => {
    "Test::CheckDeps" => "0.002",
    "Test::UseAllModules" => "0.10"
  },
  "CONFIGURE_REQUIRES" => {},
  "DISTNAME" => "Transform-Alert",
  "EXE_FILES" => [
    "bin/transalert-ctl"
  ],
  "LICENSE" => "artistic_2",
  "NAME" => "Transform::Alert",
  "PREREQ_PM" => {
    "App::Daemon" => "0.01",
    "Config::General" => "2.38",
    "Data::Dump" => "1.10",
    "File::Slurp" => "9999.14",
    "List::AllUtils" => "0.01",
    "Log::Log4perl" => "1.15",
    "Moo" => "0.009001",
    "MooX::Singleton" => "1.121160",
    "MooX::Types::MooseLike::Base" => "0.15",
    "Net::Syslog" => "0.04",
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



