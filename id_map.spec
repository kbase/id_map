/*  The IdMap service client provides various lookups. These
    lookups are designed to provide mappings of external
    identifiers to kbase identifiers. 

    Not all lookups are easily represented as one-to-one
    mappings.
*/

module IdMap {

  /*  An IdPair object represents a mapping of a kbase id
      to an external id. Additional information includes
      the source database of the external id.
  */

  typedef structure {
    string source_db;
    string source_id;
    string kbase_id;
  } IdPair;

  /*  Makes an attempt to map external identifier of a genome to
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
  */

  funcdef lookup_genome(string s, string type)
    returns (list<IdPair> id_pairs);


  /*  Makes an attempt to map external identifiers of features
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

      The return is a mapping OF WHAT?
  */

  funcdef lookup_features(string kb_genome_id, list<string> aliases, string feature_type, string source_db)
    returns ( mapping<string, list<IdPair>> );


/*
    Returns a list of mappings of all possible types of feature
    synonyms and external ids to feature kbase ids for a
    particular kbase genome, and a given type of a feature.

    string genome_kbase_id - kbase id of a target genome
    string feature_type - type of a kbase feature, e.g. CDS,
    pep, etc (see https://trac.kbase.us/projects/kbase/wiki/IDRegistry).
    If not provided, all mappings should be returned.
*/


    funcdef lookup_feature_synonyms(string kbase_id, string feature_type)
       returns (list<IdPair>);


/*
    Returns - A mapping of locus feature id to cds feature id
*/
    funcdef longest_cds_from_locus(list<string>)
        returns (mapping<string, string>);

/*

*/
    funcdef longest_cds_from_mrna(list<string>)
        returns (mapping<string, string>);




};

