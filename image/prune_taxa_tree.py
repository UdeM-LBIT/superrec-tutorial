from ete3 import Tree
from random import Random
import sys
import psycopg


def prune_tree(tree):
    # At multifurcations, keep the 2 most heavy nodes
    for node in tree.traverse("postorder"):
        if len(node.children) >= 3:
            weighted = sorted(
                node.children,
                key=lambda node: (-len(node), node.name),
            )

            for child in weighted[2:]:
                child.detach()

    return tree


def sample_tree(tree, k):
    random = Random(42)
    selected = random.sample(list(tree), k=k)
    tree.prune(selected)
    return tree


def save_taxon_sample(db_address, taxons):
    with psycopg.connect(db_address) as conn:
        conn.execute(
            f"""
            drop view if exists
                taxon_sample,
                strain_sample,
                sequence_sample,
                clustercas_sample,
                clustercas_gene_sample;

            create view taxon_sample as
                select * from taxon
                where id in {tuple(taxons)};

            create view strain_sample as
                select distinct on(taxon) *
                from strain
                where taxon in (select id from taxon_sample)
                order by taxon asc, genbank desc;

            create view sequence_sample as
                select *
                from sequence
                where strain in (select id from strain_sample);

            create view clustercas_sample as
                select *
                from clustercas
                where sequence in (select id from sequence_sample);

            create view clustercas_gene_sample as
                select *
                from clustercas_gene
                where clustercas in (select id from clustercas_sample);
            """,
        )
        conn.commit()


def main():
    db_address = "dbname=tts"
    tree = Tree(sys.stdin.read(), format=8)
    tree = prune_tree(tree)
    tree = sample_tree(tree, int(sys.argv[1]))
    save_taxon_sample(db_address, [int(node.id) for node in tree])
    print(tree.write(format=8, format_root_node=True))


if __name__ == "__main__":
    sys.exit(main())
