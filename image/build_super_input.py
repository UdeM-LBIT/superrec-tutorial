import psycopg
from ete3 import Tree
from superrec2.utils.trees import tree_to_triples, tree_from_triples
from superrec2.utils.disjoint_set import DisjointSet
from random import Random
import sys
import json


def read_tree(tree):
    object_tree = tree.copy()
    leaf_object_species = {}

    for node in object_tree:
        taxon, cluster, _ = node.name.split("___")
        node.name = cluster
        leaf_object_species[cluster] = taxon

    return object_tree, leaf_object_species


def merge(l1, l2):
    return l1 + [item for item in l2 if item not in l1]


def tree_from_triples(leaves, triples):
    if not leaves:
        return (False, -1)

    if len(leaves) == 1:
        return (True, Tree(name=leaves[0]))

    if len(leaves) == 2:
        root = Tree()
        root.add_child(Tree(name=leaves[0]))
        root.add_child(Tree(name=leaves[1]))
        return (True, root)

    partition = DisjointSet(len(leaves))
    leaf_index = {leaf: i for i, leaf in enumerate(leaves)}

    for index, (left, right, _) in enumerate(triples):
        partition.unite(leaf_index[left], leaf_index[right])

        if len(partition) <= 1:
            return (False, index)

    if len(partition) <= 1:
        return (False, len(triples))

    root = Tree()

    for group in partition.to_list():
        group_leaves = [leaves[item] for item in group]
        group_triples = [
            triple for triple in triples if all(leaf in group_leaves for leaf in triple)
        ]

        subtree = tree_from_triples(group_leaves, group_triples)

        if not subtree[0]:
            return subtree

        root.add_child(subtree[1])

    return (True, root)


def greedy_consensus(random, tree1, tree2):
    leaves1, triples1 = tree_to_triples(tree1)
    leaves2, triples2 = tree_to_triples(tree2)

    clusters = merge(leaves1, leaves2)
    triples = merge(triples1, triples2)

    random.shuffle(triples)
    removed = 0

    while not (result := tree_from_triples(clusters, triples))[0]:
        removed += 1
        del triples[result[1]]

    return removed, result[1]


def shuffle_consensus(tree1, tree2):
    random = Random(42)
    best_removed = float("inf")
    best_tree = None

    for _ in range(1_000):
        removed, result = greedy_consensus(random, tree1, tree2)

        if removed < best_removed:
            best_removed = removed
            best_tree = result

    return best_tree


def fetch_clusters(clusters):
    with psycopg.connect("dbname=tts") as conn:
        yield from conn.execute(
            f"""
            select
                clustercas,
                regexp_substr(gene, '^[^_]+') as family
            from clustercas_gene
            where clustercas in {tuple(clusters)}
            order by clustercas, start;
            """
        )


def main():
    taxon_tree = Tree(open("data/pruned_taxa.nh").read(), format=8)
    cas1_tree = Tree(open("data/align/Cas1.afa.raxml.bestTree").read())
    cas2_tree = Tree(open("data/align/Cas2.afa.raxml.bestTree").read())

    cas1_object_tree, cas1_object_species = read_tree(cas1_tree)
    cas2_object_tree, cas2_object_species = read_tree(cas2_tree)

    with open("data/Cas1-clusters.nh", "w") as file:
        file.write(cas1_object_tree.write(format=8))

    with open("data/Cas2-clusters.nh", "w") as file:
        file.write(cas2_object_tree.write(format=8))

    object_tree = shuffle_consensus(cas1_object_tree, cas2_object_tree)
    leaf_syntenies = {}

    for cluster, family in fetch_clusters([node.name for node in object_tree]):
        if family.startswith("Cas"):
            leaf_syntenies.setdefault(str(cluster), []).append(family)

    for cluster, synteny in leaf_syntenies.items():
        leaf_syntenies[cluster] = sorted(set(leaf_syntenies[cluster]))

    leaf_object_species = {**cas1_object_species, **cas2_object_species}
    print(json.dumps({
        "object_tree": object_tree.write(format=8),
        "species_tree": taxon_tree.write(format=8),
        "leaf_object_species": leaf_object_species,
        "leaf_syntenies": leaf_syntenies,
    }))


if __name__ == "__main__":
    sys.exit(main())
