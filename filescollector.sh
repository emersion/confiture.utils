#!/bin/bash

# Dependencies : find

APP_VERSION='0.1'
APP_AUTHOR='$imon'

while test $# -gt 0
do
	if [ "$1" = '--help' ] || [ "$1" = '-h' ] ; then
		echo "=== Lighp package files collector ==="
		echo "    version $APP_VERSION             "
		echo "    written by $APP_AUTHOR           "
		echo ""

		echo "Usage : ./filescollector.sh --query QUERY --lighp-path LIGHP_PATH [--output OUTPUT_DIR]"
		echo "Usage : ./filescollector.sh -q QUERY -l LIGHP_PATH [-o OUTPUT_DIR]"
		exit
	fi

	if [ "$1" = '--query' ] || [ "$1" = '-q' ] ; then
		shift
		searchQuery="$1"
	fi

	if [ "$1" = '--lighp-path' ] || [ "$1" = '-l' ] ; then
		shift
		lighpRoot=$(readlink -f "$1")
	fi

	if [ "$1" = '--output' ] || [ "$1" = '-o' ] ; then
		shift
		destPath="$1"
	fi

	shift
done

if [ -z "$searchQuery" ] ; then
	read -p "Search query : " searchQuery
fi

if [ -z "$lighpRoot" ] ; then
	read -p "Lighp root path : " lighpRoot
	lighpRoot=$(readlink -f "$lighpRoot")
fi

if [ -z "$destPath" ] ; then
	destPath=`pwd`
fi

destPath="$destPath/src"
if [ ! -d "$destPath" ] ; then
	mkdir --parents "$destPath"
fi
destPath=$(readlink -f "$destPath")

cd "$lighpRoot"

pkgFiles=( $(find . -type f -iwholename "*$searchQuery*") )

for file in ${pkgFiles[@]}
do
	if [ -f "$destPath/$file" ] ; then
		# Compare files
		origSum=`md5sum "$file" | cut -d" " -f1`
		destSum=`md5sum "$destPath/$file" | cut -d" " -f1`

		if [ "$origSum" = "$destSum" ] ; then
			continue
		fi
	fi

	keepFile=""
	while [ "$keepFile" != 'Y' ] && [ "$keepFile" != 'n' ] ; do
		read -p "Copy \"$file\" [Y/n] ? " -n 1 keepFile
		echo ""
	done

	if [ "$keepFile" = "Y" ] ; then
		cp --parents "$file" "$destPath"
	fi
done

echo "Done."