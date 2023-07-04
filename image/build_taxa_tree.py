import psycopg
from ete3 import TreeNode
import sys
import re


def fetch_taxa_infos(db_address):
    with psycopg.connect(db_address) as conn:
        yield from conn.execute("select taxon.id, taxon.scientificname, taxon.parent from taxon")


def quote_string(data: str) -> str:
    for char in " _[](),:;='\t\n":
        data = data.replace(char, "-")

    data = re.sub("-{2,}", "-", data)
    return data


def build_tree(taxa_iter):
    nodes = {}
    parents = {}
    root = None

    # Create a tree node for each taxon
    for taxon, name, parent in taxa_iter:
        node = TreeNode(name=quote_string(name))
        node.add_features(id=taxon)
        nodes[taxon] = node

        if parent is None:
            assert root is None
            root = node
        else:
            parents[taxon] = parent

    # Attach taxon nodes to their parent
    for child, parent in parents.items():
        nodes[parent].add_child(nodes[child])

    # Contract unary nodes
    for node in root.traverse("postorder"):
        if len(node.children) == 1:
            node.children[0].delete()

    return root


def main():
    db_address = "dbname=tts"
    taxa = fetch_taxa_infos(db_address)
    tree = build_tree(taxa)
    print(tree.write(format=8, features=["id"], format_root_node=True))


if __name__ == "__main__":
    sys.exit(main())
