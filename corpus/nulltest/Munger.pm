package TestMunger;

sub munge {
   my ($class, $vars) = @_;
   
   $vars->{thingy} = delete $vars->{item};
   
   return int rand(2) ? $vars : undef;
}

1;
