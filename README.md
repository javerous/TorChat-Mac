Torchat-Mac
===========

TorChat for Mac is a macOS native and unofficial port of [torchat](https://github.com/prof7bit/TorChat).


## Technics
TorChat for Mac is written in Objective-C 2.0 with Cocoa framework.
The current version needs macOS 10.10 (Yosemite) minimum to work.


## Modes
TorChat for Mac offers two modes : bundled mode and custom mode.


### Bundle mode
This mode try to handle things for you. TorChat for Mac launch a bundled `tor` binary, configure it and configure a torchat address the first time. You have almost nothing to do to start to chat.

*Benefits* :
- Easy to use, you just have to launch the application, and that's all.
- More easily when you use TorChat in nomadic.

*Drawback* :
- Because `tor` have some bootstrapping process (connect to network, declare your address, etc.), you have to wait a moment each time you quit / launch the application before being able to chat (this can take up to about 5 minutes).
- If your IP appear on the `tor` network and then your torchat identity appear online, this can help malicious person to break your anonymity by correlating the two events.


### Custom mode

This mode just connect TorChat for Mac to an already existing configured `tor` instance.

*Benefits* :
- If your `tor` instance is already running for a while, each time you quit / launch TorChat, you will appear online and see other contacts quicker.
- If you use `tor` for anything other than just chatting, this will prevent to have multi instance or `tor` running at the same time.
- You will prevent to break your anonymity by events correlation (see basic mode drawbacks).

*Drawback* :
- You have to manually configure the hidden service, and configure TorChat to use it.


## Files
### Configuration file

All your settings are written on a file called `torchat.conf` - some other settings can be put in `~/Library/Preferences/com.SourceMac.TorChat.plist` by macOS, but it's mainly settings related to interface (Windows positions, last preference panel selection, last directory selected, etc.). Nothing related to your buddies, chats, etc.

When you create a configuration file for the first time via the assistant, a configuration file is created accordingly to those specifications :
- If your `TorChat.app` is in `/Applications/`, then your configuration file is created at this path : `~/Library/Preferences/torchat.conf`
- If your `TorChat.app` is anywhere else, then your configuration file is created at the same directory as your `TorChat.app`.

If you put TorChat in the Applications directory (first case), then it's supposed you want to respect standard macOS usage, and so we put stuff on the right places on your system. But if you put TorChat in another directory (second case), then we try to respond to those specific purposes :
- Don't scatter private data everywhere in the computer. So if the computer is not yours, you can quickly delete this file once you have finished your chat.
- Be able to create an "all-in-one" USB key / DMG. This way, you can just put TorChat.app, your configuration and your data files in a cyphered USB key / DMG, then plug-in it on any computer, chat, and eject when finished. No need to copy and expose your private data on the host computer.


When `TorChat.app` is launched, it tries to find the configuration file in these places :
- The same directory as your TorChat application (see upper explanations).
- `~/torchat.conf`
- `~/.torchat.conf`
- `~/.config/torchat.conf`
- `~/Library/Preferences/torchat.conf`

Is none of this path can be opened, the assistant will either ask you to create a new configuration file, either ask you to select one manually.


### Extra files

When you use TorChat in bundled mode, a `tor` instance is configured and launched for you. This configuration needs two distinct directory :
- The `bin` directory used to store `tor` binary itself + its signatures + dylib files. By default, this directory is either in `Tor` directory inside `~/Library/Application Support/TorChat/` (TorChat in Application directory), either inside the `tor` directory, itself at the same level as your configuration file (TorChat anywhere else).
- The `data` directory used to store data used by `tor` binary (mainly caches). By default, this directory is either in `TorData` directory inside `~/Library/Application Support/TorChat/` (TorChat in Application directory), either inside the `tor` directory, itself at the same level as your configuration file.
- The `Downloads` directory used to store files sent by your buddies. By default, this directory is either `~/Downloads/` (TorChat in Applications directory), either  at the same level as your configuration file.

You can change the place and the name of those directories by going to the Preferences -> Locations panel settings. The "referral" is where your configuration file is, the "standard" is where you expect your file to be on a standard macOS application (`~/Library/...`), and "absolute" is absolute path.

Note: the `tor` binary is not launched from inside the `TorChat.app` bundle because it can be updated. And it's not recommended to modify the content of an application bundle.


## Functionalities
### File exchange

TODO

### Buddies

TODO

### Logs

TODO



## Tests

If you want to test new versions of TorChat, send me a simple e-mail to `torchat [at] sourcemac [dot] com`.

I will send you betas or golden master versions some days before official releases, and if you have free time and motivation, you can peacefully test them and tell me if you saw problematic stuff. It's a best effort testing, so no pressure.
