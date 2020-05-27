#!/usr/bin/env bash

# WARNING: DO NOT EDIT THIS FILE MANUALLY!
# WARNING: Because This file is generated from wslgit.dev.sh by ./script/gen-wslgit-sh.sh

# =========================================
#  Name:    wslgit.sh
#  Update:  2019-06-01
#  License: GPL-3.0
#  Author:  Liu Yue (hangxingliu@gmail.com)
#
#  Description:
#    Convert the Windows path contained in the arguments to Linux(WSL) path,
#       and convert the Linux(WSL) path in output of git to Windows path.
#    This script use `mount` command, awk scripts to implement above features.
#       I retained the implementation via `wslpath` codes in this script for
#       reference purposes only. (because wslpath has some shortcomings to
#       implement it)
# ==========================================

AWK="$(which gawk)";
[[ -z "$AWK" ]] && AWK="$(which awk)";
[[ -z "$AWK" ]] && echo "fatal: \"awk\" is not installed in WSL!" >&2 && exit 1;

function get_mounted_drvfs() {
	mount -t 9p | "$AWK" '
	function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t]+$/, "", s); return s; }
	{
		if(split($0, lr, "type 9p") < 2) next;
		if(split(lr[1], part, "on") < 2) next;

		drive = trim(substr(part[1],1,2));
		mount_to = trim(part[2]);

		print toupper(drive) "\n" mount_to;
	}';
}
MOUNTED_DRVFS="$(get_mounted_drvfs)";

function to_unix_path_by_wslpath() {
	local unix_path;
	unix_path="$(wslpath "$1" 2>/dev/null)"; # empty output means it is not a Linux path
	[[ -n "$unix_path" ]] && printf "%s" "$unix_path" || printf "%s" "$1";
}
function to_win_path_by_wslpath() {
	local win_path;
	win_path="$(wslpath -w "$1" 2>/dev/null)"; # empty output means it is not a Linux path
	[[ -n "$win_path" ]] && printf "%s" "$win_path";
}

function to_unix_path_by_awk() {
	printf "%s" "$1"  |
		"$AWK" -v _mount="$MOUNTED_DRVFS" 'BEGIN { mount_len = split(_mount, mount_list, "\n"); }
		{
			if(index($0, ":\\") == 2) {
				driver = toupper(substr($0, 1, 2));
				for(i = 1; i <= mount_len ; i += 2 ) {
					if(driver != mount_list[i]) continue;
					suffix = substr($0, 3); gsub(/\\/, "/", suffix); gsub("//", "/", suffix);
					print mount_list[i+1] suffix;
					exit;
				}
			}
			print $0;
			exit;
		}';
}
function to_win_path_by_awk() {
	"$AWK" -v _mount="$MOUNTED_DRVFS" 'BEGIN { mount_len = split(_mount, mount_list, "\n"); }
		{
			for(i = 1; i <= mount_len ; i += 2 ) {
				if(sub(mount_list[i+1], mount_list[i]) > 0) {
					gsub("/", "\\");
					break;
				}
			}
			print $0;
		}';
}

if [[ -n "$WSLGIT_SH_CWD" ]]; then
	correct_cwd="$(to_unix_path_by_awk "$WSLGIT_SH_CWD")";
	cd "$correct_cwd";
	[[ "$?" != 0 ]] && echo "fatal: can not cd to ${WSLGIT_SH_CWD} ($correct_cwd)" >&2 && exit 1;
fi

argv=0;
convert_output=false;
after_double_dash=false;
for arg in "$@"; do
	if [[ "$after_double_dash" != true ]]; then
		if [[ "$arg" == "rev-parse" ]] || [[ "$arg" == "remote" ]] || [[ "$arg" == "init" ]]; then
			convert_output=true;
		fi
		if [[ "$arg" == --*=* ]]; then
			prefix="${arg%%=*}";
			file_path="${arg#*=}";
			git_args[$argv]="${prefix}=$(to_unix_path_by_awk "$file_path")";
			argv=$(($argv+1));
			continue;
		fi
	fi
	[[ "$arg" == "--" ]] && after_double_dash=true;

	git_args[$argv]="$(to_unix_path_by_awk "$arg")";
	argv=$(($argv+1));
done

function execut_git() { git "${git_args[@]}" <&0; return $?; }
if [[ "$convert_output" == true ]]; then
	execut_git | to_win_path_by_awk;
else
	execut_git;
fi

exit $?;