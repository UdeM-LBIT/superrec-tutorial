#!/usr/bin/env python3
# -*- coding: utf-8 -*-
###
###   Goal:
###      Method to produce input data for the Super DTL reconciliation
###      from CSV produced from the CRISPR-Cas++ database SQL dump
###      
###
###   INPUT:
###      1- CRISPR-Cas data CSV file
###         (./data/crisprcas_dataset_curated.csv)
###      2- OUTPUT directory
###         (defaut: ./)
###      3- verbose level
###         (default: 1)
###
###   OUTPUT:
###      - Cas gene sequences present in CRISPR-Cas data CSV file
###        recovers from SQL database dump from the CRISPR-Cas++ database
###      
###
###   Name: 04-build_crisprcas_dataset_for_superrecDTL.py   Author: Yoann Anselmetti
###   Creation date: 2022/10/03                             Last modification: 2023/03/22
###


import sys
from os import path, makedirs, system
from collections import defaultdict
import argparse
from datetime import datetime
import errno

def mkdir_p(dir_path):
   try:
      makedirs(dir_path)
   except OSError as exc: # Python >2.5
      if exc.errno == errno.EEXIST and path.isdir(dir_path):
         pass
      else:
         raise
    
def parse_crisprcas_csvfile(csv_file,species_list,sep,output_dir,get_sequence,verbose):

   ### 
   previous_strain,previous_clustercas_type,previous_clustercas_id="","",""
   i=1
   in_cas_gene=open(csv_file,"r")
   dict_ID=dict()
   for line in in_cas_gene:
      if verbose>1:
         print(line)
      line.replace("/","\\")
      strain,superkingdom,taxon_id,taxon_name,refseq,genbank,seq_type,clustercas_type,clustercas_id,cas_gene,start,length,orientation=line.rstrip().split(sep)
      stop=str(int(start)+int(length)+1)

      print(taxon_name)
      if taxon_name.replace(" ","_") in species_list:

         if verbose>1:
            print("# "+taxon_name+"\t->\t"+strain)
         taxon_name=taxon_name.replace(" ","_")
         strain=strain.replace(" ","_")
         if verbose:
            print("# "+taxon_name+"\t->\t"+strain)


         if not path.exists(output_dir+"/"+superkingdom):
            makedirs(output_dir+"/"+superkingdom)

         if not path.exists(output_dir+"/"+superkingdom+"/"+taxon_name):
            makedirs(output_dir+"/"+superkingdom+"/"+taxon_name)

         if not path.exists(output_dir+"/"+superkingdom+"/"+taxon_name+"/"+strain):
            makedirs(output_dir+"/"+superkingdom+"/"+taxon_name+"/"+strain)




         clustercas_dir=output_dir+"/"+superkingdom+"/"+taxon_name+"/"+strain+"/"+clustercas_type
         if not path.exists(clustercas_dir):
            makedirs(clustercas_dir)

         if strain==previous_strain and clustercas_type==previous_clustercas_type:
            if clustercas_id!=previous_clustercas_id:
               i+=1
         else:
            i=1

         cas_gene_fasta=clustercas_dir+"/"+clustercas_type+"_"+str(i)+"_"+cas_gene+"_ori"+orientation+".fasta"


         ### Store current strain, clustercas_type and cluster_id 
         previous_strain,previous_clustercas_type,previous_clustercas_id=strain,clustercas_type,clustercas_id



         if get_sequence:
            # # OLD CODE -> Only RefSeq is present for all sequences
            # # Moreover to 1 GenBank ID can be associated several sequences....
            # # -> Modification of the code to use only RefSeq and elink to the "nuccore" database
            # accession_number=""
            # database=""
            # if genbank:
            #    accession_number=genbank
            #    database="nuccore"
            # elif refseq:
            #    accession_number=refseq
            #    database="genome"
            # else:
            #    print("!!! WARNING: There is no accession number for current Cas gene !!!")
            
            # # Use EDirect to get Cas gene sequence
            # if verbose:
            #    print('esearch -db "'+database+'" -query "'+accession_number+'" | efetch -format fasta -seq_start "'+start+'" -seq_stop "'+stop+'" > "'+cas_gene_fasta+'"')
            # system('esearch -db "'+database+'" -query "'+accession_number+'" | efetch -format fasta -seq_start "'+start+'" -seq_stop "'+stop+'" > "'+cas_gene_fasta+'"')


            # Use EDirect to get Cas gene sequence
            taxon_name=taxon_name.replace("_"," ")
            if verbose:
               print('esearch -db genome -query "'+refseq+'" | elink -target nuccore|efilter -query "'+taxon_name+'"|efilter -query "'+seq_type+'"| efetch -format fasta -seq_start "'+start+'" -seq_stop "'+stop+'" > "'+cas_gene_fasta+'"')
            system('esearch -db genome -query "'+refseq+'" | elink -target nuccore|efilter -query "'+taxon_name+'"|efilter -query "'+seq_type+'"| efetch -format fasta -seq_start "'+start+'" -seq_stop "'+stop+'" > "'+cas_gene_fasta+'"')



if __name__ == '__main__':


   start_time = datetime.now()

   #example command line
   #python build_crisprcas_dataset_for_superrecDTL.py -c head100.csv -o crisprcas_sequences;


   get_sequence=True


   parser = argparse.ArgumentParser(description='CRISPR-Cas datatset building from CRISPR-Cas++ SQL dump database')
   parser.add_argument('--csv_file', '-c', required = True, dest = 'csv_file', help = '''
                           CSV file obtained from PostGreSQL script to get CRISPR-Cas data from CRISPR-Cas++ SQL dump database.''')
   parser.add_argument('--species_list_file', '-l', required = True, dest = 'species_list_file', help = '''
                           List of species in which the Cas gene sequences will be collected.''')
   parser.add_argument('--separator', '-s', default = "~", dest = 'sep', help = '''Separator used to delimit columns of the CSV file.''')
   parser.add_argument('--output', '-o', default = ".", dest = 'output_dir', help = '''
                           Output directory where CSV file parsing will be stored''')                        
   parser.add_argument('--verbose', '-v', default = 1, dest = 'verbose', type=int, help = 'Verbose')

   args = parser.parse_args()


   mkdir_p(args.output_dir)

   species_list=open(args.species_list_file).read().splitlines()
   for species in species_list:
      print(species)


   parse_crisprcas_csvfile(args.csv_file,species_list,args.sep,args.output_dir,get_sequence,args.verbose)
 

   end_time = datetime.now()
   print('\nDuration: {}'.format(end_time - start_time))
   
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
