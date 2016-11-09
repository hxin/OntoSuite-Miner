#!/bin/sh
BASEDIR=$(dirname $0)

##load global incl
[ -f $BASEDIR/../../../global.sh ] && . $BASEDIR/../../../global.sh || { echo >&2 "Cannot find global.sh!"; exit 1; }

sourcename='GENERIF'
ontname='HPO'
text_column_name='rif'


[ ! -d $BASEDIR/$ontname ] && mkdir $BASEDIR/$ontname || rm -rf $BASEDIR/$ontname/* ;



cat <<EOF > $BASEDIR/$ontname/mappingtable.sqlite
BEGIN TRANSACTION;


/*####################################
## mapping table raw
####################################*/
DROP TABLE IF EXISTS "mapping_${ontname}_${sourcename}_raw";
CREATE TABLE "mapping_${ontname}_${sourcename}_raw" ( "text" TEXT, "term_id" VARCHAR, "term_name" VARCHAR, "mapping_score" INTEGER, "mapping_tool" VARCHAR);
CREATE INDEX mapping_${ontname}_${sourcename}_raw_term_id ON mapping_${ontname}_${sourcename}_raw (term_id);
CREATE INDEX mapping_${ontname}_${sourcename}_raw_mapping_score ON mapping_${ontname}_${sourcename}_raw (mapping_score);
CREATE INDEX mapping_${ontname}_${sourcename}_raw_mapping_tool ON mapping_${ontname}_${sourcename}_raw (mapping_tool);

/*####################################
## mapping table filter
####################################*/
DROP TABLE IF EXISTS "mapping_${ontname}_${sourcename}_filter";
CREATE TABLE "mapping_${ontname}_${sourcename}_filter" ( "text" TEXT, "term_id" VARCHAR, "term_name" VARCHAR, "mapping_score" INTEGER, "mapping_tool" VARCHAR);
CREATE INDEX mapping_${ontname}_${sourcename}_filter_term_id ON mapping_${ontname}_${sourcename}_filter (term_id);
CREATE INDEX mapping_${ontname}_${sourcename}_filter_mapping_score ON mapping_${ontname}_${sourcename}_filter (mapping_score);
CREATE INDEX mapping_${ontname}_${sourcename}_filter_mapping_tool ON mapping_${ontname}_${sourcename}_filter (mapping_tool);

COMMIT;

EOF


cat <<EOF >$BASEDIR/$ontname/join.sqlite
BEGIN TRANSACTION;
/*####################################
####You need to create your own join table !!
####################################*/
DROP TABLE IF EXISTS "gene2${ontname}_$sourcename";
CREATE table "gene2${ontname}_$sourcename"(
"entrez_id" INT,
"pubmed_id" VARCHAR,
"rif" TEXT,
"term_id" VARCHAR,
"term_name" VARCHAR,
"mapping_tool" VARCHAR,
"mapping_confident" INT
);

Insert into "gene2${ontname}_$sourcename"
select distinct t1.*,t2.term_id,lower(t2.term_name) as term_name,t2.mapping_tool,t2.mapping_confident from source_$sourcename as t1 
left join (select text,term_id,term_name,group_concat(mapping_tool) as mapping_tool,count(mapping_tool) as mapping_confident from mapping_${ontname}_${sourcename}_filter
group by text,term_id) as t2 
on t1.${text_column_name}=t2.text;

CREATE INDEX v2_gene2${ontname}_$sourcename ON gene2${ontname}_${sourcename} (term_id);
CREATE INDEX v3_gene2${ontname}_$sourcename ON gene2${ontname}_$sourcename (term_name);
CREATE INDEX v4_gene2${ontname}_$sourcename ON gene2${ontname}_$sourcename (entrez_id);
CREATE INDEX v5_gene2${ontname}_$sourcename ON gene2${ontname}_$sourcename (pubmed_id);
CREATE INDEX v7_gene2${ontname}_$sourcename ON gene2${ontname}_$sourcename (mapping_tool);
CREATE INDEX v6_gene2${ontname}_$sourcename ON gene2${ontname}_$sourcename (mapping_confident);


COMMIT;
REINDEX gene2${ontname}_$sourcename;
EOF


