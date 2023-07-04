#lang pollen
◊; vim: set spelllang=en:

◊header{
    ◊h1{Tutorial on Phylogenetic (Super-)Reconciliation}
    ◊h2{by Mattéo Delabre and Nadia El-Mabrouk}
}

The goal of this hands-on session is to experiment with phylogenetic tree reconstruction and ◊out-link["https://en.wikipedia.org/wiki/Phylogenetic_reconciliation"]{(super-)reconciliation}, using a case study on ◊out-link["https://en.wikipedia.org/wiki/CRISPR"]{CRISPR-Cas systems}.
Our final result will be a hypothetical evolutionary scenario for a subset of Cas gene clusters.
We will go through a complete pipeline, starting with the retrieval of Cas cluster information, up to building the scenario using reconciliation techniques.

◊;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

◊link-h2["prerequisites"]{Prerequisites}

To follow along this tutorial, you will need a Unix-like environment with the latest versions of the tools we are going to use.
The easiest way to set this up is by running the provided Docker container.
If needed, refer to one the following webpages for instructions on how to install Docker, depending on your operating system.

◊ul{
    ◊li{◊out-link["https://docs.docker.com/engine/install/ubuntu/"]{Ubuntu instructions}}
    ◊li{◊out-link["https://wiki.archlinux.org/title/Docker"]{Arch Linux instructions}}
    ◊li{◊out-link["https://docs.docker.com/desktop/install/mac-install/"]{macOS instructions}}
    ◊li{◊out-link["https://docs.docker.com/desktop/install/windows-install/"]{Windows instructions}}
}

Next, download the container image (about 370 MB).

◊highlight['console]{
    $ docker pull ghcr.io/udem-lbit/superrec-tutorial:latest
}

Finally, run the following command from a terminal to start the container.
Replace ◊tt{<DATA_PATH>} with the path to a folder on your machine where you want to store the results of the tutorial
(e.g., ◊tt{/home/user/superrec-data} or ◊tt{C:\superrec-data}).

◊highlight['console]{
    $ docker run -it --name reconciliation \
        --mount=type=bind,src=<DATA_PATH>,dst=/home/tts/data \
        ghcr.io/udem-lbit/superrec-tutorial
}

If at any point you leave the container (e.g., by closing the terminal), you can get back in with the following command.

◊highlight['console]{
    $ docker start -i reconciliation
}

If you prefer not to use Docker, you can also manually install the required tools:
◊out-link["https://www.postgresql.org/"]{PostgreSQL 15},
◊out-link["https://www.python.org/"]{Python 3.11},
◊out-link["https://drive5.com/muscle5/"]{MUSCLE 5.1.0},
◊out-link["https://github.com/amkozlov/raxml-ng"]{RAxML-NG 1.2.0},
◊out-link["https://github.com/celinescornavacca/ecceTERA"]{ecceTERA c600321a},
◊out-link["https://www.ncbi.nlm.nih.gov/datasets/docs/v2/download-and-install/"]{NCBI Datasets 15.7.0},
and ◊out-link["https://github.com/UdeM-LBIT/superrec2"]{superrec2 0.1.0}.

◊;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

◊link-h2["crisprcasdb"]{Using Data From CRISPRCasDb}

◊out-link["https://crisprcas.i2bc.paris-saclay.fr/"]{CRISPRCasDb} is a publically-available database of CRISPR loci detected in over 36,000 bacterial and archaeal genomes.
This database was constructed by the ◊out-link["https://www.i2bc.paris-saclay.fr/"]{I2BC} institute using CRISPRCasFinder
(◊out-link["https://doi.org/10.1093/nar/gky425"]{Couvin et al., Nucleic Acids Research, 2018}).

◊link-h3["crisprcasdb-get"]{Retrieving a copy of the dataset}

If you are following along using Docker, the container already includes a copy of the database dump as a file named ◊tt{ccpp_db.zip}.
Otherwise, you can download a copy ◊out-link["https://crisprcas.i2bc.paris-saclay.fr/Home/DownloadFile?filename=ccpp_db.zip"]{from the CRISPRCasDb website}.

