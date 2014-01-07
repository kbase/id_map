module IdMapper {

/*
	Useful refs: http://www.uniprot.org/mapping/

	IdMap service enables mapping of external ids to kbase
	ids for genomes, genes, and proteins. Future releases will
	expand the set of biological objects that are associated
	through id maps.
*/



/*
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

*/

typedef structure{
	string source_db;
	string source_id;
	string kbase_id;
} IdPair;


/*
Makes an attempt to map external identifier of a genome to
the corresponding kbase identifier. Multiple candidates can
be found, thus a list of IdPairs is returned.

string genome_id - a genome identifier. The genome identifier
can be taxonomy id, genome name, or any other genome
identifier.

NOTE: This needs to be clarified. "any other genome
identifier" is an unconstrained statement. We need percise
not abstract statements here.

*/
funcdef lookup_genome(string genome_id) returns (list<IdPair>);


/*
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
*/


funcdef lookup_features(string genome_kbase_id, list<string> feature_ids, string feature_type, string source_db)
	returns ( mapping<string, list<IdPair>> );


/*
Returns a list of mappings of all possible types of feature
synonyms and external ids to feature kbase ids for a
particular kbase genome, and a given type of a feature.

string genome_kbase_id - kbase id of a target genome
string feature_type - type of a kbase feature, e.g. CDS,
pep, etc (see
https://trac.kbase.us/projects/kbase/wiki/IDRegistry). If
not provided, all mappings should be returned
*/


funcdef lookup_feature_synonyms(string genome_kbase_id, string feature_type)
	returns (list<IdPair>);

};

