#!/bin/sh

#
#  build.sh
#
#  Copyright 2016 Avérous Julien-Pierre
#
#  This file is part of TorChat.
#
#  TorChat is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  TorChat is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with TorChat.  If not, see <http://www.gnu.org/licenses/>.
#
#

# Get base directory
base=$( dirname "$0" )
base=$( cd "${base}/../" ; pwd -P )

# Remove previous DMG.
if [ -f '/tmp/torchat_source.sparseimage' ]; then
	echo '[+] Remove previous temporary DMG.'
	
	rm '/tmp/torchat_source.sparseimage'
	
	if [ $? -ne 0 ]; then
		echo "[-] Error: Can't remove previous temporary DMG."
		exit 1	
	fi
fi

# Create temporary DMG
echo '[+] Create temporary DMG.'

/usr/bin/hdiutil create -size 300m -type SPARSE -fs 'HFS+' -volname 'SourceCache' -plist /tmp/torchat_source > /tmp/torchat_output.plist

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't create temporary DMG."
	exit 1	
fi

dmg_path=$( /usr/libexec/PlistBuddy -c 'Print :0' /tmp/torchat_output.plist)

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't obtain path of temporary DMG."
	exit 1	
fi

# Mount temporary DMG
echo '[+] Attach temporary DMG.'

/usr/bin/hdiutil attach "${dmg_path}" -nobrowse -plist > /tmp/torchat_output.plist 

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't attach temporary DMG."
	exit 1	
fi

volume_path=$( /usr/libexec/PlistBuddy -c 'Print :system-entities:0:mount-point' /tmp/torchat_output.plist 2> /dev/null )

if [ $? -ne 0 ]; then
	volume_path=$( /usr/libexec/PlistBuddy -c 'Print :system-entities:1:mount-point' /tmp/torchat_output.plist 2> /dev/null )
	
	if [ $? -ne 0 ]; then
		echo "[-] Error: Can't obtain path of attached DMG."
		exit 1
	fi
fi

# Copy sources.
echo '[+] Copy sources to temporary DMG.'

/bin/cp -R "${base}/Externals" "${volume_path}/Externals"
/bin/cp -R "${base}/TorChat" "${volume_path}/TorChat"
/bin/cp -R "${base}/TorChat.xcworkspace" "${volume_path}/TorChat.xcworkspace"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't copy sources."
	cd / ; /usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1	
fi


# Get git hash.
echo '[+] Get source git hash.'

cd "${base}"
git rev-parse --short HEAD >  "${volume_path}/TorChat/git_hash.txt" 2>/Dev/null

if [ $? -ne 0 ]; then
	echo "[#] Warning: Can't get git hash."
	rm "${volume_path}/TorChat/git_hash.txt"
fi


# Compile.
echo "[+] Compile sources (using "`xcodebuild -version`")."

cd "${volume_path}"

xcodebuild archive -workspace 'TorChat.xcworkspace' -scheme 'TorChat' -derivedDataPath "${volume_path}/DerivedData/" -archivePath "${volume_path}/torchat.xcarchive" 1>> "${volume_path}/build.txt" 2>> "${volume_path}/build_err.txt"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't build sources."
	cat "${volume_path}/build.txt"
	cat "${volume_path}/build_err.txt"
	cd / ; /usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1
fi


# Export archive.
echo '[+] Export archive.'

cat > "${volume_path}/archive.plist" <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>developer-id</string>
	<key>teamID</key>
	<string>4656ESDGU8</string>
</dict>
</plist>
EOL

xcodebuild -exportArchive -archivePath "${volume_path}/torchat.xcarchive" -exportPath "${volume_path}/output/" -exportOptionsPlist "${volume_path}/archive.plist" 1>> "${volume_path}/build.txt" 2>> "${volume_path}/build_err.txt"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't export archive."
	cat "${volume_path}/build.txt"
	cat "${volume_path}/build_err.txt"
	cd / ; /usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1
fi


# Create TorChat tarball.
echo '[+] Create TorChat tarball.'

cd "${volume_path}/output/"
/usr/bin/tar czf "TorChat.tgz" "TorChat.app"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't create TorChat tarball."
	cd / ; /usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1
fi

# Create TorChat Symbols tarball.
echo '[+] Create TorChat symbols tarball.'

cd "${volume_path}/torchat.xcarchive/dSYMs/"
/usr/bin/tar czf "TorChat-Symbols.tgz" "TorChat.app.dSYM"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't create TorChat symbols tarball."
	cd / ; /usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1
fi

# Copy result.
echo '[+] Copy result.'

if [ -z "$1" ]; then
	if [ -z "${HOME}" ]; then
		target_path="/tmp/torchat-result/"
	else
		target_path="${HOME}/Desktop/torchat-result/"
	fi
else
	target_path="${1}/torchat-result/"
fi

echo "[#] Use path '${target_path}'."

rm -rf "${target_path}"
mkdir "${target_path}"

cd "${target_path}"

cp "${volume_path}/output/TorChat.tgz" "${target_path}"
cp "${volume_path}/torchat.xcarchive/dSYMs/TorChat-Symbols.tgz" "${target_path}"

if [ ! -z "$DISPLAY" ]; then
	open "${target_path}"
fi

# Clean.
echo '[+] Clean.'

cd / ; /usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null

rm -f "${dmg_path}"
rm -f "/tmp/torchat_output.plist"
