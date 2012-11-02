package TestMunger;

sub munge {
   my ($class, $vars) = @_;
   
   my $newvars = {};
   $newvars->{thingy} = $vars->{t}{item} || $vars->{p}{item};
   
   return int rand(2) ? $newvars : undef;
}

1;
