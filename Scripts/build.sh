#!/bin/sh

# Get base directory
base=$( dirname "$0" )
base=$( cd "${base}/../" ; pwd -P )

# Remove previous DMG.
if [ -f '/tmp/torchar_source.sparseimage' ]; then
	echo '[+] Remove previous temporary DMG.'
	
	rm '/tmp/torchar_source.sparseimage'
	
	if [ $? -ne 0 ]; then
		echo "[-] Error: Can't remove previous temporary DMG."
		exit 1	
	fi
fi

# Create temporary DMG
echo '[+] Create temporary DMG.'

/usr/bin/hdiutil create -size 100m -type SPARSE -fs 'HFS+' -volname 'SourceCache' -plist /tmp/torchar_source > /tmp/torchat_output.plist

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't create temporary DMG."
	exit 1	
fi

dmg_path=$(/usr/libexec/PlistBuddy -c 'Print :0' /tmp/torchat_output.plist)

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't obtain path of temporary DMG."
	exit 1	
fi

# Mount temporary DMG
echo '[+] Attach temporary DMG.'

/usr/bin/hdiutil attach "${dmg_path}" -plist > /tmp/torchat_output.plist

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't attach temporary DMG."
	exit 1	
fi

volume_path=$(/usr/libexec/PlistBuddy -c 'Print :system-entities:0:mount-point' /tmp/torchat_output.plist)

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't obtain path of attached DMG."
	exit 1	
fi

# Copy sources.
echo '[+] Copy sources to temporary DMG.'

/bin/cp -R "${base}/TorChat" "${volume_path}/TorChat"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't copy sources."
	/usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1	
fi


# Get git hash.
echo '[+] Get source git hash.'

cd "${base}"
git rev-parse --short HEAD >  "${volume_path}/TorChat/git_hash.txt"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't get git hash."
	/usr/bin/hdiutil detach "${volume_path}" 1>/dev/null 2>/dev/null
	exit 1	
fi


# Compile.
echo '[+] Compile sources.'

cd "${volume_path}/TorChat"

xcodebuild archive -project 'TorChat.xcodeproj' -scheme 'TorChat' -archivePath "${volume_path}/torchat.xcarchive" 1> "${volume_path}/build.txt" 2> "${volume_path}/build_err.txt"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't build sources."
	cat "${volume_path}/build.txt"
	cat "${volume_path}/build_err.txt"
	/usr/bin/hdiutil detach "${volume_path}" 2>/dev/null 1>/dev/null
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

xcodebuild -exportArchive -archivePath "${volume_path}/torchat.xcarchive" -exportPath "${volume_path}/output/" -exportOptionsPlist "${volume_path}/archive.plist" 1> "${volume_path}/build.txt" 2> "${volume_path}/build_err.txt"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't export archive."
	cat "${volume_path}/build.txt"
	cat "${volume_path}/build_err.txt"
	/usr/bin/hdiutil detach "${volume_path}" 2>/dev/null 1>/dev/null
	exit 1
fi


# Create TorChat tarball.
echo '[+] Create TorChat tarball.'

cd "${volume_path}/output/"
/usr/bin/tar czf "TorChat.tgz" "TorChat.app"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't create TorChat tarball."
	/usr/bin/hdiutil detach "${volume_path}" 2>/dev/null 1>/dev/null
	exit 1
fi

# Create TorChat Symbols tarball.
echo '[+] Create TorChat symbols tarball.'

cd "${volume_path}/torchat.xcarchive/dSYMs/"
/usr/bin/tar czf "TorChat-Symbols.tgz" "TorChat.app.dSYM"

if [ $? -ne 0 ]; then
	echo "[-] Error: Can't create TorChat symbols tarball."
	/usr/bin/hdiutil detach "${volume_path}" 2>/dev/null 1>/dev/null
	exit 1
fi

# Copy result.
echo '[+] Copy result.'

rm -rf "/Users/${USER}/Desktop/torchat-result/"
mkdir "/Users/${USER}/Desktop/torchat-result/"

cd "/Users/${USER}/Desktop/torchat-result/"

cp "${volume_path}/output/TorChat.tgz" "/Users/${USER}/Desktop/torchat-result/"
cp "${volume_path}/torchat.xcarchive/dSYMs/TorChat-Symbols.tgz" "/Users/${USER}/Desktop/torchat-result/"

open "/Users/${USER}/Desktop/torchat-result/"

# Clean.
echo '[+] Clean.'

/usr/bin/hdiutil detach "${volume_path}" 2>/dev/null 1>/dev/null

rm -f "${dmg_path}"
rm -f "/tmp/torchat_output.plist"
