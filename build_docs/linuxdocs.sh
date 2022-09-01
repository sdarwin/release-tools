#!/bin/bash

set -e

scriptname="linuxdocs.sh"

# READ IN COMMAND-LINE OPTIONS

TEMP=`getopt -o t:,h:: --long type:,help:: -- "$@"`
eval set -- "$TEMP"

# extract options and their arguments into variables.
while true ; do
    case "$1" in
        -h|--help)
            helpmessage="""
usage: $scriptname [-h] [--type TYPE] [path_to_library]

Builds library documentation.

optional arguments:
  -h, --help            Show this help message and exit
  --type TYPE           The \"type\" of build. Defaults to \"main\" which installs all standard boost prerequisites.
                        Another option is \"cppal\" which installs the prerequisites used by boostorg/json and a few other similar libraries.
                        More \"types\" can be added in the future if your library needs a specific set of packages installed.
                        The type is usually auto-detected and doesn't need to be specified.

standard arguments:
  path_to_library	Where the library is located. Defaults to current working directory.
"""

            echo ""
	    echo "$helpmessage" ;
	    echo ""
            exit 0
            ;;
        -t|--type)
            case "$2" in
                "") typeoption="" ; shift 2 ;;
                 *) typeoption=$2 ; shift 2 ;;
            esac ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done

if [ -n "$1" ]; then
    echo "Library path set to $1. Changing to that directory."
    cd $1
else
    workingdir=$(pwd)
    echo "Using current working directory ${workingdir}."
fi

# DETERMINE REPOSITORY

export REPONAME=$(basename -s .git `git config --get remote.origin.url` 2> /dev/null || echo "empty")
export BOOST_SRC_FOLDER=$(git rev-parse --show-toplevel 2> /dev/null || echo "nofolder")

if [ "${REPONAME}" = "empty" -o "${REPONAME}" = "release-tools" ]; then
    echo -e "\nSet the path_to_library as the first command-line argument:\n\n$scriptname _path_to_library_\n\nOr change the working directory to that first.\n"
    exit 1
else
    echo "Reponame is ${REPONAME}."
fi

# CHECK IF RUNNING IN BOOST-ROOT

PARENTNAME=$(basename -s .git `git --git-dir ${BOOST_SRC_FOLDER}/../../.git config --get remote.origin.url` 2> /dev/null || echo "not_found")
if [ -n "${PARENTNAME}" -a "${PARENTNAME}" = "boost" ]; then
    echo "Starting out inside boost-root."
    BOOSTROOTLIBRARY="yes"
else
    echo "Not starting out inside boost-root."
    BOOSTROOTLIBRARY="no"
fi

# DECIDE THE TYPE

alltypes="main cppal"
cppaltypes="json beast url http_proto socks_proto zlib"

if [ -z "$typeoption" ]; then
    if [[ " $cppaltypes " =~ .*\ $REPONAME\ .* ]]; then
        typeoption="cppal"
    else
        typeoption="main"
    fi
fi

echo "Build type is ${typeoption}."

if [[ !  " $alltypes " =~ .*\ $typeoption\ .* ]]; then
    echo "Allowed types are currently 'main' and 'cppal'. Not $typeoption. Please choose a different option. Exiting."
    exit 1
fi

if git rev-parse --abbrev-ref HEAD | grep master ; then BOOST_BRANCH=master ; else BOOST_BRANCH=develop ; fi

echo '==================================> INSTALL'

sudo apt-get update
sudo apt-get install -y docbook docbook-xml docbook-xsl xsltproc libsaxonhe-java default-jre-headless flex libfl-dev bison unzip rsync wget python3 cmake build-essential

if [ "$typeoption" = "main" ]; then
    sudo apt-get install -y python3-pip ruby docutils-doc docutils-common python3-docutils
    sudo gem install asciidoctor --version 1.5.8
    sudo pip3 install docutils
fi

cd $BOOST_SRC_FOLDER
cd ..
mkdir -p tmp && cd tmp

if which doxygen; then
    echo "doxygen found"
else
    echo "building doxygen"
    if [ ! -d doxygen ]; then git clone -b 'Release_1_8_15' --depth 1 https://github.com/doxygen/doxygen.git && echo "not-cached" ; else echo "cached" ; fi
    cd doxygen
    cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release
    cd build
    sudo make install
    cd ../..
fi

if [ ! -f saxonhe.zip ]; then wget -O saxonhe.zip https://sourceforge.net/projects/saxon/files/Saxon-HE/9.9/SaxonHE9-9-1-4J.zip/download && echo "not-cached" ; else echo "cached" ; fi
unzip -d saxonhe -o saxonhe.zip
cd saxonhe
sudo rm /usr/share/java/Saxon-HE.jar || true
sudo cp saxon9he.jar /usr/share/java/Saxon-HE.jar

cd $BOOST_SRC_FOLDER

if [ "${BOOSTROOTLIBRARY}" = "yes" ]; then
    cd ../..
    git checkout $BOOST_BRANCH
    git pull
    export BOOST_ROOT=$(pwd)
else
    cd ..
    if [ ! -d boost-root ]; then
        git clone -b $BOOST_BRANCH https://github.com/boostorg/boost.git boost-root --depth 1
        cd boost-root
        export BOOST_ROOT=$(pwd)
        rsync -av $BOOST_SRC_FOLDER/ libs/$REPONAME
    else
        cd boost-root
        git checkout $BOOST_BRANCH
        git pull
        export BOOST_ROOT=$(pwd)
        rsync -av $BOOST_SRC_FOLDER/ libs/$REPONAME
    fi
fi

git submodule update --init libs/context
git submodule update --init tools/boostbook
git submodule update --init tools/boostdep
git submodule update --init tools/docca
git submodule update --init tools/quickbook

if [ "$typeoption" = "main" ]; then
    git submodule update --init tools/auto_index
    git submodule update --quiet --init --recursive

    # recopy the library as it might have been overwritten
    rm -rf /tmp/$REPONAME
    cp -rp libs/$REPONAME /tmp/$REPONAME
    rsync -av --delete $BOOST_SRC_FOLDER/ libs/$REPONAME
    # diff -r libs/$REPONAME /tmp/$REPONAME
fi

python3 tools/boostdep/depinst/depinst.py ../tools/quickbook
./bootstrap.sh
./b2 headers

echo '==================================> COMPILE'

if [ "$typeoption" = "main" ]; then
    ./b2 -q -d0 --build-dir=build --distdir=build/dist tools/quickbook tools/auto_index/build
    echo "using quickbook : build/dist/bin/quickbook ; using auto-index : build/dist/bin/auto_index ; using docutils ; using doxygen ; using boostbook ; using asciidoctor ; using saxonhe ;" > tools/build/src/user-config.jam
    ./b2 -j3 libs/$REPONAME/doc/

elif  [ "$typeoption" = "cppal" ]; then
    echo "using doxygen ; using boostbook ; using saxonhe ;" > tools/build/src/user-config.jam
    ./b2 libs/$REPONAME/doc/
fi

if [ "${BOOSTROOTLIBRARY}" = "yes" ]; then
    echo ""
    echo "Build completed. Check the doc/ directory."
    echo ""
else
    echo ""
    echo "Build completed. Check the ../boost-root/libs/${REPONAME}/doc directory."
    echo ""
fi
