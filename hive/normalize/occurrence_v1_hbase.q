-- This script requires three parameters to be passed in the command line: mapcount (# of mappers), occjar (the occurrence-hive.jar to use), and snapshot (e.g. 20071219)

-- Fix UDF classpath issues
SET mapreduce.task.classpath.user.precedence = true;
SET mapreduce.user.classpath.first=true;
SET mapreduce.job.user.classpath.first=true;

-- Use Snappy
SET hive.exec.compress.output=true;
SET mapred.output.compression.type=BLOCK;
SET mapred.output.compression.codec=org.apache.hadoop.io.compress.SnappyCodec;

SET mapred.map.tasks = ${hiveconf:mapcount};

-- Set up memory for YARN
SET mapreduce.map.memory.mb = 4096;
SET mapreduce.reduce.memory.mb = 4096;
SET mapreduce.map.java.opts = -Xmx3072m;
SET mapreduce.reduce.java.opts = -Xmx3072m;


ADD JAR ${hiveconf:occjar};
CREATE TEMPORARY FUNCTION parseDate AS 'org.gbif.occurrence.hive.udf.DateParseUDF';
CREATE TEMPORARY FUNCTION parseBoR AS 'org.gbif.occurrence.hive.udf.BasisOfRecordParseUDF';

DROP TABLE IF EXISTS snapshot.occurrence_${hiveconf:snapshot};
CREATE TABLE snapshot.occurrence_${hiveconf:snapshot} STORED AS rcfile AS
SELECT
  r.id,
  r.dataset_id,
  r.publisher_id,
  r.publisher_country,
  t.kingdom,
  t.phylum,
  t.class_rank,
  t.order_rank,
  t.family,
  t.genus,
  t.species,
  t.scientific_name,
  t.kingdom_id,
  t.phylum_id,
  t.class_id,
  t.order_id,
  t.family_id,
  t.genus_id,
  t.species_id,
  t.taxon_id,
  r.basis_of_record,
  g.latitude,
  g.longitude,
  g.country,
  d.day,
  d.month,
  d.year
  FROM
  (SELECT
   id,
   dataset_id,
   publisher_id,
   publisher_country,
   CONCAT_WS("|",
             COALESCE(kingdom, ""),
             COALESCE(phylum, ""),
             COALESCE(class_rank, ""),
             COALESCE(order_rank, ""),
             COALESCE(family, ""),
             COALESCE(genus, ""),
             COALESCE(scientific_name, ""),
             COALESCE(specific_epithet,""),
             COALESCE(infraspecific_epithet, ""),
             COALESCE(author, ""),
             COALESCE(taxon_rank,"")
   ) as taxon_key,
   CONCAT_WS("|",
             COALESCE(latitude, ""),
             COALESCE(longitude, ""),
             COALESCE(country, "")
   ) as geo_key,
   parseDate(year,month,day,event_date) d,
   parseBoR(basis_of_record) as basis_of_record
 FROM snapshot.raw_${hiveconf:snapshot}
) r
JOIN snapshot.tmp_taxonomy_interp t ON t.taxon_key = r.taxon_key
JOIN snapshot.tmp_geo_interp g ON g.geo_key = r.geo_key;
