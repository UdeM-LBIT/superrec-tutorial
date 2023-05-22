#!/bin/bash
###
###   Goal:
###      Script to refine CRISPRCasdb CSV file
###
###   INPUT:
###      1- CRIPSRCasdb database PostGreSQL dump
###         (./data/crisprcas_dataset.csv)
###
###   OUTPUT:
###      - Refined CRISPRCasdb CSV file
###
###   Name: 03-refine_crisprcasdb_csv_file.sh   Author: Yoann Anselmetti
###   Creation date: 2023/03/22                 Last modification: 2023/03/22
###

sed -i 's/"//g' $1
sed -i 'N;s/\n / /g' $1
sed -i 'N;s/ \n/ /g' $1