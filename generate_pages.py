#!/usr/bin/python3

'''
Versions of ci_boost_release.py from 2016-2021 were calling http://www.boost.org/doc/generate.php
to download and update index.html and libs/libraries.htm in the archive bundles.

generate.php (PHP5) will eventually be deprecated and removed.

It's convenient to have a self-sufficient release-tool, not depending on the website, at least during a transition period while the website is in flux.

generate_pages.py creates the files in question: index.html and libs/libraries.htm.
'''

import sys
import os
import glob
import jinja2
import json
import pprint
from collections import defaultdict

boostlibrarycategories = defaultdict(dict)
boostlibrarycategories["Algorithms"]["title"] = "Algorithms"
boostlibrarycategories["Concurrent"]["title"] = "Concurrent Programming"
boostlibrarycategories["Containers"]["title"] = "Containers"
boostlibrarycategories["Correctness"]["title"] = "Correctness and testing"
boostlibrarycategories["Data"]["title"] = "Data structures"
boostlibrarycategories["Domain"]["title"] = "Domain Specific"
boostlibrarycategories["Emulation"]["title"] = "Language Features Emulation"
boostlibrarycategories["Function-objects"]["title"] = "Function objects and higher-order programming"
boostlibrarycategories["Generic"]["title"] = "Generic Programming"
boostlibrarycategories["Image-processing"]["title"] = "Image processing"
boostlibrarycategories["IO"]["title"] = "Input/Output"
boostlibrarycategories["Inter-language"]["title"] = "Inter-language support"
boostlibrarycategories["Iterators"]["title"] = "Iterators"
boostlibrarycategories["Math"]["title"] = "Math and numerics"
boostlibrarycategories["Memory"]["title"] = "Memory"
boostlibrarycategories["Metaprogramming"]["title"] = "Template Metaprogramming"
boostlibrarycategories["Miscellaneous"]["title"] = "Miscellaneous"
boostlibrarycategories["Parsing"]["title"] = "Parsing"
boostlibrarycategories["Patterns"]["title"] = "Patterns and Idioms"
boostlibrarycategories["Preprocessor"]["title"] = "Preprocessor Metaprogramming"
boostlibrarycategories["Programming"]["title"] = "Programming Interfaces"
boostlibrarycategories["State"]["title"] = "State Machines"
boostlibrarycategories["String"]["title"] = "String and text processing"
boostlibrarycategories["System"]["title"] = "System"
boostlibrarycategories["Workarounds"]["title"] = "Broken compiler workarounds"

boostlibrariestoskip=["libs/headers","libs/numeric"]
boostlibrariestoadd=["libs/numeric/conversion","libs/numeric/interval","libs/numeric/odeint","libs/numeric/ublas"]

def generatehtmlpages():
    for sourcefile in ["index.html","libs/libraries.htm"]
    with open(sourcefile, 'r',  encoding="utf-8") as file:
        file_contents = file.read()

    # Ingest all boost library metadata:
    allmetadata={}
    all_libraries=[]
    all_libraries.extend(boostlibrariestoadd)

    for directoryname in glob.iglob('libs/*', recursive=False):
        if os.path.isdir(directoryname) and directoryname not in boostlibrariestoskip: # filter dirs
            all_libraries.append(directoryname)

    for directoryname in all_libraries:
        with open(directoryname + "/meta/libraries.json", 'r',  encoding="utf-8") as file:
            file_contents = file.read()
            data = json.loads(file_contents)
            if type(data) is dict:
                key=data["key"]
                allmetadata[key]=data
            if type(data) is list:
                for item in data:
                    key=item["key"]
                    allmetadata[key]=item
    pprint.pprint(allmetadata)

if __name__ == "__main__":
    generatehtmlpages()


