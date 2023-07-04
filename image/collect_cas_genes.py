import psycopg
from psycopg.rows import class_row
from Bio import SeqIO
from Bio.SeqRecord import SeqRecord
import sys
import os
import re
from dataclasses import dataclass


@dataclass
class Gene:
    name: str
    start: int
    length: int
    orientation: int
    cluster_id: str
    cluster_start: int
    cluster_length: int
    assembly_id: str
    sequence_desc: str
    sequence_length: int
    taxon_name: str

    @property
    def family(self) -> str:
        return self.name.split('_')[0]


def fetch_genes_infos():
    with psycopg.connect("dbname=tts", row_factory=class_row(Gene)) as conn:
        yield from conn.execute(
            """
            select clustercas_gene.gene as name,
                clustercas_gene.start,
                clustercas_gene.length,
                clustercas_gene.orientation,
                clustercas.id as cluster_id,
                clustercas.start as cluster_start,
                clustercas.length as cluster_length,
                strain.genbank as assembly_id,
                sequence.description as sequence_desc,
                sequence.length as sequence_length,
                taxon.scientificname as taxon_name
            from clustercas_gene_sample as clustercas_gene
                join clustercas_sample as clustercas
                    on clustercas_gene.clustercas = clustercas.id
                join sequence_sample as sequence
                    on clustercas.sequence = sequence.id
                join strain_sample as strain
                    on sequence.strain = strain.id
                join taxon_sample as taxon
                    on strain.taxon = taxon.id
            order by genbank, gene;
            """
        )


def fetch_assembly_data(genbank_id):
    directory = f'data/ncbi_dataset/data/{genbank_id}'
    files = os.listdir(directory)
    assert len(files) == 1
    return SeqIO.to_dict(
        SeqIO.parse(f'{directory}/{files[0]}', format="fasta"),
        key_function=lambda record: len(record)
    )


def extract_gene_sequences(genes_iter):
    cur_assembly_id = None
    cur_assembly = None

    for gene in genes_iter:
        if cur_assembly_id != gene.assembly_id:
            cur_assembly_id = gene.assembly_id
            cur_assembly = fetch_assembly_data(gene.assembly_id)

        parent_sequence = cur_assembly[gene.sequence_length].seq
        start = gene.start
        end = gene.start + gene.length
        sequence = parent_sequence[start:end]

        if gene.orientation == 2:
            sequence = sequence.reverse_complement()

        yield gene, sequence


def quote_string(data: str) -> str:
    for char in " _[](),:;='\t\n":
        data = data.replace(char, "-")

    data = re.sub("-{2,}", "-", data)
    return data


def output_sequences():
    files = {}

    for gene, sequence in extract_gene_sequences(fetch_genes_infos()):
        if gene.family not in files:
            files[gene.family] = open(f"data/align/{gene.family}.fna", "w")

        files[gene.family].write(
            SeqRecord(
                id=f'{quote_string(gene.taxon_name)}___{gene.cluster_id}___{gene.name}',
                seq=sequence,
                description='',
            ).format("fasta") + "\n"
        )

    for file in files.values():
        file.close()


if __name__ == "__main__":
    os.makedirs("data/align", exist_ok=True)
    sys.exit(output_sequences())
