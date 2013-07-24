# split text file into individual words
# - call from pipe

use strict;

# ---------- ---------- ---------- ----------

# prepositions array

# open file, get all text
my @theFile = <STDIN>;
my $theFile = join("\n", @theFile);

# convert '' pairs into "
$theFile =~ s/\'\'/\"/g;

# remove punctuation, numbers, strange characters
$theFile =~ s/[\?\;\:\!\,\.\"\(\)\$\%\*\\\/\+\-\=\<\>\[\]\_\`\!\|\{\}0-9~��������]/ /g;

# remove page numbers
$theFile =~ s/-.*?-/ /g;

# optional: remove dash
$theFile =~ s/-/ /g;

# remove isolated ', `, &, -
$theFile =~ s/\s[\'\`\&\-]/ /g;
$theFile =~ s/[\'\`\&\-]\s/ /g;

$theFile = lc $theFile;

my @preps = ("a", "al", "ante", "antes", "asi", "aunque", "bajo", "bien", "cabe", "como", "con", "con", "contra", "cuando", "de", "del", "desde", "despues", "durante", "e", "el", "empero", "en", "entre", "esta", "hacia", "hasta", "la", "las", "los", "luego", "mas", "mediante", "muy", "ni", "o", "ora", "para", "pero", "por", "porque", "pues", "que", "se", "sea", "segun", "si", "sin", "sino", "siquiera", "sobre", "tal", "toda", "tras", "u", "un", "una", "uno", "unos", "y", "ya");
my %prepsHash = map { $_ => 1 } @preps;

# split back on whitespace
my @theWords = split(" ", $theFile);

foreach my $theWord (@theWords) {
  # optional: remove words with ^, & in them
  if ($theWord !~ /[\^\&]/ && !exists($prepsHash{lc $theWord})) {
    print("$theWord\n");
  }
}