Let’s start by loading the database dump into PostgreSQL.

◊highlight['console]{
    $ createdb tts
    $ unzip -d ccpp_db ccpp_db.zip
    $ psql --file ccpp_db/*/*/*.sql 2>/dev/null
}

◊link-h3["crisprcasdb-structure"]{Understanding the dataset structure}

There are five main tables in the database which will be of interest to us today.

◊dl{
    ◊dt{◊tt{taxon}}
    ◊dd{◊em{A taxonomic entity (species, strain, …).}◊br[]
        ◊tt{.parent} references the parent taxon.}

    ◊dt{◊tt{strain}}
    ◊dd{◊em{A strain of a taxon.}◊br[]
        ◊tt{.taxon} references the associated taxon.◊br[]
        ◊tt{.genbank} holds a GenBank ID for the strain genome assembly.}

    ◊dt{◊tt{sequence}}
    ◊dd{◊em{A sequence in a genome assembly.}◊br[]
        ◊tt{.strain} references the sequenced strain.}

    ◊dt{◊tt{clustercas}}
    ◊dd{◊em{A cluster of Cas genes.}◊br[]
        ◊tt{.sequence} references the sequence containing this cluster.◊br[]
        ◊tt{.start} and ◊tt{.length} are the cluster extents in the sequence.}

    ◊dt{◊tt{clustercas_gene}}
    ◊dd{◊em{A Cas gene in a cluster.}◊br[]
        ◊tt{.clustercas} references the containing cluster.◊br[]
        ◊tt{.gene} is the gene family name.◊br[]
        ◊tt{.start} and ◊tt{.length} are the gene extents in the sequence.◊br[]
        ◊tt{.orientation} is 2 if the gene is backwards in the sequence, 1 otherwise.}
}

To get more details on the tables’s structure, you can start a PostgreSQL session and use the ◊tt{\d} and ◊tt{\d <TABLE>} commands.

◊highlight['postgresql-console]{
    $ psql
    psql (15.3)
    Type "help" for help.

    tts=# \d taxon
}

◊link-h3["crisprcasdb-queries"]{Running basic queries on the dataset}

Here are a few questions and corresponding SQL queries to get more familiar with the dataset.
You can execute them in your PostgreSQL session, as before.

◊em{Count the total number of Cas genes in the dataset.}

◊highlight['sql]{
    select count(*) from clustercas_gene;
}

◊em{Count the number of Cas genes for each Cas family in the dataset.}

◊highlight['sql]{
    select
        regexp_substr(gene, '^[^_]+') as family,
        count(*) as occurrences
    from clustercas_gene
    group by family
    order by count(*) desc;
}

◊em{Count the total number of Cas clusters in the dataset.}

◊highlight['sql]{
    select count(*) from clustercas;
}

◊em{List the gene contents of a specific Cas cluster.}

◊highlight['sql]{
    select
        regexp_substr(gene, '^[^_]+') as family,
        start,
        length,
        orientation
    from clustercas_gene
    where clustercas = '8aed4995-e0c3-41e5-839b-bce8997c6752'
    order by start;
}

Notice how this cluster contains multiple copies of the Cas3, 4, 5 and 7 genes.

◊em{For each Cas gene family, compute the proportion of clusters containing at least one gene from that family.}

◊highlight['sql]{
    select
        regexp_substr(gene, '^[^_]+') as family,
        count(distinct clustercas)::decimal
        / (select count(*) from clustercas) * 100
        as clusters_percent
    from clustercas_gene
    group by family
    order by clusters_percent desc;
}

Now that we are more familiar with the dataset, let’s start extracting the data we need.

◊link-h3["crisprcasdb-speciestree"]{Extracting the taxa tree}

To run a reconciliation, we will need a tree of the taxa inside which the genes evolve.
The dataset contains a subset of the NCBI taxonomy, which we will extract and use.
Doing this using SQL only is a bit awkward, so we will use Python instead.

◊highlight['console]{
    $ python build_taxa_tree.py > data/taxa.nh
}

