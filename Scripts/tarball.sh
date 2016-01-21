#! /bin/sh

# Get base directory
base=$( dirname "$0" )
base=$( cd "${base}/../" ; pwd -P )

# Save directory
pushd "$base" > /dev/null

# Build excludes list
cat > Misc/exclude <<EOF
./Misc/exclude
./Misc/tarball.sh
./Misc/TorChat.tgz
./Tests
./DSym
./Crash
xcuserdata
.DS_Store
.svn
EOF

# Prepare environement to not backup extended attributes
export COPYFILE_DISABLE=true
export COPY_EXTENDED_ATTRIBUTES_DISABLE=true

# Clean old
rm -f Misc/TorChat.tgz

# Build tarball
tar -s ':./:TorChat/:' -X misc/exclude -c -z -v -f Misc/TorChat.tgz .

# Clean exclude
rm Misc/exclude

# Restore directory
popd > /dev/null
