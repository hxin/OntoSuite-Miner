-- Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--      http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.


# Add schema_type entry to meta table
ALTER TABLE `variation` CHANGE `validation_status` `validation_status` SET('cluster','freq','submitter','doublehit','hapmap','1000Genome','failed','precious');

ALTER TABLE `variation_feature` CHANGE `validation_status` `validation_status` SET('cluster','freq','submitter','doublehit','hapmap','1000Genome','failed','precious');

# patch identifier
INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL,'patch', 'patch_58_59_e.sql|add 1000Genome validation_status');