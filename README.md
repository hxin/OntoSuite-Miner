# OntoSuite-Miner

*OntoSuite-Miner* is a framework composed of a set of Linux shell scripts, Perl/R scripts and two concept recognizers, the MetaMap and the NCBO Annotator working together to automate the creation of ontology based annotation from publicly available data repositories. The main purpose of the *OntoSuite-Miner* is to link genes with ontology terms given their free text annotation from a variety of sources. 

A high-level schematic describtion is shown in file *OntoSuit-Miner_workflow.png*. 


##NCBO Annotator
The [NCBO Annotator](https://bioportal.bioontology.org/annotator) is an ontology-based Web service that annotates textual meta data with biomedical ontology concepts (terms). It allows users to tag their data automatically with ontology concepts. These concepts come from National Center for [Biomedical Ontology (NCBO)](https://bioportal.bioontology.org/ontologies) BioPortal, an ontology repository containing more than 500 ontologies (September 2016). 

Despite a RESTFUL web service, NCBO also provides a virtual appliance which contains a pre-installed, pre-configured version of the NCBO Annotator that can be run locally on a Linux operating system. It simulates an environment which provides all the pre-requirements (scripts, libs etc.) for the NCBO Annotator and provides the same service locally to the user with a shorter response time and more flexibility on configuration. Ontologies that are currently not in the NCBO BioPortal repository can also be added locally.

[NCBO Annotator virtual appliance](https://www.bioontology.org/wiki/index.php/Category:NCBO_Virtual_Appliance) is not publicly available. To obtain the VMWare Virtual Appliance, contact NCBO Support to initiate your request. You'll then be asked privately for your BioPortal account username. organizational goals, and reason for preferring the local installation. If you don't have a BioPortal account, you can create one at [here](http://bit.ly/bioportal-account). The overall transaction can take a few working days, depending on resource availability.


*OntoSuite-Miner* implements NCBO VIRTUAL APPLIANCE v2.4.

##MetaMap
The [MetaMap](https://metamap.nlm.nih.gov/) is a highly configurable program developed at the National Library of Medicine (NLM) to map biomedical text to the UMLS Metathesaurus or, equivalently, to discover Metathesaurus concepts referred to in text. MetaMap can runlocally on a Linux machine. It parses input text into noun phrases and generates theirvariants including alternate spellings, abbreviations, synonyms, inflections and derivations. A candidate set of Metathesaurus concepts were identified and scored based onthe strength of mapping from the variants to each candidate concept. MetaMap natively works with UMLS Metathesaurus, but can be optionally configured to work on any ontology. The [data file builder (DFB)](https://metamap.nlm.nih.gov/DataFileBuilder.shtml) provided by MetaMap allows the transformation of an ontology into UMLS database tables which is the default dictionaryformat used by MetaMap.


*OntoSuite-Miner* implements [MetaMap 2013](https://metamap.nlm.nih.gov/Docs/Metamap13_Usage.shtml).