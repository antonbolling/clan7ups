#08/24/03 - JM - Added cook_string2 which removes ' marks from a string

use warnings;
use strict;

# Get the first integer from input.
sub cook_int {
  my ($input) = @_;

  my $int;

	if (!defined $input) {
		$int = undef;
	} elsif ($input =~ /(-?\d+)/) {
    $int = $1;
  }
  else {
    $int = undef;
  }

#  print STDERR "Cookint returning $int\n";
  return $int;
}

# Get the whole string and prepare it to be safe within single quotes in a select.
# - escape qutoes
# - anything else?
sub cook_string {
  my $input = shift;

  $input =~ s/\'/\\\'/g;

  return $input;
}

sub cook_string2 {
  my $input = shift;
  
  $input =~ s/\'//g;
  
  return $input;
}

# Get the first word, escape quotes
sub cook_word {
  my $input = shift;

  my ($first) = split /\s+/, $input;
  $first =~ s/\'/\\\'/g;

  return $first;
}

1;
