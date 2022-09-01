## Building the documentation for specific boost libraries

Each boost libraries contains documentation in the doc/ folder. For example, https://github.com/boostorg/core has documentation in core/doc/. The format is generally [Quickbook](https://www.boost.org/doc/libs/master/doc/html/quickbook.html) and needs to be compiled into html. The scripts here accomplish that.

There are different possible configurations when building the docs:

Option 1. Start out with single boost library.

A new boost-root directory will be generated for you, next to the current repo, (in the location ../boost-root)  and the docs will be output to ../boost-root/libs/_name-of-this-repo_/doc/html

or

Option 2. You have already set up boost-root.

The repo has already been placed in boost-root/libs/_name-of-this-repo_, and that's where you will run the build. In that case, the docs will be output in the current directory, such as _name-of-this-repo_/doc/html.  The existing boost-root will be used.

Either of the above choices are possible. The build scripts detect if they are being run from a boost-root or not.

In order to build the documentation, refer to the appropriate sections below:

## Linux

There various ways to run the script. One method is to run the script from the current location, and tell it where the docs are:
```
./linuxdocs.sh _path_to_boost_library_
```
Another method which might be easier is to copy the script into location in $PATH, so it can be run anywhere. Then, switch to the library's directory.
```
cp linuxdocs.sh /usr/local/bin/
which linuxdocs.sh
cd _path_to_boost_library_
linuxdocs.sh
```

## MacOS

There various ways to run the script. One method is to run the script from the current location, and tell it where the docs are:
```
./macosdocs.sh _path_to_boost_library_
```
Another method which might be easier is to copy the script into location in $PATH, so it can be run anywhere. Then, switch to the library's directory.
```
cp macosdocs.sh /usr/local/bin/
which macosdocs.sh
cd _path_to_boost_library_
macosdocs.sh
```

## Windows

There various ways to run the script. One method is to run the script from the current location, and tell it where the docs are:
```
.\windowsdocs.sh _path_to_boost_library_
```
Another method which might be easier is to copy the script into location in $PATH, so it can be run anywhere. Then, switch to the library's directory.
```
cp windowsdocs.ps1 C:\windows\system32
where windowsdocs.ps1
cd _path_to_boost_library_
windowsdocs.ps1
```
