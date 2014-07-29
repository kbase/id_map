package Bio::KBase::IdMap::IdMapImpl;
use strict;
use Bio::KBase::Exceptions;
# Use Semantic Versioning (2.0.0-rc.1)
# http://semver.org 
our $VERSION = "0.1.0";

=head1 NAME

IdMap

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
Log::Log4perl->easy_init($INFO);
our $cfg = {};
our ($mysql_user, $mysql_pass, $data_source, $cdmi_url);

if (defined $ENV{KB_DEPLOYMENT_CONFIG} && -e $ENV{KB_DEPLOYMENT_CONFIG}) {
    $cfg = new Config::Simple($ENV{KB_DEPLOYMENT_CONFIG}) or
        die "could not construct new Config::Simple object";
    $mysql_user    = $cfg->param('id_map.mysql-user');
    $mysql_pass    = $cfg->param('id_map.mysql-pass');
    $data_source   = $cfg->param('id_map.data-source');
    INFO "$$ reading config from $ENV{KB_DEPLOYMENT_CONFIG}";
    DEBUG "$$ mysl user:   $mysql_user";
    INFO "$$ data source: $data_source";
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
	alias has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$s is a string
$type is a string
$id_pairs is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	alias has a value which is a string
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

These are the two supported cases at this time. Valid types
are NAME and NCBI_TAXID

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

	$id_pairs = [];
	my ($sql, $sth, $rv, $results, $source_db, $q_input);
	my $dbh = $self->{get_dbh}->(); 
       
	if ( uc($type) eq "NAME" ) {
	    $q_input = '%' .uc($s) . '%';
	    $sql = "select distinct g.id from Genome g left outer join ".
		   "IsTaxonomyOf it on it.to_link = g.id left outer join ".
		   "TaxonomicGrouping tg on tg.id = it.from_link ".
		   "where UPPER(tg.scientific_name) like ? or UPPER(g.scientific_name) like ? ";

	    $source_db = 'NCBI';

	}

	elsif ( uc($type) eq "NCBI_TAXID" ) {
	    $sql = "select it.to_link, t.scientific_name from IsTaxonomyOf it ".
		   "inner join TaxonomicGrouping t on it.from_link=t.id ".
		   "where t.id = ? and t.id = ? ";
	    $source_db = 'NCBI';
	    $q_input = $s;

	}
	else {
		die "unrecognized type $type";
	}

	INFO "$$ sql $sql";

        $sth = $dbh->prepare($sql) or die "can not prepare $sql";
        $rv = $sth->execute($q_input,$q_input) or die "can not execute $sql";
        $results = $sth->fetchall_arrayref();

        foreach my $result (@$results) {

            push @{ $id_pairs }, {'source_db' => $source_db,
				  'alias' => $s,
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

  $return = $obj->lookup_features($genome_id, $aliases, $feature_type, $source_db)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_id is a string
$aliases is a reference to a list where each element is a string
$feature_type is a string
$source_db is a string
$return is a reference to a hash where the key is a string and the value is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	alias has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$genome_id is a string
$aliases is a reference to a list where each element is a string
$feature_type is a string
$source_db is a string
$return is a reference to a hash where the key is a string and the value is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	alias has a value which is a string
	kbase_id has a value which is a string


=end text



=item Description

Given a genome id, a list of aliases, a feature type and a source db
return the set of feature ids associated with the aliases.

lookup_features attempts to find feature ids for the aliases provided.
The match is somewhat ambiguous  in that if an alias is provided
that is associated with a feature of type locus, then the
mrna and cds features encompassed in that locus will also be
returned. Therefor it is possible to have multiple feature ids
associated with one alias.

Parameters for the lookup_features function are:
string genome_id     - a kbase genome identifier
list<string> aliases - a list of aliases
string feature_type  - a kbase feature type
string source_db     - a kbase source identifier

To specify all feature types, provide an empty string as the
value of the feature_type parameter. To specify all source databases,
provide an empty string as the value of the source_db parameter.

  The lookup_features function returns a mapping between
  an alias and an IdPair.

=back

=cut

sub lookup_features
{
    my $self = shift;
    my($genome_id, $aliases, $feature_type, $source_db) = @_;

    my @_bad_arguments;
    (!ref($genome_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_id\" (value was \"$genome_id\")");
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

	$return = {};
	my ( $dbh, $sql, $sth, $rv, $in_str, );
	my ( $quoted_gid, $quoted_sid, $quoted_ft, );

	$dbh = $self->{get_dbh}->();
	foreach my $alias (@$aliases) {
		$in_str .= $dbh->quote($alias) . ",";
	}
	$in_str =~ s/,$//;
	$quoted_gid = $dbh->quote($genome_id);
	$quoted_sid = $dbh->quote($source_db);
	$quoted_ft  = $dbh->quote($feature_type);

	if((not $source_db) and (not $feature_type)) {
		DEBUG "$$ not source_db and not feature_tupe"; 
		$sql  = "select * from HasAliasAssertedFrom ";
		$sql .= "where from_link in ( ";
		$sql .= "  select to_link from IsOwnerOf   ";
		$sql .= "  where from_link = $quoted_gid ";
		$sql .= ") and alias in ( $in_str ) ";
        }
	elsif ((not $source_db) and $feature_type ) {
		DEBUG "$$ not source db and feature_type";
		$sql  = "select * from HasAliasAssertedFrom ";
		$sql .= "where from_link in ( ";
		$sql .= "  select o.to_link from IsOwnerOf o, Feature f ";
		$sql .= "  where o.from_link = $quoted_gid ";
		$sql .= "  and o.to_link=f.id and f.feature_type = $quoted_ft ";
		$sql .= ")  and alias in ( $in_str ) ";

	}
	elsif ($source_db and (not $feature_type)) {
		DEBUG "$$ source db and not feature type";
                $sql  = "select * from HasAliasAssertedFrom ";
                $sql .= "where to_link = $quoted_sid and from_link in ( ";
                $sql .= "  select o.to_link from IsOwnerOf o, Feature f ";
                $sql .= "  where o.from_link = $quoted_gid ";
                $sql .= "  and o.to_link=f.id ";
                $sql .= ")  and alias in ( $in_str ) ";
	}
	elsif ($source_db and $feature_type) {
		DEBUG "$$ source db and feature type";
                $sql  = "select * from HasAliasAssertedFrom ";
                $sql .= "where to_link = $quoted_sid and from_link in ( ";
                $sql .= "  select o.to_link from IsOwnerOf o, Feature f ";
                $sql .= "  where o.from_link = $quoted_gid ";
                $sql .= "  and o.to_link=f.id and f.feature_type = $quoted_ft ";
                $sql .= ")  and alias in ( $in_str ) ";
	}
	else {
		die "unanticipated set of parameters";
	}

	INFO "$$ $sql";

	$sth = $dbh->prepare($sql);
	$rv  = $sth->execute();
	
	#+---------------------+----------------+-----------------+
	#| from_link           | to_link        | alias           |
	#+---------------------+----------------+-----------------+
	#| kb|g.3899.CDS.70691 | load_file      | AT1G79940.3.CDS |
	#| kb|g.3899.CDS.70691 | uniprot_gene   | AT1G79940       |

	while ( my $ary_ref = $sth->fetchrow_arrayref ) {
		push @{$return->{$ary_ref->[2]}},
				{'kbase_id' => $ary_ref->[0],
				 'source_db'  => $ary_ref->[1],
				 'alias'      => $ary_ref->[2]};
	}

	$return = {} if not defined $return;

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

  $return = $obj->lookup_feature_synonyms($genome_id, $feature_type)

=over 4

=item Parameter and return types

=begin html

<pre>
$genome_id is a string
$feature_type is a string
$return is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	alias has a value which is a string
	kbase_id has a value which is a string

</pre>

=end html

=begin text

$genome_id is a string
$feature_type is a string
$return is a reference to a list where each element is an IdPair
IdPair is a reference to a hash where the following keys are defined:
	source_db has a value which is a string
	alias has a value which is a string
	kbase_id has a value which is a string


=end text



=item Description

Returns a list of mappings of all possible types of feature
synonyms and external ids to feature kbase ids for a
particular kbase genome, and a given type of a feature.

string genome_id - kbase id of a target genome
string feature_type - type of a kbase feature, e.g. CDS,
pep, etc (see https://trac.kbase.us/projects/kbase/wiki/IDRegistry).
If not provided, all mappings should be returned.

=back

=cut

sub lookup_feature_synonyms
{
    my $self = shift;
    my($genome_id, $feature_type) = @_;

    my @_bad_arguments;
    (!ref($genome_id)) or push(@_bad_arguments, "Invalid type for argument \"genome_id\" (value was \"$genome_id\")");
    (!ref($feature_type)) or push(@_bad_arguments, "Invalid type for argument \"feature_type\" (value was \"$feature_type\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to lookup_feature_synonyms:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'lookup_feature_synonyms');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($return);
    #BEGIN lookup_feature_synonyms

    $return = [];
    my ($sql, $dbh, $sth, $rv, $ary_ref);

    # genome to feature
    # feature to alias
    # aliases to source

    $dbh = $self->{get_dbh}->();

    DEBUG "$$ quoting genome_id $genome_id";
    DEBUG "$$ quoting feature_type $feature_type";
    my $quoted_id = $dbh->quote($genome_id);
    my $quoted_type = $dbh->quote($feature_type);
    DEBUG "$$ qouted genome_genome_id $quoted_id";
    DEBUG "$$ quoted feature_type $quoted_type";

  $sql  = "select * from HasAliasAssertedFrom ";
  $sql .= "where from_link in ";
  $sql .= "(select o.to_link ";
  $sql .= "from IsOwnerOf o, Feature f ";
  $sql .= "where o.from_link = $quoted_id ";
  $sql .= "and f.id = o.to_link ";
  $sql .= "and f.feature_type = $quoted_type)";

  INFO "$$ $sql";

  $sth = $dbh->prepare($sql) or die "could not prepare $sql";
  $rv  = $sth->execute()     or die "could not execute $sql";
  while(my $ary_ref = $sth->fetchrow_arrayref) {
    push @{$return}, {'source_db'  =>  $ary_ref->[1],
		      'alias'  =>  $ary_ref->[2],
		      'kbase_id'   =>  $ary_ref->[0]};
  }

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




=head2 longest_cds_from_locus

  $return = $obj->longest_cds_from_locus($arg_1)

=over 4

=item Parameter and return types

=begin html

<pre>
$arg_1 is a reference to a list where each element is a string
$return is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$arg_1 is a reference to a list where each element is a string
$return is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

Returns a mapping of locus feature id to cds feature id.

=back

=cut

sub longest_cds_from_locus
{
    my $self = shift;
    my($arg_1) = @_;

    my @_bad_arguments;
    (ref($arg_1) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"arg_1\" (value was \"$arg_1\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to longest_cds_from_locus:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'longest_cds_from_locus');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($return);
    #BEGIN longest_cds_from_locus

	my($sql, $dbh, $sth, $rv, @query_ids);

	$dbh = $self->{get_dbh}->();
	foreach (@{ $arg_1 }) {
		push @query_ids, $dbh->quote($_);
	}

	#$sql  = "select t1.to_link, t1.from_link, t2.from_link, f.sequence_length ";
	#$sql .= "from Feature f, Encompasses t1 ";
	#$sql .= "join Encompasses t2 on t1.from_link = t2.to_link ";
	#$sql .= "where t1.to_link in ( ";
	#$sql .= join ",", @query_ids;
	#$sql .= " ) ";
	#$sql .= "and t2.from_link = f.id";

        $sql  = "select t1.from_link, t1.to_link, t2.to_link, f.sequence_length ";
        $sql .= "from Feature f, Encompasses t1 ";
        $sql .= "join Encompasses t2 on t1.to_link = t2.from_link ";
        $sql .= "where t1.from_link in ( ";
        $sql .= join ",", @query_ids;
        $sql .= " ) ";
        $sql .= "and t2.to_link = f.id";

	DEBUG "$$ $sql";

	$sth = $dbh->prepare($sql) or die "can not prepare $sql";
	$rv = $sth->execute() or die "can not execute $sql";
	
	while(my $ary_ref = $sth->fetchrow_arrayref) {
		DEBUG "$$ $ary_ref->[0] $ary_ref->[2] $ary_ref->[3]";
		my ($len) = values %{ $return->{$ary_ref->[0]} };
		$return->{$ary_ref->[0]} = {$ary_ref->[2] => $ary_ref->[3]}
			 if $ary_ref->[3] > $len;
		DEBUG "$$ is $ary_ref->[3] gt $len";
	}
	


# select m2l.to_link as LOCUS, c2m.to_link as mRNA, f.id as CDS, f.sequence_length
# from Feature f left outer join Encompasses c2m on f.id = c2m.from_link
# left outer join Encompasses m2l on c2m.to_link = m2l.from_link
# where substring_index(f.id, '.', 2) = 'kb|g.3899'
# and f.feature_type = 'CDS'
# and ((m2l.to_link is not NULL) or (c2m.to_link is not NULL))
# order by m2l.to_link, c2m.to_link, f.id ;


    #END longest_cds_from_locus
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to longest_cds_from_locus:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'longest_cds_from_locus');
    }
    return($return);
}




=head2 longest_cds_from_mrna

  $return = $obj->longest_cds_from_mrna($arg_1)

=over 4

=item Parameter and return types

=begin html

<pre>
$arg_1 is a reference to a list where each element is a string
$return is a reference to a hash where the key is a string and the value is a string

</pre>

=end html

=begin text

$arg_1 is a reference to a list where each element is a string
$return is a reference to a hash where the key is a string and the value is a string


=end text



=item Description

Returns a mapping a mrna feature id to a cds feature id.

=back

=cut

sub longest_cds_from_mrna
{
    my $self = shift;
    my($arg_1) = @_;

    my @_bad_arguments;
    (ref($arg_1) eq 'ARRAY') or push(@_bad_arguments, "Invalid type for argument \"arg_1\" (value was \"$arg_1\")");
    if (@_bad_arguments) {
	my $msg = "Invalid arguments passed to longest_cds_from_mrna:\n" . join("", map { "\t$_\n" } @_bad_arguments);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'longest_cds_from_mrna');
    }

    my $ctx = $Bio::KBase::IdMap::Service::CallContext;
    my($return);
    #BEGIN longest_cds_from_mrna
        my($sql, $dbh, $sth, $rv, @query_ids);

        my $dbh = $self->{get_dbh}->();
        foreach (@{ $arg_1 }) {
                push @query_ids, $dbh->quote($_);
        }

        $sql  = "select t1.to_link, t1.from_link, t2.from_link, f.sequence_length ";
        $sql .= "from Feature f, Encompasses t1 ";
        $sql .= "join Encompasses t2 on t1.from_link = t2.to_link ";
        $sql .= "where t1.from_link in ( ";
        $sql .= join ",", @query_ids;
        $sql .= " ) ";
        $sql .= "and t2.from_link = f.id";

        DEBUG "$$ $sql";

        $sth = $dbh->prepare($sql) or die "can not prepare $sql";
        $rv = $sth->execute() or die "can not execute $sql";

        while(my $ary_ref = $sth->fetchrow_arrayref) {
                DEBUG "$$ $ary_ref->[1] $ary_ref->[2] $ary_ref->[3]";
                my ($len) = values %{ $return->{$ary_ref->[1]} };
                $return->{$ary_ref->[1]} = {$ary_ref->[0] => $ary_ref->[3]}
                         if $ary_ref->[3] > $len;
                DEBUG "$$ is $ary_ref->[3] gt $len";
        }
    #END longest_cds_from_mrna
    my @_bad_returns;
    (ref($return) eq 'HASH') or push(@_bad_returns, "Invalid type for return variable \"return\" (value was \"$return\")");
    if (@_bad_returns) {
	my $msg = "Invalid returns passed to longest_cds_from_mrna:\n" . join("", map { "\t$_\n" } @_bad_returns);
	Bio::KBase::Exceptions::ArgumentValidationError->throw(error => $msg,
							       method_name => 'longest_cds_from_mrna');
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

A mapping of aliases to the corresponding kbase identifier.

string source_db  - the kbase id of the source
string alias      - the identifier to be mapped to a feature id
string kbase_id - the kbase id of the feature


=item Definition

=begin html

<pre>
a reference to a hash where the following keys are defined:
source_db has a value which is a string
alias has a value which is a string
kbase_id has a value which is a string

</pre>

=end html

=begin text

a reference to a hash where the following keys are defined:
source_db has a value which is a string
alias has a value which is a string
kbase_id has a value which is a string


=end text

=back



=cut

1;
