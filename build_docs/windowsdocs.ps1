
# Copyright 2022 Sam Darwin
#
# Distributed under the Boost Software License, Version 1.0.
# (See accompanying file LICENSE_1_0.txt or copy at http://boost.org/LICENSE_1_0.txt)

param (
   [Parameter(Mandatory=$false)][alias("path")][string]$pathoption = "",
   [Parameter(Mandatory=$false)][alias("type")][string]$typeoption = "",
   [switch]$help = $false,
   [switch]${skip-boost} = $false,
   [switch]${skip-packages} = $false,
   [switch]$quick = $false
)

$scriptname="windowsdocs.ps1"

if ($help) {

$helpmessage="
usage: $scriptname [-help] [-type TYPE] [-skip-boost] [-skip-packages] [path_to_library]

Builds library documentation.

optional arguments:
  -help                 Show this help message and exit
  -type TYPE            The `"type`" of build. Defaults to `"main`" which installs all standard boost prerequisites.
                        Another option is `"cppal`" which installs the prerequisites used by boostorg/json and a few other similar libraries.
                        More `"types`" can be added in the future if your library needs a specific set of packages installed.
                        The type is usually auto-detected and doesn't need to be specified.
  -skip-boost           Skip downloading boostorg/boost and building b2 if you are certain those steps have already been done.
  -skip-packages        Skip installing all packages (pip, gem, apt, etc.) if you are certain that has already been done.
  -quick                Equivalent to setting both -skip-boost and -skip-packages. If not sure, then don't skip these steps.


standard arguments:
  path_to_library       Where the library is located. Defaults to current working directory.
"

echo $helpmessage
exit 0
}
if ($quick) { ${skip-boost} = $true ; ${skip-packages} = $true ; } 

pushd

# git is required. In the unlikely case it's not yet installed, moving that part of the package install process
# here to an earlier part of the script:

