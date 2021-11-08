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
from jinja2 import Environment, BaseLoader
import json
import pprint
from collections import defaultdict
import re

def generatehtmlpages():
    boostlibrarycategories = defaultdict(dict)
    boostlibrarycategories["Algorithms"]["title"] = "Algorithms"
    boostlibrarycategories["Workarounds"]["title"] = "Broken compiler workarounds"
    boostlibrarycategories["Concurrent"]["title"] = "Concurrent Programming"
    boostlibrarycategories["Containers"]["title"] = "Containers"
    boostlibrarycategories["Correctness"]["title"] = "Correctness and testing"
    boostlibrarycategories["Data"]["title"] = "Data structures"
    boostlibrarycategories["Domain"]["title"] = "Domain Specific"
    boostlibrarycategories["Error-handling"]["title"] = "Error handling and recovery"
    boostlibrarycategories["Function-objects"]["title"] = "Function objects and higher-order programming"
    boostlibrarycategories["Generic"]["title"] = "Generic Programming"
    boostlibrarycategories["Image-processing"]["title"] = "Image processing"
    boostlibrarycategories["IO"]["title"] = "Input/Output"
    boostlibrarycategories["Inter-language"]["title"] = "Inter-language support"
    boostlibrarycategories["Iterators"]["title"] = "Iterators"
    boostlibrarycategories["Emulation"]["title"] = "Language Features Emulation"
    boostlibrarycategories["Math"]["title"] = "Math and numerics"
    boostlibrarycategories["Memory"]["title"] = "Memory"
    boostlibrarycategories["Parsing"]["title"] = "Parsing"
    boostlibrarycategories["Patterns"]["title"] = "Patterns and Idioms"
    boostlibrarycategories["Preprocessor"]["title"] = "Preprocessor Metaprogramming"
    boostlibrarycategories["Programming"]["title"] = "Programming Interfaces"
    boostlibrarycategories["State"]["title"] = "State Machines"
    boostlibrarycategories["String"]["title"] = "String and text processing"
    boostlibrarycategories["System"]["title"] = "System"
    boostlibrarycategories["Metaprogramming"]["title"] = "Template Metaprogramming"
    boostlibrarycategories["Miscellaneous"]["title"] = "Miscellaneous"
    
    for category in boostlibrarycategories:
        boostlibrarycategories[category]["libraries"]=[]
    
    boostlibrariestoskip=["libs/detail","libs/numeric","libs/winapi"]
    boostlibrariestoadd=["libs/numeric/conversion", "libs/numeric/interval", "libs/numeric/odeint", "libs/numeric/ublas","libs/spirit/classic","libs/spirit/repository"]

    def names_to_string(names):
        if isinstance(names, list):
            last_name = names.pop()
            if len(names) > 0:
                return ", ".join(names) + " and " + last_name
            else:
                return last_name
        else:
            return names

    # Discover boost version
    with open('Jamroot', 'r',  encoding="utf-8") as file:
        file_contents = file.read()
        m = re.search("constant BOOST_VERSION : (.*) ;",file_contents)
        source_version = m.group(1)
        source_version_underscores=source_version.replace(".","_")
    release_notes_url="https://www.boost.org/users/history/version_" + source_version_underscores + ".html"
    # Ingest all boost library metadata:
    allmetadata={}
    all_libraries=[]
    all_libraries.extend(boostlibrariestoadd)

    for directoryname in glob.iglob('libs/*', recursive=False):
        if os.path.isdir(directoryname) and (directoryname not in boostlibrariestoskip) and os.path.isfile(directoryname + "/meta/libraries.json"): # filter dirs
            all_libraries.append(directoryname)

    for directoryname in all_libraries:
        librarypath=re.sub(r'^libs/','',directoryname)
        with open(directoryname + "/meta/libraries.json", 'r',  encoding="utf-8") as file:
            file_contents = file.read()
            data = json.loads(file_contents)
            if type(data) is dict:
                key=data["key"]
                allmetadata[key]=data
                allmetadata[key]["librarypath"]=librarypath
            if type(data) is list:
                for item in data:
                    key=item["key"]
                    allmetadata[key]=item
                    allmetadata[key]["librarypath"]=librarypath
    #pprint.pprint(allmetadata)
    #quit()

    for key, value in allmetadata.items():
        # fix documentation
        # if not "documentation" in value:
        #     allmetadata[key]["documentation"]=value["librarypath"] + "/index.html"
        if not "documentation" in value:
            allmetadata[key]["documentation_modified"]=value["librarypath"] + "/index.html"
        else:
            allmetadata[key]["documentation_modified"]=value["librarypath"] + "/" + allmetadata[key]["documentation"]
            if re.search('/$',allmetadata[key]["documentation_modified"]):
                allmetadata[key]["documentation_modified"]=allmetadata[key]["documentation_modified"] + 'index.html'
        # modify description
        allmetadata[key]["description_modified"]=re.sub(r'\s*\.\s*$','', allmetadata[key]["description"])
        # modify authors
        allmetadata[key]["authors_modified"]=names_to_string(allmetadata[key]["authors"])

    # Specific fixes which should be propagated upstream
    allmetadata['histogram']['name']="Histogram"            # sent pr # done.
    allmetadata['parameter_python']['name']="Parameter Python Bindings"     # sent pr
    allmetadata['process']['name']="Process"                # sent pr
    allmetadata['stl_interfaces']['name']="Stl_interfaces"  # sent pr
    allmetadata['utility/string_ref']['name']="String_ref"  # sent pr
    allmetadata['compatibility']['category']=["Workarounds"] # sent pr
    allmetadata['config']['category']=["Workarounds"]       # sent pr  # done
    # allmetadata['leaf']['category']=["Miscellaneous"]       # sent pr  # done. obsolete.
    allmetadata['logic/tribool']['documentation_modified']="../doc/html/tribool.html"

    # determine libraries per category
    for category in boostlibrarycategories:
        for library in allmetadata:
            if category in allmetadata[library]["category"]:
                boostlibrarycategories[category]["libraries"].append(library)
            # sort
            boostlibrarycategories[category]["libraries"].sort(key=lambda x: allmetadata[x]["name"].lower())

    # sort allmetadata
    sorted_tuples =sorted(allmetadata.items(), key=lambda x : x[1]['name'].lower())
    allmetadata = {k: v for k, v in sorted_tuples}

    # |sort(attribute="1.name",case_sensitive=False)

    # pprint.pprint(boostlibrarycategories)
    # quit()

    for sourcefile in ["index.html", "libs/libraries.htm"]:
        with open(sourcefile, 'r',  encoding="utf-8") as file:
            file_contents = file.read()
        if sourcefile == "libs/libraries.htm":
            file_contents = file_contents.replace('charset=iso-8859-1','charset=utf-8' ) 
            file_contents = file_contents.replace('{{#categorized}}\n','{% for key, value in boostlibrarycategories.items() %}{% set category = key %}{% set name = key %}{% set title = value["title"] %}' ) 
            # file_contents = file_contents.replace('{{#categorized}}\n','{% for key, value in boostlibrarycategories.items() %}{% set category = key %}{% set name = key %}' ) 
            file_contents = file_contents.replace('{{/categorized}}\n','{% endfor %}')
            file_contents = file_contents.replace('{{#alphabetic}}\n','{% for key, value in allmetadata.items() %}{% set name = value["name"] %}{% set authors = value["authors_modified"] %}{% set link = value["documentation_modified"] %}{% set description = value["description_modified"] %}')
            file_contents = file_contents.replace('{{/alphabetic}}\n','{% endfor %}')
            file_contents = file_contents.replace('{{#libraries}}\n','{% for library in boostlibrarycategories[category]["libraries"] %}{% set name = allmetadata[library]["name"] %}{% set authors = allmetadata[library]["authors_modified"] %}{% set link = allmetadata[library]["documentation_modified"] %}{% set description = allmetadata[library]["description_modified"] %}')
            file_contents = file_contents.replace('{{/libraries}}\n','{% endfor %}')
            file_contents = file_contents.replace('{{#authors}}','')
            file_contents = file_contents.replace('{{/authors}}','')
            string="""{{! This is a template for the library list. See the generated file at:
    http://www.boost.org/doc/libs/develop/libs/libraries.htm
}}
"""
            file_contents = file_contents.replace(string,'')
        elif sourcefile == "index.html":
            string="""      {{#is_develop}}Development Snapshot{{/is_develop}}
"""
            file_contents = file_contents.replace(string,'')
            string="""
  {{#unreleased_lib_count}}
  <p>
  {{#is_develop}}This development snapshot{{/is_develop}}
  {{^is_develop}}Boost {{minor_release}}{{/is_develop}}
  includes {{unreleased_lib_count}} new
  {{#unreleased_library_plural}}libraries{{/unreleased_library_plural}}
  {{^unreleased_library_plural}}library{{/unreleased_library_plural}}
  ({{#unreleased_libs}}{{#index}}, {{/index}}<a href="{{link}}">{{name}}</a>{{/unreleased_libs}})
  as well as updates to many existing libraries.
  {{/unreleased_lib_count}}
  {{^unreleased_lib_count}}"""
            file_contents = file_contents.replace(string,'')
            string="""  {{/unreleased_lib_count}}
"""
            file_contents = file_contents.replace(string,'')
            file_contents = file_contents.replace('{{^is_develop}}','')
            file_contents = file_contents.replace('{{/is_develop}}','')
        # print(file_contents)
        # quit()
        rtemplate = Environment(loader=BaseLoader, autoescape=True).from_string(file_contents)
        data = rtemplate.render(release_notes_url=release_notes_url,version=source_version,allmetadata=allmetadata,boostlibrarycategories=boostlibrarycategories)

        # Post processing
        data = data.replace('Determines the type of a function call expression, from ','Determines the type of a function call expression')
        data = data.replace('idiosyncrasies; not intended for library users, from ','idiosyncrasies; not intended for library users')
        data = data.replace('makes the standard integer types safely available in namespace boost without placing any names in namespace std, from ','makes the standard integer types safely available in namespace boost without placing any names in namespace std')
        # print(data)
        with open(sourcefile, 'w',  encoding="utf-8") as f:
            print(data,file=f)

if __name__ == "__main__":
    generatehtmlpages()

