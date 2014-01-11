package Bio::KBase::IdMap::IdMapImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

IdMapper

=head1 DESCRIPTION



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
	print STDERR join(", ", @connection);
        # need some assurance that the handle is still connected. not 
        # totally sure this will work. needs to be tested.
        $self->{get_dbh} = sub {
                unless ($self->{dbh}->ping) {
                        $self->{dbh} = DBI->connect(@connection);
                }
                return $self->{dbh};
        };	
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

  $return = $obj->lookup_genome($genome_id)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_id is a string
$return is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$genome_id is a string
$return is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	source_id has a value which is a string
	kbase_id has a value which is a string


=end text



=item Description

Makes an attempt to map external identifier of a genome to
the corresponding kbase identifier. Multiple candidates can
be found, thus a list of IdPairs is returned.

string genome_id - a genome identifier. The genome identifier
can be taxonomy id, genome name, or any other genome
identifier.

NOTE: This needs to be clarified. "any other genome
identifier" is an unconstrained statement. We need percise
not abstract statements here.

=back

=cut

sub lookup_genome
{
    my $self = shift;
    my($genome_id) = @_;

    my @_bad_arguments;
    (!ref($genome_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_id\" (value was \"$genome_id\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to lookup_genome:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_genome');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($return);
    #BEGIN lookup_genome
	my $dbh = $self->{get_dbh}->();
	my $sql = "select id from Genome where UPPER(scientific_name) ";
	$sql   .= "like \'$genome_id%\'";
	$dbh->prepare($sql) or die "can not prepare $sql";
	my $rs = $dbh->execute($sql) or die "can not execute $sql";
	$return = fetchall_arrayref();

    #END lookup_genome
    my @_bad_returns;
    (ref($return) eq 'ARRAY') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to lookup_genome:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_genome');
    }
    return($return);
}




=head2 lookup_features

  $return = $obj->lookup_features($genome_kbase_id, $feature_ids, $feature_type, $source_db)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_kbase_id is a string
$feature_ids is a reference to a list where each element is a string
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

$genome_kbase_id is a string
$feature_ids is a reference to a list where each element is a string
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

    string genome_kbase_id - kbase id of a target genome
    list<string> feature_ids - list of feature identifiers.
        e.g. locus tag, gene name, MO locus id, etc.

        NOTE: Again, specificity of statements. 'etc' is not
        specific and should not be included in this document.

    string feature_type - type of a kbase feature to map to,
        e.g. CDS, pep, etc (see
        https://trac.kbase.us/projects/kbase/wiki/IDRegistry). If
        not provided, all mappings should be returned

        NOTE: We need the specific list of feature types that
        will be supported.

    string source_db - the name of a database to consider as
        a source of a feature_ids. If not provided, all databases
        should be considered,

=back

=cut

sub lookup_features
{
    my $self = shift;
    my($genome_kbase_id, $feature_ids, $feature_type, $source_db) = @_;

    my @_bad_arguments;
    (!ref($genome_kbase_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_kbase_id\" (value was \"$genome_kbase_id\")");
    (ref($feature_ids) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"feature_ids\" (value was \"$feature_ids\")");
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

A mapping of external identifier of an object to a
corresponding kbase identifier.

string source_db - source database/resource of the object
                                   to be mapped to kbase id
string source_id - identifier of the object to be mapped to
                                   kbase id
string kbase_id  - identifier of the same object in the
                                   KBase name space

Supported external databases are maintained as a
controlled vocabulary, and include:


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
