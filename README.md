# WSL2 Git

Updated version of (https://github.com/hangxingliu/wslgit).

Updated `get_mounted_drvfs()` function, to work with 9p type of mount.

Please ensure git is installed in your WSL.
1) Copy *wslgit.sh* to the `/usr/bin/` or `~/bin` directory in your WSL.
2) Add the following config into VSCode Settings.
{ "git.path": "C:\\path\\to\\git.bat" }
