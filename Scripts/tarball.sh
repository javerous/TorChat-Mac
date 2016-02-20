#! /bin/sh

# Get base directory
base=$( dirname "$0" )
base=$( cd "${base}/../" ; pwd -P )

# Save directory
pushd "$base" > /dev/null

# Build excludes list
cat > Scripts/exclude <<EOF
./Scripts/exclude
TorChat.tgz
xcuserdata
.DS_Store
.git
.gitmodules
EOF

# Prepare environement to not backup extended attributes
export COPYFILE_DISABLE=true
export COPY_EXTENDED_ATTRIBUTES_DISABLE=true

# Clean old
rm -f TorChat.tgz

# Build tarball
tar -s ':./:TorChat/:' -X Scripts/exclude -c -z -v -f TorChat.tgz .

# Clean exclude
rm Scripts/exclude

# Restore directory
popd > /dev/null
