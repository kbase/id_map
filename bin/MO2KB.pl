use strict;
use warnings;

use Data::Dumper ;
use LWP::UserAgent;
use HTTP::Request::Common;
use JSON;

use Getopt::Long;

# use KBase::CDMI ;


# Input either
my $id   = '';

GetOptions (
	    'id=s'     => \$id ,
	   );


unless($id){
  print STDERR "No ID provided (e.g. $0 -id YP_003268079.1)\n";
  exit;
}

#  Assumption Refseq, Microbes Online and KBase gene calls are different and md5 matching will not work

#  For input ID and Organism
#      Find KBase organism ID
#      Get all aliases (refseq IDs) for all features and create mapping table
#      Get MD5 and refseq ID for input ID
#      lookup mapping and return KBase ID



 # Initialize HTTP
{
  my $ua = LWP::UserAgent->new;
  $ua->agent("MyClientAW/0.1 ");

  # json object for decoding json string into internal data structures and encode perl data structures into a json string
  my $json = new JSON;

  # Create URL with all parameters

# CHANGE URLS

my $url = { accession => 'http://api.metagenomics.anl.gov/m5nr/accession/' ,
	    md5       => 'http://api.metagenomics.anl.gov/m5nr/md5/',
};

  
  # Retrieve complete record for id and get organism name
  
  my $response = $ua->get($url->{accession}.$id) ;

  # Check if request was successful, exit if error
  &error($response) unless ($response->is_success);

  my $content = $response->content;

  # create PERL data structure from json format
  my $data     = $json->decode($content);
  my $entry    = $data->{data}->[0] ;
  my $organism = $entry->{organism} ;
  my $md5      = $entry->{md5};

  #print Dumper $entry ;
  #print $organism , "\n";

  ######
  # KBase CDM block , create mapping here
  ######

  # Lookup Refseq ID for MO ID

  $response = $ua->get($url->{md5}.$md5."?source=RefSeq") ;
  &error($response) unless ($response->is_success);
  $content = $response->content;
  $data    = $json->decode($content);

  foreach my $entry (@{$data->{data}}){
    # Modify $organism for fuzzy matching
    print  join "\t" , ( $entry->{accession} , $organism ) , "\n" if ($entry->{organism} =~/$organism/)  ;
  }


  # Map Refseq ID with KBase ID using alias mapping

}





sub error{
  my ($response , $error_code) = @_;

  my $json = new JSON;

  print STDERR join "\t" , "ERROR: " , $response->code , "\n";
  eval{
    my $data = $json->decode( $response->content );
    print STDERR "ERROR:\t" . $data->{ERROR} . "\n";
  };
  exit 1;
}

