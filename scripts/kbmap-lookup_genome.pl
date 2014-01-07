use strict;
use Bio::KBase::IdMap::Client;
use Getopt::Long; 
use JSON;
use Pod::Usage;

my $man  = 0;
my $help = 0;
my ($in, $out);

GetOptions(
	'h'	=> \$help,
	'help'	=> \$help,
	'man'	=> \$man,
	'i=s'   => \$in,
	'o=s'   => \$out,
) or pod2usage(0);
pod2usage(-exitstatus => 0,
	  -output => \*STDOUT,
	  -verbose => 2,
	  -noperldoc => 1,
	 ) if $help or $man;

# do a little validation on the parameters


my ($ih, $oh);

if ($in) {
    open $ih, "<", $in or die "Cannot open input file $in: $!";
}
else {
    $ih = \*STDIN;
}
if ($out) {
    open $oh, ">", $out or die "Cannot open output file $out: $!";
}
else {
    $oh = \*STDOUT;
}


# main logic

my $obj = Bio::KBase::IdMap::Client->new();
while(<$ih>) {
  my $rv  = Bio::KBase::IdMap::Client->lookup_genome($_);
  foreach my $idpair (@$rv) {
    print $oh $idpair->{'source_db'}, "\t";
    print $oh $idpair->{'source_id'}, "\t";
    print $oh $idpair->{'kbase_id'}, "\n";
  }
}


sub serialize_handle {
	my $handle = shift or
		die "handle not passed to serialize_handle";
        my $json_text = to_json( $handle, { ascii => 1, pretty => 1 } );
	print $oh $json_text;
}	


sub deserialize_handle {
	my $ih = shift or
		die "in not passed to deserialize_handle";
	my ($json_text, $perl_scalar);
	$json_text .= $_ while ( <$ih> );
	$perl_scalar = from_json( $json_text, { utf8  => 1 } );
}

 

=pod

=head1	NAME

lookup_genome

=head1	SYNOPSIS

lookup_genome <params>

=head1	DESCRIPTION

The lookup_genome command calls the lookup_genome method of a Bio::KBase::IdMap::Client object.

=head1	COMMAND-LINE OPTIONS

=over

=item	-h, --help, --man  This documentation

=item   -i  Specifies input. If set, then input is read from the file
passed as the value to this option. If not set, then input is read
from STDIN. Input is a genome identifier.

=item   -o  Specifies output. If set, then output is written to the
file passed as the value to this option. If not set, then outupt is
written to STDOUT. Output is a tab delimited set of id mappings
(called IdPairs). Each IdPair has three fields, a source db, a source
id, and a kbase id.

=back

=head1	AUTHORS

Thomas Brettin

=cut

1;

