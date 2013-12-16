#!/usr/bin/env python
# meshconcepts2json.py
"""
load all concept of the ontology and create a file : concepts.json with conceptIds and conceptNames

usage:
    python meshconcepts2json.py path/to/mesh-ontology.xml
    python meshconcepts2json.py path/to/mesh-ontology.xml path/to/mesh_concept.ttl
"""

from lxml import objectify, etree
import sys
import json


if len(sys.argv) > 2:
    outname = sys.argv[2]
else:
    outname = "out"

mesh_ontology = sys.argv[1]

# open("%s.json" % outname, "w").write("");
open("%s.ttl" % outname, "w").write("");

# jsonout = open("%s.json" % outname, 'a')
ttlout = open("%s.ttl" % outname, 'a')

ttlout.write('<http://kalitmo.org/type/MeshConcept> <http://purl.org/dc/elements/1.1/title> \"mesh concept\" .\n')

root = objectify.fromstring(open(mesh_ontology).read())

for node in root.iterchildren():
    id = node.xpath("DescriptorUI")[0].text
    title = node.xpath("DescriptorName/String")[0].text
    splited_title = title.replace(',', ' ').replace('-', ' ').replace('/', ' ').replace(':', ' ').replace('_', ' ').split()
    classified_title = "".join(i.capitalize() for i in splited_title)
    aliases = list(set([title] + [i.text for i in node.xpath("ConceptList/Concept/TermList/Term/String")]))
    # jsonout.write(json.dumps({"_id": id, "title": title, "aliases": aliases, "_search": [i.lower() for i in aliases]})+"\n")
    results = [
        '<http://kalitmo.org/mesh_concept/%s> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://kalitmo.org/type/MeshConcept> .' % classified_title,
        '<http://kalitmo.org/mesh_concept/%s> <http://kalitmo.org/property/id>  "%s" .' % (classified_title, id),
        '<http://kalitmo.org/mesh_concept/%s>  <http://purl.org/dc/elements/1.1/title>  "%s" .' % (classified_title, title),
        '<http://kalitmo.org/mesh_concept/%s>  <http://purl.org/dc/elements/1.1/alias>  "%s" .' % (classified_title, title)
    ]
    for alias in aliases:
        if isinstance(alias, unicode):
            alias = alias.encode('utf-8')
        results.append('<http://kalitmo.org/mesh_concept/%s>  <http://kalitmo.org/property/alias>  "%s" .' % (classified_title, alias))
    ttlout.write("\n".join(results)+'\n')

# jsonout.close()
ttlout.close()