#!/bin/bash

# Dependencies : -

APP_VERSION='0.1'
APP_AUTHOR='$imon'

collectChanges=false
collectChangesNoConfirm=false
generatePkgs=false
addPkgsToRepo=false

while test $# -gt 0
do
	if [ "$1" = '--help' ] || [ "$1" = '-h' ] ; then
		echo "=== Lighp package mass controller ==="
		echo "    version $APP_VERSION             "
		echo "    written by $APP_AUTHOR           "
		echo ""

		echo "Usage : ./massctl.sh [--repository REPO_PATH] [--base-dir BASE_DIR] [--lighp-path LIGHP_PATH] [--collect-changes] [--collect-noconfirm] [--generate] [--add-to-repo]"
		echo "Usage : ./massctl.sh [-r REPO_PATH] [-b BASE_DIR] [--l LIGHP_PATH] [-C] [-G] [-A]"
		echo "BASE_DIR: by default, current directory"
		echo "LIGHP_PATH: by default, none"
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

	if [ "$1" = '--lighp-path' ] || [ "$1" = '-l' ] ; then
		shift
		lighpPath=$(readlink -f "$1")
	fi

	if [ "$1" = '--collect-changes' ] || [ "$1" = '-C' ] ; then
		collectChanges=true
	fi

	if [ "$1" = '--collect-noconfirm' ] ; then
		collectChangesNoConfirm=true
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

if [ $collectChanges = true ] ; then
	if [ -z "$lighpPath" ] ; then
		read -p "Lighp's path : " lighpPath
	fi

	if [ ! -d "$lighpPath" ] ; then
		echo "Lighp dir \"$lighpPath\" doesn't exists."
		exit
	fi

	for pkgName in ${pkgFolders[@]}
	do
		if [ ! -d "$pkgName" ] ; then
			continue
		fi

		pkgDir="$rootPath/$pkgName"

		if [ ! -d "$pkgDir/src" ] ; then
			continue
		fi

		echo "Collecting changes for package in folder \"$pkgDir\"..."

		args="--input \"$pkgDir\" --lighp-path \"$lighpPath\""
		if [ $collectChangesNoConfirm = true ] ; then
			args="$args --yes"
		fi

		eval "./changescollector.sh $args"
	done
fi

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

		echo "Generating package in folder \"$pkgDir\"..."
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