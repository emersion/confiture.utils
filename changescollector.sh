#!/bin/bash

# Dependencies : python, git

APP_VERSION='0.1'
APP_AUTHOR='$imon'

echo "=== Lighp files changes collector ==="
echo "    version $APP_VERSION             "
echo "    written by $APP_AUTHOR           "
echo ""

forceYes=false

while test $# -gt 0
do
	if [ "$1" = '--help' ] || [ "$1" = '-h' ] ; then
		echo "Usage : changescollector.sh [--input|-i PKG_DIR] --lighp-path|-l LIGHP_PATH [--output|-o OUTPUT_DIR] [--yes]"
		echo "Usage : changescollector.sh --git-commit|-g GIT_COMMIT --lighp-path|-l LIGHP_PATH --output|-o OUTPUT_DIR [--yes]"
		echo "PKG_DIR: by default, current directory"
		echo "OUTPUT_DIR: by default, PKG_DIR"
		exit
	fi

	if [ "$1" = '--input' ] || [ "$1" = '-i' ] ; then
		shift
		sourcePath=$(readlink -f "$1")
	fi

	if [ "$1" = '--lighp-path' ] || [ "$1" = '-l' ] ; then
		shift
		lighpRoot=$(readlink -f "$1")
	fi

	if [ "$1" = '--output' ] || [ "$1" = '-o' ] ; then
		shift
		destPath="$1"
	fi

	if [ "$1" = '--yes' ] ; then
		forceYes=true
	fi

	if [ "$1" = '--git-commit' ] || [ "$1" = '-g' ] ; then
		shift
		gitCommit="$1"
	fi

	shift
done

if [ -z "$sourcePath" ] ; then
	sourcePath=`pwd`
fi

if [ -z "$lighpRoot" ] ; then
	read -p "Lighp root path : " lighpRoot
	lighpRoot=$(readlink -f "$lighpRoot")
fi

if [ -z "$destPath" ] ; then
	destPath="$sourcePath"
fi

pkgMetadataPath="$sourcePath/metadata.json"
pkgFilesPath="$sourcePath/files.json"
pkgSrcPath="$sourcePath/source.zip"

if [ ! -z "$gitCommit" ] ; then
	pkgFiles=( $(git --git-dir "$lighpRoot/.git" diff --name-only $gitCommit $gitCommit~1) )
else
	if [ ! -f "$pkgFilesPath" ] ; then
		echo "Cannot find package's files' index file \"$pkgFilesPath\""
		exit
	fi

	pyScript="import json, sys;
try:
	files = json.load(open('$pkgFilesPath','r'))
except ValueError:
	sys.exit()

found = False
i = 0
for key in files:
	print(key)"

	pkgFiles=( $(python -c "$pyScript") )
fi

destPath="$destPath/src"
if [ ! -d "$destPath" ] ; then
	mkdir --parents "$destPath"
fi
destPath=$(readlink -f "$destPath")

cd "$destPath"
destPath=`pwd`

cd "$lighpRoot"

for file in ${pkgFiles[@]}
do
	filePath="$lighpRoot/$file"

	if [ ! -f "$filePath" ] ; then
		question="Delete \"$file\" [Y/n] ? "
	else
		# Compare files
		origSum=`md5sum "$filePath" 2>/dev/null | cut -d" " -f1`
		destSum=`md5sum "$destPath/$file" 2>/dev/null | cut -d" " -f1`

		if [ "$origSum" = "$destSum" ] ; then
			continue
		fi

		question="Copy \"$file\" [Y/n] ? "
	fi

	if [ $forceYes = true ] ; then
		doOperation="Y"
	else
		doOperation=""
		while [ "$doOperation" != 'Y' ] && [ "$doOperation" != 'n' ] ; do
			read -p "$question" -n 1 doOperation
			echo ""
		done
	fi

	if [ "$doOperation" = "Y" ] ; then
		if [ ! -f "$filePath" ] ; then
			rm -f "$filePath"
			echo "Deleted: $file"
		else
			cp --parents "./$file" "$destPath"
			echo "Copied: $file"
		fi
	fi
done

echo "Done."