
use Test::More;
use Config::Simple;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
use Data::Dumper;

our $cfg = {};
our ($obj, $h);

if (defined $ENV{KB_DEPLOYMENT_CONFIG} && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
    $cfg = new Config::Simple($ENV{KB_DEPLOYMENT_CONFIG}) or
	die "can not create Config object";
    print "using $ENV{KB_DEPLOYMENT_CONFIG} for configs\n";
}
else {
    $cfg = new Config::Simple(syntax=>'ini');
    $cfg->param('id_map.service-host', '127.0.0.1');
    $cfg->param('id_map.service-port', '7111');
}


my $url = "http://" . $cfg->param('id_map.service-host') . 
	  ":" . $cfg->param('id_map.service-port');


BEGIN {
	use_ok( Bio::KBase::IdMap::Client );
}


can_ok("Bio::KBase::IdMap::Client", qw(
	new
	lookup_genome
	lookup_features
	lookup_feature_synonyms

	 )
);

INFO "using $url";

isa_ok ($obj = Bio::KBase::IdMap::Client->new($url), Bio::KBase::IdMap::Client);

ok(@{$genomes = $obj->lookup_genome("Burkholderia","NAME" )} > 0,
	"lookup_genome returned genomes");

print Dumper $genomes;

$ids = tax_id_list();
ok(@{$genomes = $obj->lookup_genome(180504, "NCBI_TAXID")} == 1,
	"lookup_genome returned one genome");

print Dumper $genomes;

# funcdef lookup_features(string kb_genome_id, list<string> aliases, string feature_type, string source_db)

ok(ref($obj->lookup_features("",[],"","")) eq 'HASH', "lookup_features returns a hash reference");
ok(ref($obj->lookup_feature_synonyms("","")) eq 'ARRAY', "lookup_feature_synonyms returns an array reference");

# | kb|g.3899.locus.9953  | kb|g.3899.mRNA.12242 | kb|g.3899.CDS.21726 |             369 |
# | kb|g.3899.locus.9953  | kb|g.3899.mRNA.12379 | kb|g.3899.CDS.21494 |             348 |
# | kb|g.3899.locus.9953  | kb|g.3899.mRNA.12551 | kb|g.3899.CDS.21269 |             372 |
#
# | kb|g.3899.locus.997   | kb|g.3899.mRNA.1209  | kb|g.3899.CDS.27325 |             858 |
# | kb|g.3899.locus.997   | kb|g.3899.mRNA.1404  | kb|g.3899.CDS.27644 |            1104 |
#
# | kb|g.3899.locus.98    | kb|g.3899.mRNA.11    | kb|g.3899.CDS.26180 |            1893 |
# | kb|g.3899.locus.98    | kb|g.3899.mRNA.163   | kb|g.3899.CDS.25774 |            1386 |
# | kb|g.3899.locus.98    | kb|g.3899.mRNA.367   | kb|g.3899.CDS.26136 |            1878 |
#
# | kb|g.3899.locus.974   | kb|g.3899.mRNA.1662  | kb|g.3899.CDS.27123 |             582 |

my $ids = ['kb|g.3899.locus.9953','kb|g.3899.locus.997','kb|g.3899.locus.98','kb|g.3899.locus.974'];
ok(ref($longest = $obj->longest_cds_from_locus($ids)) eq "HASH", "longest_cds_from_locus returns a hash reference");
print Dumper $longest;

$ids = ['kb|g.3899.mRNA.1662','kb|g.3899.mRNA.11','kb|g.3899.mRNA.163','kb|g.3899.mRNA.367','kb|g.3899.mRNA.12379','kb|g.3899.mRNA.12242','kb|g.3899.mRNA.12551','kb|g.3899.mRNA.1404','kb|g.3899.mRNA.1209'];
ok(ref($longest = $obj->longest_cds_from_mrna($ids)) eq "HASH", "longest_cds_from_rna returns a hash reference");
print Dumper $longest;

$ids = [ 'kb|g.3899.mRNA.24549' ];
ok(ref($longest = $obj->longest_cds_from_mrna($ids)) eq "HASH", "longest_cds_from_rna returns a hash reference");
print Dumper $longest;

done_testing;






# Data for testing

sub tax_id_list {
	my @ids = (
292,
337, 
180504, 
209052,
216591,
242527,
242861,
243160,
243261,
244310,
255131,
260373,
264729,
266265,
269482,
269483,
271848,
272560,
279280,
279530,
320371,
320372,
320373,
320374,
320388,
320389,
320390,
331109,
331271,
331272,
331978,
332032,
334802,
334803,
339670,
348137,
350701,
350702,
357347,
357348,
360118,
370895,
391038,
395019,
396596,
396597,
396598,
398527,
398577,
406425,
412021,
417280,
425067,
431891,
431892,
431893,
431894,
436115,
441152,
441153,
441154,
441155,
441156,
441157,
441158,
441159,
441160,
441161,
441162,
441163,
441164,
441165,
441166,
469610,
513051,
513052,
513053,
516466,
536230,
557724,
595498,
626418,
640510,
640511,
640512,
882378,
884204,
999541);

	return \@ids;
}
