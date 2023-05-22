#!/bin/bash
###
###   Goal:
###      Script to load CRISPRCasdb PostGreSQL (psql) database
###      on psql terminal
###
###   INPUT:
###      1- CRIPSRCasdb database PostGreSQL dump
###         (./data/20220414_ccpp_recette_chromo_complete.sql)
###      2- CRIPSRCasdb database name
###         (ccpp20220414)
###
###   OUTPUT:
###      - Load CRISPRCasdb database SQL Dump on the psql database
###        ccpp20220414 owned by $USER (Linux username account)
###
###   Name: 01-load_crisprcasdb_psql_dump.sh    Author: Yoann Anselmetti
###   Creation date: 2023/03/22                 Last modification: 2023/03/22
###

sudo -u postgres createuser -sdr $USER
createdb $2
psql -U $USER -d $2 -a -f $1
sudo -u $USER psql $2
