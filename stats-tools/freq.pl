# count frequency on lines (from stdin)
# - call from pipe

# - if we run through words.pl first, then we can get the frequency of words

use strict;

# ---------- ---------- ---------- ----------

# open file, get all text
my @theFile = <STDIN>;

# do frequency breakdown
my %theFreq;

foreach my $theLine (@theFile) {
  chomp($theLine);
  $theFreq{$theLine}++;
}

# output frequency breakdown
print "{";
foreach my $theWord (sort keys %theFreq) {
  print("\"$theWord\":\"$theFreq{$theWord}\",");
}
print "\"\":0}";