if ( -Not ${skip-packages} ) {
    if ( -Not (Get-Command choco -errorAction SilentlyContinue) ) {
        echo "Install chocolatey"
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    
    if ( -Not (Get-Command git -errorAction SilentlyContinue) ) {
        echo "Install git"
        choco install -y git
    }

    # Make `refreshenv` available right away, by defining the $env:ChocolateyInstall
    # variable and importing the Chocolatey profile module.
    # Note: Using `. $PROFILE` instead *may* work, but isn't guaranteed to.
    $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    refreshenv
}

if ($pathoption) {
    echo "Library path set to $pathoption. Changing to that directory."
    cd $pathoption
}
else
{
    $workingdir = pwd
    echo "Using current working directory $workingdir."
}

# DETERMINE REPOSITORY

$originurl=git config --get remote.origin.url
if ($LASTEXITCODE -eq 0)  {
    $REPONAME=[io.path]::GetFileNameWithoutExtension($originurl)
}
else { 
    $REPONAME="empty"
}

if (($REPONAME -eq "empty") -or ($REPONAME -eq "release-tools")) {
    echo ""
    echo "Set the path_to_library as the first command-line argument:"
    echo ""
    echo "$scriptname _path_to_library_"
    echo ""
    echo "Or change the working directory to that first."
    exit 1
}
else {
    echo "REPONAME is $REPONAME"
}

$BOOST_SRC_FOLDER=git rev-parse --show-toplevel
if ( ! $LASTEXITCODE -eq 0)  {
    $BOOST_SRC_FOLDER="nofolder"
}
else {
    echo "BOOST_SRC_FOLDER is $BOOST_SRC_FOLDER"
}

$PARENTNAME=[io.path]::GetFileNameWithoutExtension($(git --git-dir $BOOST_SRC_FOLDER/../../.git config --get remote.origin.url))


if ( $PARENTNAME -eq "boost" )
{
    echo "Starting out inside boost-root"
    $BOOSTROOTLIBRARY="yes"
}
else
{
    echo "Not starting out inside boost-root"
    $BOOSTROOTLIBRARY="no"
}

# DECIDE THE TYPE

$alltypes="main cppal"
$cppaltypes="json beast url http_proto socks_proto zlib"

if (! $typeoption ) {
    if ($cppaltypes.contains($REPONAME)) {
        $typeoption="cppal"
    }
    else {
        $typeoption="main"
    }
}

echo "Build type is $typeoption"

if ( ! $alltypes.contains($typeoption)) {
    echo "Allowed types are currently 'main' and 'cppal'. Not $typeoption. Please choose a different option. Exiting."
    exit 1
}

$REPO_BRANCH=git rev-parse --abbrev-ref HEAD
echo "REPO_BRANCH is $REPO_BRANCH"

if ( $REPO_BRANCH -eq "master" )
{
    $BOOST_BRANCH="master"
}
else
{
    $BOOST_BRANCH="develop"
}

echo "BOOST_BRANCH is $BOOST_BRANCH"

echo '==================================> INSTALL'

if ( -Not ${skip-packages} ) {

    if ( -Not (Get-Command choco -errorAction SilentlyContinue) ) {
        echo "Install chocolatey"
        iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))
    }
    
    choco install -y rsync sed doxygen.install xsltproc docbook-bundle
    
    if ( -Not (Get-Command java -errorAction SilentlyContinue) )
    {
        choco install -y openjdk --version=17.0.1
    }
    
    if ( -Not (Get-Command python -errorAction SilentlyContinue) )
    {
        choco install -y python3
    }
    
    if ( -Not (Get-Command git -errorAction SilentlyContinue) )
    {
        choco install -y git
    }
    
    if ($typeoption -eq "main") {
    if ( -Not (Get-Command ruby -errorAction SilentlyContinue) )
    {
        choco install -y ruby
    }
    }
    
    # Make `refreshenv` available right away, by defining the $env:ChocolateyInstall
    # variable and importing the Chocolatey profile module.
    # Note: Using `. $PROFILE` instead *may* work, but isn't guaranteed to.
    $env:ChocolateyInstall = Convert-Path "$((Get-Command choco).Path)\..\.."
    Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
    
    refreshenv
    
    # if [ "$typeoption" = "main" ]; then
    #     sudo apt-get install -y python3-pip ruby docutils-doc docutils-common python3-docutils
    #     sudo gem install asciidoctor --version 1.5.8
    #     sudo pip3 install docutils
    # fi
    
    if ($typeoption -eq "main") {
        gem install asciidoctor --version 1.5.8
        pip install docutils
        $pattern = '[\\/]'
        $asciidoctorpath=(get-command asciidoctor).Path -replace $pattern, '/'
    }
    
    # A bug fix, which may need to be developed further:
    # b2 reports that the "cp" command can't be found on Windows.
    # Let's add git's version of "cp" to the PATH.
    $newpathitem="C:\Program Files\Git\usr\bin"
    if( (Test-Path -Path $newpathitem) -and -Not ( $env:Path -like "*$newpathitem*"))
    {
           $env:Path += ";$newpathitem"
    }
    
    Copy-Item "C:\Program Files\doxygen\bin\doxygen.exe" "C:\Windows\System32\doxygen.exe"

    cd $BOOST_SRC_FOLDER
    cd ..
    if ( -Not (Test-Path -Path "tmp") )
    {
        mkdir tmp
    }
    
    cd tmp
    
    # Install saxon
    if ( -Not (Test-Path -Path "C:\usr\share\java\Saxon-HE.jar") )
    {
        $source = 'https://sourceforge.net/projects/saxon/files/Saxon-HE/9.9/SaxonHE9-9-1-4J.zip/download'
        $destination = 'saxonhe.zip'
        if ( Test-Path -Path $destination)
        {
            rm $destination
        }
        if ( Test-Path -Path "saxonhe")
        {
            rm Remove-Item saxonhe -Recurse -Force
        }
        Start-BitsTransfer -Source $source -Destination $destination
        Expand-Archive .\saxonhe.zip
        cd saxonhe
        if ( -Not (Test-Path -Path "C:\usr\share\java") )
        {
            mkdir "C:\usr\share\java"
        }
        cp saxon9he.jar Saxon-HE.jar
        cp Saxon-HE.jar "C:\usr\share\java\"
    }

}

cd $BOOST_SRC_FOLDER

if ( ${skip-boost} ) {
    # skip-boost was set. A reduced set of actions.
    if ( $BOOSTROOTLIBRARY -eq "yes" ) {
        cd ../..
        $Env:BOOST_ROOT=Get-Location | Foreach-Object { $_.Path }
        echo "Env:BOOST_ROOT is $Env:BOOST_ROOT"
    }

    else {
        cd ..
        if ( -Not (Test-Path -Path "boost-root") ) {
            echo "boost-root missing. Rerun this script without the -skip-boost or -quick option."
            exit(1)
	    }
        else {
            cd boost-root
            $Env:BOOST_ROOT=Get-Location | Foreach-Object { $_.Path }
            echo "Env:BOOST_ROOT is $Env:BOOST_ROOT"
            if (Test-Path -Path "libs\$REPONAME")
            {
                rmdir libs\$REPONAME -Force -Recurse
            }
            Copy-Item -Path $BOOST_SRC_FOLDER -Destination libs\$REPONAME -Recurse -Force
            }
        } 
    }
