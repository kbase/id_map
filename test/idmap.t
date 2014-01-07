use Test::More;
use Config::Simple;

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
    $cfg->param('id_map.service-port', '7777');
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


isa_ok ($obj = Bio::KBase::IdMap::Client->new($url), Bio::KBase::IdMap::Client);


done_testing;
