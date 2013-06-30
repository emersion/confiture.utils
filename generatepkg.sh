#!/bin/bash

# Dependencies : mktemp, zip, du, md5sum, (python)

APP_VERSION='0.1'
APP_AUTHOR='$imon'

while test $# -gt 0
do
	if [ "$1" = '--help' ] || [ "$1" = '-h' ] ; then
		echo "=== Lighp package generator ==="
		echo "    version $APP_VERSION       "
		echo "    written by $APP_AUTHOR     "
		echo ""

		echo "Usage : ./generatepkg.sh --name PKG_NAME --input PKG_SOURCE [--output OUTPUT_DIR]"
		echo "Usage : ./generatepkg.sh -n PKG_NAME -i PKG_SOURCE [-o OUTPUT_DIR]"
		exit
	fi

	if [ "$1" = '--name' ] || [ "$1" = '-n' ] ; then
		shift
		pkgName="$1"
	fi

	if [ "$1" = '--input' ] || [ "$1" = '-i' ] ; then
		shift
		pkgRoot=$(readlink -f "$1")
	fi

	if [ "$1" = '--output' ] || [ "$1" = '-o' ] ; then
		shift
		destDir="$1"
	fi

	shift
done

if [ -z "$pkgName" ] ; then
	read -p "Package's name : " pkgName
fi

if [ -z "$pkgRoot" ] ; then
	pkgRoot=`pwd`
fi

pkgFiles="$pkgRoot/src"
if [ ! -d "$pkgFiles" ] ; then
	echo "The source directory \"$pkgFiles\" doesn't exist."
	exit
fi
pkgFiles=$(readlink -f "$pkgFiles") #Equivalent to realpath (see https://andy.wordpress.com/2008/05/09/bash-equivalent-for-php-realpath/)

if [ -z "$destDir" ] ; then
	destDir="$pkgRoot"
fi

if [ ! -d "$destDir" ] ; then
	mkdir --parents "$destDir"
fi
destDir=$(readlink -f "$destDir")

# Create a temporary directory and copy files in it
tmpDir=`mktemp -d`

echo "Copying package's source to \"$tmpDir/src/\"..."
cp -R "$pkgFiles" "$tmpDir/src/"

cd "$tmpDir/"

# List package's files
echo -n "Calculating package's size..."
pkgExtractedSize=`du --apparent-size --block-size=1 src/ | tail -n 1 | cut -f1`
echo ' '$pkgExtractedSize" B"

echo "Creating files list..."

echo -n '{' > "$destDir/files.json"

function listFilesInDir() {
	for file in `ls -a "src/$1" 2>/dev/null`
	do
		if [ "$file" = '..' ] || [ "$file" = '.' ] ; then
			continue
		fi

		if [ -z $1 ]
		then
			filePath="$file"
		else
			filePath="$1/$file"
		fi

		if [ -d "src/$filePath" ]
		then
			echo "Open: $filePath"
			listFilesInDir "$filePath"
		else
			echo "Add: $filePath"

			comma=''
			if [ "`cat "$destDir/files.json"`" != '{' ]
			then
				comma=','
			fi

			md5sum=`md5sum "src/$filePath" | cut -d" " -f1`
			echo -n $comma >> "$destDir/files.json"
			echo "" >> "$destDir/files.json"
			echo -n '	"/'$filePath'":{"md5sum":"'$md5sum'"}' >> "$destDir/files.json"
		fi
	done
}

listFilesInDir

echo "" >> "$destDir/files.json"
echo -n '}' >> "$destDir/files.json"

# Compress files
echo "Zipping files to \"source.zip\"..."
if [ -f "$destDir/source.zip" ] ; then
	rm "$destDir/source.zip"
fi
zip --quiet --recurse-paths "$destDir/source.zip" src/

echo -n "Calculating compressed package's size..."
pkgSize=`du --apparent-size --block-size=1 "$destDir/source.zip" | tail -n 1 | cut -f1`
echo ' '$pkgSize" B"

# Add scripts
hasScripts="false"
if [ -f "$pkgRoot"/INSTALL.* ] || [ -f "$pkgRoot"/REMOVE.* ] ; then
	echo "Copying install & remove scripts..."
	cp "$pkgRoot"/{INSTALL,REMOVE}.* .

	echo "Zipping install & remove scripts..."
	zip --quiet --recurse-paths "$destDir/source.zip" ./{INSTALL,REMOVE}.*

	hasScripts="true"
fi

updateDate=`date "+%F %R:%S"`

echo "Creating package's metadata..."
metadata='{
	"name":"'$pkgName'",
	"title":"'$pkgName'",
	"subtitle":"",
	"version":"",
	"description":"",
	"url":"",
	"maintainer":"",
	"license":"",
	"size":'$pkgSize',
	"extractedSize":'$pkgExtractedSize',
	"updateDate":"'$updateDate'",
	"hasScripts":'$hasScripts'
}'

metadataPath="$destDir/metadata.json"
if [ -f "$metadataPath" ] ; then
	echo "	Metadata file already exist. Merging it with new data..."
	pyScript="import json, sys;
try:
	metadata = json.load(open('$metadataPath','r'))
except ValueError:
	metadata = {}

metadata['name'] = ''
metadata['size'] = ''
metadata['extractedSize'] = ''
metadata['updateDate'] = ''

newMetadata = json.loads(\"\"\"$metadata\"\"\")
for key in newMetadata:
	if (not key in metadata or not metadata[key] and newMetadata[key]):
		metadata[key] = newMetadata[key]

print json.dumps(metadata, indent = 4)"

	json=`python -c "$pyScript"`

	echo "$json" > "$metadataPath"
else
	echo "$metadata" > "$metadataPath"
fi

# Clean the terrain
echo "Deleting temporary directory..."
rm -rf "$tmpDir"

echo "Package generated."