else {
    # skip-boost was not set. The standard flow.
    #
    if ( $BOOSTROOTLIBRARY -eq "yes" ) {
        echo "updating boost-root"
        cd ../..
        git checkout $BOOST_BRANCH
        git pull
        $Env:BOOST_ROOT=Get-Location | Foreach-Object { $_.Path }
        echo "Env:BOOST_ROOT is $Env:BOOST_ROOT"
    }
    else {
        cd ..
        if ( -Not (Test-Path -Path "boost-root") ) {
            echo "cloning boost-root"
            git clone -b $BOOST_BRANCH https://github.com/boostorg/boost.git boost-root --depth 1
            cd boost-root
            $Env:BOOST_ROOT=Get-Location | Foreach-Object { $_.Path }
            echo "Env:BOOST_ROOT is $Env:BOOST_ROOT"
            if (Test-Path -Path "libs\$REPONAME")
            {
                rmdir libs\$REPONAME -Force -Recurse
            }
            Copy-Item -Path $BOOST_SRC_FOLDER -Destination libs\$REPONAME -Recurse -Force
        }
        else {
            echo "updating boost-root"
            cd boost-root
            git checkout $BOOST_BRANCH
            git pull
            $Env:BOOST_ROOT=Get-Location | Foreach-Object { $_.Path }
            echo "Env:BOOST_ROOT is $Env:BOOST_ROOT"
            if (Test-Path -Path "libs\$REPONAME")
            {
                rmdir libs\$REPONAME -Force -Recurse
            }
            Copy-Item -Path $BOOST_SRC_FOLDER -Destination libs\$REPONAME -Recurse -Force
        }
    }
}

if ( -Not ${skip-boost} ) {
    git submodule update --init libs/context
    git submodule update --init tools/boostbook
    git submodule update --init tools/boostdep
    git submodule update --init tools/docca
    git submodule update --init tools/quickbook
    git submodule update --init tools/build
    
    if ($typeoption -eq "main") {
        git submodule update --init tools/auto_index
        git submodule update --quiet --init --recursive
    
        # recopy the library as it might have been overwritten
        Copy-Item -Path $BOOST_SRC_FOLDER\* -Destination libs\$REPONAME\ -Recurse -Force
    }
    
    $matcher='\.saxonhe_jar = \$(jar\[1\]) ;$'
    $replacer='.saxonhe_jar = $(jar[1]) ;  .saxonhe_jar = \"/usr/share/java/Saxon-HE.jar\" ;'
    sed -i "s~$matcher~$replacer~" tools/build/src/tools/saxonhe.jam
    
    python tools/boostdep/depinst/depinst.py ../tools/quickbook
    
    echo "Running bootstrap.bat"
    ./bootstrap.bat
    
    echo "Running ./b2 headers"
    ./b2 headers
}

echo '==================================> COMPILE'

if ($typeoption -eq "main") {
    ./b2 -q -d0 --build-dir=build --distdir=build/dist tools/quickbook tools/auto_index/build
    $content="using quickbook : build/dist/bin/quickbook ; using auto-index : build/dist/bin/auto_index ; using docutils ; using doxygen : `"/Program Files/doxygen/bin/doxygen.exe`" ; using boostbook ; using asciidoctor : `"$asciidoctorpath`" ; using saxonhe ;"
    $filename="$Env:BOOST_ROOT\tools\build\src\user-config.jam"
    [IO.File]::WriteAllLines($filename, $content)
    ./b2 libs/$REPONAME/doc/
}
elseif ($typeoption -eq "cppal") {
    $content="using doxygen : `"/Program Files/doxygen/bin/doxygen.exe`" ; using boostbook ; using saxonhe ;"
    $filename="$Env:BOOST_ROOT\tools\build\src\user-config.jam"
    [IO.File]::WriteAllLines($filename, $content)
    ./b2 libs/$REPONAME/doc/
}

if ($BOOSTROOTLIBRARY -eq "yes") {
    echo ""
    echo "Build completed. Check the doc/ directory."
    echo ""
}
else {
    echo ""
    echo "Build completed. Check the ../boost-root/libs/${REPONAME}/doc directory."
    echo ""
}

popd

