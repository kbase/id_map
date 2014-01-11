package Bio::KBase::IdMap::IdMapImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

IdMapper

=head1 DESCRIPTION

The IdMap service client provides various lookups. These
lookups are designed to provide mappings of external
identifiers to kbase identifiers. 

Not all lookups are easily represented as one-to-one
mappings.

=cut

#BEGIN_HEADER
use DBI;
use Data::Dumper;
use Config::Simple;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($DEBUG);
use Bio::KBase::CDMI::Client;
our $cfg = {};
our ($mysql_user, $mysql_pass, $data_source, $cdmi_url);

if (defined $ENV{KB_DEPLOYMENT_CONFIG} && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
    $cfg = new Config::Simple($ENV{KB_DEPLOYMENT_CONFIG}) or
        die "could not construct new Config::Simple object";
    $mysql_user    = $cfg->param('id_map.mysql-user');
    $mysql_pass    = $cfg->param('id_map.mysql-pass');
    $data_source   = $cfg->param('id_map.data-source');
    $cdmi_url      = $cfg->param('id_map.cdmi_url');
    INFO "$$ reading config from $ENV{KB_DEPLOYMENT_CONFIG}";
    INFO "$$ mysl user:   $mysql_user";
    INFO "$$ data source: $data_source";
    INFO "$$ cdmi url:    $cdmi_url";
}
else {
    die "could not find KB_DEPLOYMENT_CONFIG";
}
#END_HEADER

sub new
{
    my($class, @args) = @_;
    my $self = {
    };
    bless $self, $class;
    #BEGIN_CONSTRUCTOR

        my @connection = ($data_source, $mysql_user, $mysql_pass, {});
        $self->{dbh} = DBI->connect(@connection) or die "could not connect";

	# make reliable connection
        $self->{get_dbh} = sub {
                unless ($self->{dbh}->ping) {
                        $self->{dbh} = DBI->connect(@connection);
                }
                return $self->{dbh};
        };

	# create client interface to central store
	$self->{cdmi} = Bio::KBase::CDMI::Client->new($cdmi_url);
		
    #END_CONSTRUCTOR

    if ($self->can('_init_instance'))
    {
	$self->_init_instance();
    }
    return $self;
}

=head1 METHODS



=head2 lookup_genome

  $id_pairs = $obj->lookup_genome($s, $type)

=over 4

=item Parameter and return types

=begin html

<pre>
$s is a string
$type is a string
$id_pairs is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$s is a string
$type is a string
$id_pairs is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string


=end text



=item Description

Makes an attempt to map external identifier of a genome to
the corresponding kbase identifier. Multiple candidates can
be found, thus a list of IdPairs is returned.

string s - a string that represents some sort of genome
identifier. The type of identifier is resolved with the
type parameter.

string type - this provides information about the tupe
of alias that is provided as the first parameter.

An example of the parameters is the first parameter could
be a string "Burkholderia" and the type could be
scientific_name.

A second example is the first parmater could be an integer
and the type could be ncbi_taxonid.

These are the two supported cases at this time.

=back

=cut

