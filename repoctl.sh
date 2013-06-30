#!/bin/bash
#set -xv
# Dependencies : python

APP_VERSION='0.1'
APP_AUTHOR='$imon'

if [ "$1" = '--help' ] || [ "$1" = '-h' ] ; then
	echo "=== Lighp repository manager ==="
	echo "    version $APP_VERSION        "
	echo "    written by $APP_AUTHOR      "
	echo ""

	echo "Usage : ./repoctl.sh --repository|-r REPO_PATH --add-pkg|-a [PKG_PATH]"
	echo "Usage : ./repoctl.sh --repository|-r REPO_PATH --delete-pkg|-d PKG_NAME"
	exit
fi

if [ "$1" = '--repository' ] || [ "$1" = '-r' ] ; then
	shift
	repoPath=$(readlink -f "$1")
	shift
else
	read -p "Repository's path : " repoPath
fi

if [ ! -d "$repoPath" ] ; then
	echo "Repo \"$repoPath\" doesn't exists."
	exit
fi

repoMetadataFile="$repoPath/metadata.json"
repoIndexFile="$repoPath/index.json"

currentDir=`pwd` # Current directory

action="$1"
shift

case "$action" in
	'--add-pkg'|'-a')
		pkgRoot="$1"
		shift

		if [ -z "$pkgRoot" ] ; then
			pkgRoot="$currentDir"
		fi

		echo "Loading package from \"$pkgRoot\"..."

		pkgMetadataPath="$pkgRoot/metadata.json"
		pkgFilesPath="$pkgRoot/files.json"
		pkgContentPath="$pkgRoot/source.zip"

		# Check if files exist
		if [ ! -f "$pkgMetadataPath" ] ; then
			echo "Cannot find package's metadata file \"$pkgMetadataPath\""
			exit
		fi
		if [ ! -f "$pkgFilesPath" ] ; then
			echo "Cannot find package's files' index file \"$pkgFilesPath\""
			exit
		fi
		if [ ! -f "$pkgContentPath" ] ; then
			echo "Cannot find package's content file \"$pkgContentPath\""
			exit
		fi

		# Get package's name
		pkgName=`cat "$pkgMetadataPath" | python -c 'import json,sys;obj=json.load(sys.stdin);print obj["name"];'`
		echo "Package's name : \"$pkgName\""

		pkgFirstLetter=${pkgName:0:1}
		repoPkgRoot="$repoPath/packages/$pkgFirstLetter/$pkgName/"

		echo "Creating package's directory \"$repoPkgRoot\"..."

		mkdir -p "$repoPkgRoot"

		echo "Copying files into \"$repoPkgRoot\"..."

		cp "$pkgMetadataPath" "$repoPkgRoot"
		cp "$pkgFilesPath" "$repoPkgRoot"
		cp "$pkgContentPath" "$repoPkgRoot"

		echo "Adding package to index file..."

		if [ -f "$repoIndexFile" ] ; then
			pyScript="import json, sys;
try:
	metadata = json.load(open('$pkgMetadataPath','r'))
	indexes = json.load(open('$repoIndexFile','r'))
except ValueError:
	sys.exit()

found = False
i = 0
for pkg in indexes:
	if (indexes[i]['name'] == metadata['name']):
		found = True
		indexes[i] = metadata
	i += 1
if (not found):
	indexes.append(metadata)
print json.dumps(indexes)"

			json=`python -c "$pyScript"`

			if [ -n "$json" ] ; then
				echo "$json" > "$repoIndexFile"
			else
				echo "Unable to parse JSON."
				exit
			fi
		else
			pkgMetadata=`cat "$pkgMetadataPath"`
			echo "[$pkgMetadata]" > "$repoIndexFile"
			echo '{
	"title":"",
	"kind":"lighp",
	"specification":"1.0",
	"maintainer":""
}' > "$repoMetadataFile"
		fi

		echo "Package added."
		;;
	'--delete-pkg'|'-d')
		pkgName="$1"
		shift

		echo "Package's name : \"$pkgName\""

		pkgFirstLetter=${pkgName:0:1}
		firstLetterDir="$repoPath/packages/$pkgFirstLetter/"
		repoPkgRoot="$firstLetterDir/$pkgName/"

		echo "Deleting package's directory \"$repoPkgRoot\"..."
		rm -R "$repoPkgRoot"
		rmdir "$firstLetterDir" 2>/dev/null # Delete parent dir, if not empty

		echo "Removing package from index file..."

		if [ -f "$repoIndexFile" ] ; then
			pyScript="import json, sys;
try:
	pkgName = '$pkgName'
	indexes = json.load(open('$repoIndexFile','r'))
except ValueError:
	sys.exit()

i = 0
for pkg in indexes:
	if (indexes[i]['name'] == pkgName):
		indexes.pop(i)
	i += 1

print json.dumps(indexes)"

			json=`python -c "$pyScript"`

			if [ -n "$json" ] ; then
				echo "$json" > "$repoIndexFile"
			else
				echo "Unable to parse JSON."
				exit
			fi
		fi

		echo "Package removed"
		;;
	*)
		echo "No action specified. Syntax :"
		echo "repoctl [--repository repository] --add-pkg"
		echo "repoctl [-r repository] -a"
		;;
esac
