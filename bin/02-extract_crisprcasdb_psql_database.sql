-- Get general infos on psql connexion
\conninfo


---------
-- Get raw tables of ccpp20220414
---------
\! mkdir -p ./data/raw_tables_ccpp20220414
\echo 'Store table area in "./data/raw_tables_ccpp20220414/area"'
\o ./data/raw_tables_ccpp20220414/area.txt
SELECT * FROM area;
\echo 'Store table clustercas in "./data/raw_tables_ccpp20220414/clustercas"'
\o ./data/raw_tables_ccpp20220414/clustercas.txt
SELECT * FROM clustercas;
\echo 'Store table clustercas_gene in "./data/raw_tables_ccpp20220414/clustercas_gene"'
\o ./data/raw_tables_ccpp20220414/clustercas_gene.txt
SELECT * FROM clustercas_gene;
\echo 'Store table crisprcasdb in "./data/raw_tables_ccpp20220414/crisprcasdb"'
\o ./data/raw_tables_ccpp20220414/crisprcasdb.txt
SELECT * FROM crisprcasdb;
\echo 'Store table crisprcas_stats in "./data/raw_tables_ccpp20220414/crisprcas_stats"'
\o ./data/raw_tables_ccpp20220414/crisprcas_stats.txt
SELECT * FROM crisprcas_stats;
\echo 'Store table crisprlocus in "./data/raw_tables_ccpp20220414/crisprlocus"'
\o ./data/raw_tables_ccpp20220414/crisprlocus.txt
SELECT * FROM crisprlocus;
\echo 'Store table crisprlocus_region in "./data/raw_tables_ccpp20220414/crisprlocus_region"'
\o ./data/raw_tables_ccpp20220414/crisprlocus_region.txt
SELECT * FROM crisprlocus_region;
\echo 'Store table entity in "./data/raw_tables_ccpp20220414/entity"'
\o ./data/raw_tables_ccpp20220414/entity.txt
SELECT * FROM entity;
\echo 'Store table job in "./data/raw_tables_ccpp20220414/job"'
\o ./data/raw_tables_ccpp20220414/job.txt
SELECT * FROM job;
\echo 'Store table member in "./data/raw_tables_ccpp20220414/member"'
\o ./data/raw_tables_ccpp20220414/member.txt
SELECT * FROM member;
\echo 'Store table person in "./data/raw_tables_ccpp20220414/person"'
\o ./data/raw_tables_ccpp20220414/person.txt
SELECT * FROM person;
\echo 'Store table record in "./data/raw_tables_ccpp20220414/record"'
\o ./data/raw_tables_ccpp20220414/record.txt
SELECT * FROM record;
\echo 'Store table region in "./data/raw_tables_ccpp20220414/region"'
\o ./data/raw_tables_ccpp20220414/region.txt
SELECT * FROM region;
\echo 'Store table sequence in "./data/raw_tables_ccpp20220414/sequence"'
\o ./data/raw_tables_ccpp20220414/sequence.txt
SELECT * FROM sequence;
\echo 'Store table strain in "./data/raw_tables_ccpp20220414/strain"'
\o ./data/raw_tables_ccpp20220414/strain.txt
SELECT * FROM strain;
\echo 'Store table taxon in "./data/raw_tables_ccpp20220414/taxon"'
\o ./data/raw_tables_ccpp20220414/taxon.txt
SELECT * FROM taxon;
\echo 'Store table taxon_bacteria in "./data/raw_tables_ccpp20220414/taxon_bacteria"'
\o ./data/raw_tables_ccpp20220414/taxon_bacteria.txt
SELECT * FROM taxon_bacteria;
\echo 'Store table taxon_archaea in "./data/raw_tables_ccpp20220414/taxon_archaea"'
\o ./data/raw_tables_ccpp20220414/taxon_archaea.txt
SELECT * FROM taxon_archaea;
\echo 'Store table update in "./data/raw_tables_ccpp20220414/update"'
\o ./data/raw_tables_ccpp20220414/update.txt
SELECT * FROM update;
\echo 'Store table usage in "./data/raw_tables_ccpp20220414/usage"'
\o ./data/raw_tables_ccpp20220414/usage.txt
SELECT * FROM usage;
\o


-- Create table that will contain all informations
-- to get Cas genes sequences from genomic database


-- Create a table with superkingdom and strain ID
-- only with strains with at least 1 Cas cluster  
CREATE TABLE temptable1
AS
SELECT superkingdom, strain.id AS strain_id, strain.taxon AS taxon_id, genbank, refseq
FROM strain 
INNER JOIN crisprcasdb
ON strain.id=crisprcasdb.id
	-- Select CRISPR-Cas with Cas cluster
	WHERE cas_type!='no_cluster' AND cas_gene!='no_cas';


-- Add strain name to the crisprcasdataset table from the entity table
ALTER TABLE temptable1
ADD COLUMN strain_name character varying(256);
UPDATE temptable1 SET strain_name = (
  SELECT entity.name
  FROM entity
  	WHERE strain_id=entity.id
);
ALTER TABLE temptable1
ALTER COLUMN strain_name SET NOT NULL;

-- Add taxon name to the crisprcasdataset table from the taxon table
ALTER TABLE temptable1
ADD COLUMN taxon_name character varying(256);
UPDATE temptable1 SET taxon_name = (
  SELECT taxon.scientificname
  FROM taxon
  	WHERE taxon_id=taxon.id
);
ALTER TABLE temptable1
ALTER COLUMN taxon_name SET NOT NULL;


-- Add sequence id to the 'crisprcasdataset' table from the 'sequence' table
-- There can be several sequences / strain (Need a CROSS JOIN)
CREATE TABLE temptable2
AS
SELECT strain_name, superkingdom, taxon_id, taxon_name, genbank, refseq, sequence.id AS seq_id, sequence.description AS seq_type
FROM sequence
CROSS JOIN temptable1
	WHERE strain_id=sequence.strain;
-- Drop "temptable1" table
DROP TABLE temptable1;


-- Add cluster Cas type  to the 'crisprcasdataset' table from the 'clustercas' table
-- There can be several clustercas / sequence (Need a CROSS JOIN)
CREATE TABLE temptable3
AS
SELECT strain_name, superkingdom, taxon_id, taxon_name, clustercas.class AS clustercas_type, genbank, refseq, seq_type, clustercas.id AS clustercas_id
FROM clustercas
CROSS JOIN temptable2
	WHERE seq_id=clustercas.sequence;
-- Drop "temptable2" table
DROP TABLE temptable2;


-- Add Cas gene to the 'crisprcasdataset' table from the 'clustercas_gene' table
-- There can be several Cas gene / cluster Cas (Need a CROSS JOIN)
CREATE TABLE crisprcasdataset
AS
SELECT strain_name, superkingdom, taxon_id, taxon_name, genbank, refseq, seq_type, clustercas_type, clustercas_id, clustercas_gene.gene AS cas_gene, clustercas_gene.start, clustercas_gene.length, clustercas_gene.orientation
FROM clustercas_gene
CROSS JOIN temptable3
	WHERE clustercas_id=clustercas_gene.clustercas;
-- Drop "temptable3" table
DROP TABLE temptable3;

-- Store "crisprcasdataset" table in CSV file 'crisprcas_dataset.csv' 
\copy crisprcasdataset TO './data/crisprcas_dataset.csv' DELIMITER '~' CSV
-- Drop "crisprcasdataset" table
DROP TABLE crisprcasdataset;