sub lookup_genome
{
    my $self = shift;
    my($s, $type) = @_;

    my @_bad_arguments;
    (!ref($s)) or push(@_bad_arguments, "Invalid type for argument \"s\" (value was \"$s\")");
    (!ref($type)) or push(@_bad_arguments, "Invalid type for argument \"type\" (value was \"$type\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to lookup_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_genome');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($id_pairs);
    #BEGIN lookup_genome

	my ($sql, $rs, $results, $id_pairs, $source_db);
	my $dbh = $self->{get_dbh}->();

	if ( uc($type) eq "NAME" ) {

	    $sql  = "select id from Genome ";
	    $sql .= "where UPPER(scientific_name) like \'$s\%\'";

	    $source_db = 'NCBI';

	}

	elsif ( uc($type) eq "NCBI_TAXID" ) {

	    $sql  = "select g.id, t.scientific_name ";
	    $sql .= "from Genome g, TaxonomicGrouping t ";
	    $sql .= "where g.scientific_name = t.scientific_name ";
	    $sql .= "and t.id = $s";

	    $source_db = 'NCBI';

	}

        $dbh->prepare($sql) or die "can not prepare $sql";
        $rs = $dbh->execute($sql) or die "can not execute $sql";
        $results = fetchall_arrayref();

	$id_pairs = [];
        foreach my $result (@$results) {

            push @{ $id_pairs }, {'source_db' => $source_db,
				  'source_id' => $s,
				  'kbase_id'  => $result->[0],
				 };
        }


    #END lookup_genome
    my @_bad_returns;
    (ref($id_pairs) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"id_pairs\" (value was \"$id_pairs\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to lookup_genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_genome');
    }
    return($id_pairs);
}




=head2 lookup_features

  $return = $obj->lookup_features($kb_genome_id, $aliases, $feature_type, $source_db)

=over 4

=item Parameter and return types

=begin html

<pre>
$kb_genome_id is a string
$aliases is a reference to a list where each element is a string
$feature_type is a string
$source_db is a string
$return is a reference to a hash where the key is a string and the value is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$kb_genome_id is a string
$aliases is a reference to a list where each element is a string
$feature_type is a string
$source_db is a string
$return is a reference to a hash where the key is a string and the value is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string


=end text



=item Description

Makes an attempt to map external identifiers of features
(genes, proteins, etc) to the corresponding kbase
identifiers. Multiple candidates can be found per each
external feature identifier.

string kb_genome_id  - kbase id of a target genome

list<string> aliases - list of aliases to lookup. 

string feature_type  - type of a kbase feature to map to,
Supported types are 'CDS'.

string source_db     - the name of a database to consider as
a source of a feature_ids. If not provided, all databases
should be considered,

=back

=cut

sub lookup_features
{
    my $self = shift;
    my($kb_genome_id, $aliases, $feature_type, $source_db) = @_;

    my @_bad_arguments;
    (!ref($kb_genome_id)) or push(@_bad_arguments, "Invalid type for argument \"kb_genome_id\" (value was \"$kb_genome_id\")");
    (ref($aliases) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"aliases\" (value was \"$aliases\")");
    (!ref($feature_type)) or push(@_bad_arguments, "Invalid type for argument \"feature_type\" (value was \"$feature_type\")");
    (!ref($source_db)) or push(@_bad_arguments, "Invalid type for argument \"source_db\" (value was \"$source_db\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to lookup_features:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_features');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($return);
    #BEGIN lookup_features

#	my $fids = $self->{}->aliases_to_fids($aliases);



    #END lookup_features
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to lookup_features:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_features');
    }
    return($return);
}




=head2 lookup_feature_synonyms

  $return = $obj->lookup_feature_synonyms($genome_kbase_id, $feature_type)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_kbase_id is a string
$feature_type is a string
$return is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$genome_kbase_id is a string
$feature_type is a string
$return is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string


=end text



=item Description

Returns a list of mappings of all possible types of feature
synonyms and external ids to feature kbase ids for a
particular kbase genome, and a given type of a feature.

string genome_kbase_id - kbase id of a target genome
string feature_type - type of a kbase feature, e.g. CDS,
pep, etc (see
https://trac.kbase.us/projects/kbase/wiki/IDRegistry). If
not provided, all mappings should be returned

=back

=cut

sub lookup_feature_synonyms
{
    my $self = shift;
    my($genome_kbase_id, $feature_type) = @_;

    my @_bad_arguments;
    (!ref($genome_kbase_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_kbase_id\" (value was \"$genome_kbase_id\")");
    (!ref($feature_type)) or push(@_bad_arguments, "Invalid type for argument \"feature_type\" (value was \"$feature_type\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to lookup_feature_synonyms:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_feature_synonyms');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($return);
    #BEGIN lookup_feature_synonyms



# aliases_to_fids

  # $return = $obj->aliases_to_fids($aliases)

# Parameter and return types

#    $aliases is an aliases
#    $return is a reference to a hash where the key is an alias and the value is a fid
#    aliases is a reference to a list where each element is an alias
#    alias is a string
#    fid is a string









    #END lookup_feature_synonyms
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to lookup_feature_synonyms:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_feature_synonyms');
    }
    return($return);
}




=head2 version 

  $return = $obj->version()

=over 4

=item Parameter and return types

=begin html

<pre>
$return is a string
</pre>

=end html

=begin text

$return is a string

=end text

=item Description

Return the module version. This is a Semantic Versioning number.

=back

=cut

sub version {
    return $VERSION;
}

=head1 TYPES



=head2 IdPair

=over 4



=item Description

An IdPair object represents a mapping of a kbase id
to an external id. Additional information includes
the source database of the external id.


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
source_db has a value which is a string
source_id has a value which is a string
kbase_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
source_db has a value which is a string
source_id has a value which is a string
kbase_id has a value which is a string


=end text

=back



=cut

1;
