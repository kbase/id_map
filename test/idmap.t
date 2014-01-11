use Test::More;
use Config::Simple;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);

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

$genomes = $obj->lookup_genome("Burkholderia");



done_testing;
