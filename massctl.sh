#!/bin/bash

# Dependencies : -

APP_VERSION='0.1'
APP_AUTHOR='$imon'

generatePkgs=false
addPkgsToRepo=false

while test $# -gt 0
do
	if [ "$1" = '--help' ] || [ "$1" = '-h' ] ; then
		echo "=== Lighp package mass controller ==="
		echo "    version $APP_VERSION             "
		echo "    written by $APP_AUTHOR           "
		echo ""

		echo "Usage : ./massctl.sh [--base-dir BASE_DIR] --repository REPO_PATH [--generate] [--add-to-repo]"
		echo "Usage : ./massctl.sh [-b BASE_DIR] -r REPO_PATH [-G] [-A]"
		echo "BASE_DIR: by default, current directory"
		exit
	fi

	if [ "$1" = '--base-dir' ] || [ "$1" = '-b' ] ; then
		shift
		rootPath=$(readlink -f "$1")
	fi

	if [ "$1" = '--repository' ] || [ "$1" = '-r' ] ; then
		shift
		repoPath=$(readlink -f "$1")
	fi

	if [ "$1" = '--generate' ] || [ "$1" = '-G' ] ; then
		generatePkgs=true
	fi

	if [ "$1" = '--add-to-repo' ] || [ "$1" = '-A' ] ; then
		addPkgsToRepo=true
	fi

	shift
done

if [ -z "$rootPath" ] ; then
	rootPath=`pwd`
fi

pkgFolders=( $(ls "$rootPath") )

if [ $generatePkgs = true ] ; then
	for pkgName in ${pkgFolders[@]}
	do
		if [ ! -d "$pkgName" ] ; then
			continue
		fi

		pkgDir="$rootPath/$pkgName"

		if [ ! -d "$pkgDir/src" ] ; then
			continue
		fi

		echo "Adding package in folder \"$pkgDir\"..."
		./generatepkg.sh --name "$pkgName" --input "$pkgDir" --output "$pkgDir"
	done
fi

if [ $addPkgsToRepo = true ] ; then
	if [ -z "$repoPath" ] ; then
		read -p "Repository's path : " repoPath
	fi

	if [ ! -d "$repoPath" ] ; then
		echo "Repo \"$repoPath\" doesn't exists."
		exit
	fi

	for pkgFolder in ${pkgFolders[@]}
	do
		if [ ! -d "$pkgFolder" ] ; then
			continue
		fi

		pkgMetadataPath="$rootPath/$pkgFolder/metadata.json"

		if [ ! -f "$pkgMetadataPath" ] ; then
			continue
		fi

		echo "Adding package in folder \"$pkgFolder\"..."
		./repoctl.sh --repository "$repoPath" --add-pkg "$rootPath/$pkgFolder"
	done
fi

echo "Done."