◊link-h3["crisprcasdb-sample"]{Selecting a subset of taxa and clusters to study}

The dataset is too large to be analyzed entirely within the timeframe of this tutorial.
Hence, we will only consider Cas clusters from a sample of the available taxa.

We first subsample the taxa set by removing parts of the tree until we get a fully binary tree.
Such a binary tree is required for running the reconciliation step.
Then, we take a random sample of 40 taxa among the remaining ones.

◊highlight['console]{
    $ python prune_taxa_tree.py 40 < data/taxa.nh > data/pruned_taxa.nh
}

The script also creates views named ◊tt{*_sample} in the database, which mirror the tables of interest with only the sampled records.
You can upload the resulting ◊tt{pruned_taxa.nh} tree to the ◊out-link["http://etetoolkit.org/treeview/"]{Ete tree viewer} to visualize its structure.

◊;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

◊link-h2["genetrees"]{Building Gene Trees}

Our next step on the way to running the reconciliation tools is to build gene trees for the selected gene families.
We’ll use the usual multiple alignment and maximum likelihood approaches.

◊link-h3["genetrees-genomes"]{Retrieving Genome Assemblies}

Since CRISPRCasDb does not include the actual DNA sequences, we’ll have to start by retrieving them from NCBI’s servers.
We start by listing all the assembly IDs to be retrieved.

◊highlight['console]{
    $ psql --command 'select genbank from strain_sample;' \
        --no-align --tuples-only \
        > data/assembly_ids.txt
}

The retrieval of sequence data is done in two parts.
The first step is to prepare a folder structure in which the sequences will be stored.

◊highlight['console]{
    $ datasets download genome accession \
        --inputfile data/assembly_ids.txt \
        --filename data/ncbi_dataset.zip \
        --include genome \
        --dehydrated
    $ unzip -d data data/ncbi_dataset.zip
    $ rm data/ncbi_dataset.zip data/README.md
}

Then, we run a second command to populate this structure.
If this command fails or is interrupted, you can simply start it again to fetch the missing sequences.

◊highlight['console]{
    $ datasets rehydrate --directory data
}

The downloaded sequences can be found in the ◊tt{data/ncbi_dataset/data} subfolders.

◊link-h3["genetrees-genes"]{Extracting Gene Sequences}

Since we are only interested in the genes, not complete genome sequences, we need to extract those specifically.
The following script uses information from the database and the downloaded sequences to compile one multi-FASTA file for each gene family.

◊highlight['console]{
    $ python collect_cas_genes.py
}

The resulting files are stored in ◊tt{data/align}.

◊link-h3["genetrees-alignment"]{Aligning the Sequences}

Next, we proceed to performing multiple sequence alignment on Cas1 and Cas2 genes,
using MUSCLE (◊out-link["https://doi.org/10.1101/2021.06.20.449169"]{Edgar, 2022}).

◊highlight['console]{
    $ muscle -align data/align/Cas1.fna -output data/align/Cas1.afa
    $ muscle -align data/align/Cas2.fna -output data/align/Cas2.afa
}

◊link-h3["genetrees-ml"]{Searching for Maximum-Likelihood Trees}

Finally, we use RAxML-NG (◊out-link["https://doi.org/10.1093/bioinformatics/btz305"]{Kozlov et al., 2019}) to look for the best maximum-likelihood trees for the multiple alignment results.
Here the GTR+G evolution model is used, which is suited for nucleotidic data.
For more advanced uses of RAxML-NG, you can refer to ◊out-link["https://github.com/amkozlov/raxml-ng/wiki/Tutorial"]{this tutorial}.

◊highlight['console]{
    $ raxml-ng --model GTR+G --msa data/align/Cas1.afa --seed 42 --search
    $ raxml-ng --model GTR+G --msa data/align/Cas2.afa --seed 42 --search
}

The resulting trees are stored in ◊tt{data/align/Cas1.afa.raxml.bestTree} and ◊tt{data/align/Cas2.afa.raxml.bestTree}.
Upload them to the ◊out-link["http://etetoolkit.org/treeview/"]{Ete tree viewer} to visualize their structure, and compare them to the species tree obtained above.

◊;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

◊link-h2["rec"]{Computing Reconciliations on Individual Gene Trees}

To obtain an scenario explaining the discrepancies between the gene trees and the species tree, we can compute a most-parsimonious classical reconciliation.
Many reconciliation tools exist which implement various reconciliation models:
◊out-link["https://www.cs.hmc.edu/~hadas/jane/"]{Jane},
◊out-link["https://project.inria.fr/treerecs/"]{TreeRecs},
◊out-link["https://compbio.mit.edu/ranger-dtl/"]{RANGER-DTL},
◊out-link["https://www.cs.cmu.edu/~durand/Notung/"]{Notung},
among others.

◊link-h3["rec-run"]{Running ecceTERA}

Here, we chose to use ecceTERA (◊out-link["https://doi.org/10.1093/bioinformatics/btw105"]{Jacox et al., 2016}).

◊highlight['console]{
    $ ecceTERA species.file=data/pruned_taxa.nh \
        gene.file=data/align/Cas1.afa.raxml.bestTree \
        dated=0 \
        print.reconciliations=1 \
        recPhyloXML.reconciliation=true \
        output.dir=data \
        output.prefix=Cas1_
    $ ecceTERA species.file=data/pruned_taxa.nh \
        gene.file=data/align/Cas2.afa.raxml.bestTree \
        dated=0 \
        print.reconciliations=1 \
        recPhyloXML.reconciliation=true \
        output.dir=data \
        output.prefix=Cas2_
}

The results are stored as ◊out-link["https://github.com/WandrilleD/recPhyloXML"]{recPhyloXML} files inside the ◊tt{data} folder
(recPhyloXML is a standard interchange format for phylogenetic reconciliations, see ◊out-link["https://doi.org/10.1093/bioinformatics/bty389"]{Duchemin, 2018}).
You can use ◊out-link["http://thirdkind.univ-lyon1.fr/"]{ThirdKind} to visualize them.

When there are multiple optimal reconciliations, ecceTERA outputs three different solutions: a randomly selected one, and two median reconciliations representative of the space of all possible solutions.

◊link-h3["rec-costs"]{Tweaking the costs}

By default, ecceTERA assigns a cost of 1 to losses, 2 to duplications, and 3 to HGTs.
To redefine those costs, you can use the ◊tt{loss.cost}, ◊tt{dupli.cost} and ◊tt{HGT.cost} arguments.
Try assigning a very high cost to HGTs (so that they are effectively forbidden).
What do you notice?

◊;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

◊link-h2["superrec"]{Computing Super-Reconciliations}

Finally, we are interested in computing a cluster-level scenario with segmental events.
To that end, we will use superrec2 (◊out-link["https://doi.org/10.1007/978-3-031-06220-9_8"]{Anselmetti et al., 2022}).

◊link-h3["superrec-supertree"]{Building a supertree}

The trees ◊in-link["#genetrees-ml"]{obtained above} for Cas1 and Cas2 overlap on some of their nodes.
These are the nodes corresponding to clusters with both a Cas1 and a Cas2 copy.
To run the super-reconciliation, we need a supertree that encompasses the topology of both of these trees.
Unfortunately, the trees are not consistent (their topologies contradict in some places).

Here, we will use an heuristic approach: we remove random disagreeing triplets until the two trees become consistent.
We repeat this a few times and keep the most resolved solution, i.e., the run where we had to remove the least number of triplets.

◊highlight['console]{
    $ python build_super_input.py > data/super_input.json
}

◊link-h3["superrec-run"]{Running superrec2}

◊highlight['console]{
    $ superrec2 reconcile \
        --input data/super_input.json \
        superdtl > data/super_output.json
}

To view the results, you can use the following command.
This requires a working LaTeX installation, which is unfortunately not included in the Docker container due to space constraints.

◊highlight['console]{
    $ superrec2 draw \
        --input data/super_output.json \
        --output data/super_output.pdf
}
