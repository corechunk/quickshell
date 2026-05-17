#!/usr/bin/env bash

# Set some colors for output messages 
MAGENTA="$(tput setaf 5)"
ORANGE="$(tput setaf 214)"
RED="$(tput setaf 1)"
YELLOW="$(tput setaf 3)"
GREEN="$(tput setaf 2)"
BLUE="$(tput setaf 4)"
SKY_BLUE="$(tput setaf 6)"
RESET="$(tput sgr0)"

app="quickshell"
destDir="$HOME/.config/quickshell"
backupDir="$HOME/.config/.quickshell.backup.netchunk"

compareVersions() { # over engineered version comparison function :)
    # 1. Clean inputs: Strip 'v'/'V', all whitespace, tabs, and trailing newlines
    local ver1=$(echo "$1" | tr -d 'vV[:space:]')
    local ver2=$(echo "$2" | tr -d 'vV[:space:]')

    # If either version string ends up completely empty, return unknown
    if [[ -z "$ver1" || -z "$ver2" ]]; then
        echo "unknown"
        return
    fi

    # 2. Parse into arrays using '.' as the delimiter
    IFS='.' read -r -a v1_parts <<< "$ver1"
    IFS='.' read -r -a v2_parts <<< "$ver2"

    # 3. HEAVY-DUTY PADDING: Force both arrays to have exactly 4 elements (0 to 3)
    for i in {0..3}; do
        if [[ -z "${v1_parts[i]}" ]]; then
            v1_parts[i]=0
        fi
        if [[ -z "${v2_parts[i]}" ]]; then
            v2_parts[i]=0
        fi
    done

    # 4. Strict Directional Left-to-Right Traversal
    for i in {0..3}; do
        if (( v1_parts[i] < v2_parts[i] )); then
            # The destination version (v2) is larger -> An update is available!
			# action leads to left part [action is left directional] install/backup/restore
            case $i in
                0) echo "major update"; return ;;
                1) echo "minor update"; return ;;
                2) echo "patch update"; return ;;
                3) echo "hotfix update"; return ;;
            esac
        elif (( v1_parts[i] > v2_parts[i] )); then
            # The current version (v1) is larger -> Higher version already here!
            echo "downgrade"
            return
        fi
    done

    # If the loop finishes without returning, all parts matched perfectly
    echo "equal"
} # R.I.P my ADHD brain, this function is way too much for a simple version comparison, 

analyze() { # over engineered function to analyze version :)
					# creates global variables on the go installMsg/backupMsg/restoreMsg

	# 1. Read current directory version (Colored Green)
	if [[ -f ".version" ]]; then
		fileContent=$(cat ".version")
		version="${fileContent}"
	else
		version=""
	fi

	# 2. Read destination directory version (Colored Yellow)
	if [[ -f "$destDir/.version" ]]; then
		fileContent=$(cat "$destDir/.version")
		versionDest="${fileContent}"
	else
		versionDest=""
	fi

	# 3. Read backup directory version (Colored Blue)
	if [[ -f "$backupDir/.version" ]]; then
		fileContent=$(cat "$backupDir/.version")
		versionRestore="${fileContent}"
	else
		versionRestore=""
	fi

    # 1. Calculate underlying states using your raw text version variables
    local installStatus=$(compareVersions "$versionDest" "$version")
    local backupStatus=$(compareVersions "$versionRestore" "$versionDest") # backup action replaces backup version with live version
    local restoreStatus=$(compareVersions "$versionDest" "$versionRestore") # restore action replaces live version with backup version

    # 2. CRAFT INSTALLATION MESSAGES (Comparing Live Config vs Current Directory Script)
	case "$installStatus" in
        "major update")  installMsg=" ${RED}[ MAJOR UPDATE AVAILABLE: v$versionDest -> v$version ]${RESET}" ;;
        "minor update")  installMsg=" ${ORANGE}[ Minor update available: v$versionDest -> v$version ]${RESET}" ;;
        "patch update")  installMsg=" ${SKY_BLUE}[ Patch update available: v$versionDest -> v$version ]${RESET}" ;;
        "hotfix update") installMsg=" ${BLUE}[ Hotfix update available: v$versionDest -> v$version ]${RESET}" ;;
        "downgrade")     installMsg=" ${YELLOW}[ Local version (v$version) is older than live (v$versionDest) ]${RESET}" ;;
        "equal")         installMsg=" ${GREEN}[ Version tags are identical ]${RESET}" ;;
        *)               installMsg=" ${MAGENTA}[ Unknown version status ]${RESET}" ;;
    esac

    # 3. CRAFT BACKUP MESSAGES (Comparing Live Config vs Backup Directory)
    # If versionDest (live) is completely empty, it means there is no tracked live version
    if [[ -z "$versionDest" ]]; then
        backupMsg=" ${YELLOW}[ Untracked live config. Backup anyway to save your current dots ]${RESET}"
    else
        case "$backupStatus" in
            "major update"|"minor update"|"patch update"|"hotfix update") backupMsg=" ${ORANGE}[ Backup is STALE (v$versionRestore). Live config has newer updates (v$versionDest) ]${RESET}" ;;
            "downgrade")    backupMsg=" ${MAGENTA}[ Backup (v$versionRestore) contains a newer version than live (v$versionDest). maybe shouldn't backup, cux itll erase the newer version. procceed with caution. ]${RESET}" ;;
            "equal")        backupMsg=" ${GREEN}[ Backup is FRESH (Identical to live config) ]${RESET}" ;;
            *)              backupMsg=" ${RED}[ No backup found. Backup now before installing new dots! ]${RESET}" ;;
        esac
    fi

    # 4. CRAFT RESTORE MESSAGES (Comparing Live Config vs Backup Directory)
    # If versionRestore (backup) is completely empty, it means there is nothing to restore from
	if [[ -z "$versionRestore" ]]; then
        restoreMsg=" ${RED}[ No backup found to restore from ]${RESET}"
    elif [[ -z "$versionDest" ]]; then
        restoreMsg=" ${YELLOW}[ RESTORE: Overwriting untracked live config with backup (v$versionRestore) ]${RESET}"
    else
        case "$restoreStatus" in
            "major update")  restoreMsg=" ${RED}[ RESTORE: Will perform MAJOR upgrade (v$versionDest -> v$versionRestore) ]${RESET}" ;;
            "minor update")  restoreMsg=" ${ORANGE}[ RESTORE: Will perform Minor upgrade (v$versionDest -> v$versionRestore) ]${RESET}" ;;
            "patch update")  restoreMsg=" ${SKY_BLUE}[ RESTORE: Will perform Patch upgrade (v$versionDest -> v$versionRestore) ]${RESET}" ;;
            "hotfix update") restoreMsg=" ${BLUE}[ RESTORE: Will perform Hotfix upgrade (v$versionDest -> v$versionRestore) ]${RESET}" ;;
            "downgrade")     restoreMsg=" ${RED}[ Warning: Restoring will DOWNGRADE live config (v$versionDest -> v$versionRestore) ]${RESET}" ;;
            "equal")         restoreMsg=" ${BLUE}[ Backup is identical to live. No need to restore ]${RESET}" ;;
            *)               restoreMsg=" ${MAGENTA}[ Unknown version state. Restore with caution ]${RESET}" ;;
        esac
    fi
}

mkdir -p "$destDir"

command_exists(){
    command -v "$1" >/dev/null 2>&1
    return $?
}
package_manager(){
    if command_exists apt;then
        echo "apt"
    elif command_exists pacman;then
        echo "pacman"
    elif command_exists dnf;then
        echo "dnf"
    else
        echo "none"
    fi
}
check_sudo(){
    if sudo -n true 2>/dev/null; then
        has_sudo=1
    else
        has_sudo=0
    fi
}
install_pkg_dynamic(){
	check_sudo
	echo -e "\n$BLUE[Package] : $GREEN$1$RESET\n"
	if [[ $has_sudo -eq 0 ]]; then
	echo -e "You do NOT have sudo privileges. So, you are prompted for sudo password.\n$NOTE You'll not be asked for other packages if you use password correctly now"

	fi

    if   [[ $2 == default || -z $2 ]];then #1. Install if needed with prompt (no reinstall/default/safe)
        if   [[ $(package_manager) == "apt" ]];then
            sudo apt install "$1"
        elif [[ $(package_manager) == "pacman" ]];then
            sudo pacman -S "$1" --needed
        elif [[ $(package_manager) == "dnf" ]];then
            sudo dnf install "$1"
        fi
    elif [[ $2 == install-force ]];then #2. Install by force without prompt (no reinstall/default/safe)
        if   [[ $(package_manager) == "apt" ]];then
            sudo apt install "$1" -y
        elif [[ $(package_manager) == "pacman" ]];then
            sudo pacman -S "$1" --needed --noconfirm
        elif [[ $(package_manager) == "dnf" ]];then
            sudo dnf install "$1" -y
        fi
    else
        echo "invalid option for installation, ..."
        return 1;
    fi

    return 0;

}

dev_cp(){
    local src="."
    local dst="$destDir"

    mkdir -p "$dst"
    rm -rf "$dst"/.[!.]* "$dst"/..?* "$dst"/* 2>/dev/null

    # exclusions (like the rsync --exclude list)
    local excludes=( \
        "installer_${app}_dots.sh" \
        ".git" \
        ".gitignore" \
        "GEMINI.md" \
        "nohup.out" \
        "LICENSE" \
        "README.md" \
        ".version" \
    )

    # build --exclude args for tar
    local tar_excludes=()
    for e in "${excludes[@]}"; do
        tar_excludes+=( --exclude="$e" )
    done

    # use tar pipeline to copy while preserving attributes and applying excludes
    (cd "$src" 2>/dev/null && tar cf - "${tar_excludes[@]}" .) | (cd "$dst" && tar xpf -)
}
copy_dir(){  # rsync -af "$src"/. "$dst"/     #alternative
    local src="$1"
    local dst="$2"

    mkdir -p "$dst"
    rm -rf "$dst"/.[!.]* "$dst"/..?* "$dst"/* 2>/dev/null

    # exclusions (like the rsync --exclude list)
    local excludes=( \
        "installer_${app}_dots.sh" \
        ".git" \
        ".gitignore" \
        "GEMINI.md" \
        "nohup.out" \
        "LICENSE" \
        "README.md" \
    )

    # build --exclude args for tar
    local tar_excludes=()
    for e in "${excludes[@]}"; do
        tar_excludes+=( --exclude="$e" )
    done

    # use tar pipeline to copy while preserving attributes and applying excludes
    (cd "$src" 2>/dev/null && tar cf - "${tar_excludes[@]}" .) | (cd "$dst" && tar xpf -)
}

#install(){
#    rsync -af ./          $destDir/   --delete
#}
#backup(){
#    rsync -af $destDir/   $backupDir/ --delete
#}
#restore(){
#    rsync -af $backupDir/ $destDir/   --delete
#}

installApp(){
	# install app if doesnt exist
	command -v "$app" >/dev/null 2>&1 || {
		echo >&2 "app $app not found, installing..."
		install_pkg_dynamic "$app" "default"
	}
}
install(){
    copy_dir "." "$destDir"
}

backup(){
    copy_dir "$destDir" "$backupDir"
}

restore(){
    copy_dir "$backupDir" "$destDir"
}

dev_menu(){
    while true; do
		analyze
		echo "###################################"
		echo "##         ${MAGENTA}DEVELOPER MENU${RESET}"
		echo "##         Local:  v$version"
		echo "##         Config: v$versionDest"
		echo "##         Backup: v$versionRestore"
		echo "###################################"
        echo "1. hot copy without version note"
        echo "2. release with cp func to fully install"
        echo "x. Back to main menu"
        local input
        read -p "choose dev opt: " input
        case "$input" in
            "1")
                dev_cp
                echo -e "${GREEN}Hot copy completed (excluding .version)${RESET}"
            ;;
            "2")
                install
                echo -e "${GREEN}Full release install completed${RESET}"
            ;;
            "x"|"X")
                break
            ;;
        esac
    done
}

menu(){
    while true; do
		analyze # refreshes some vars that are used in the menu
		echo "###################################"
		echo "##         ${BLUE}corechunk${RESET}/$app"
		echo "##         version: $version"
		echo "##         Quickshell Installer"
		echo "###################################"
        echo "0. install $app"
        echo "1. install modules${installMsg}"
        echo "2. backup  modules${backupMsg}"
        echo "3. restore modules${restoreMsg}"
        echo "x. Exit"
        local input
        read -p "choose opt: " input
        case "$input" in
            "0")
                installApp
            ;;
            "1")
                install
            ;;
            "2")
                backup
            ;;
            "3")
                restore
            ;;
            "x"|"X")
                break
            ;;
        esac
    done
}


if [[ -z $1 ]]; then
    menu
else # for silent execution with arg, no prompt, no menu
    case "$1" in
        "dev")
            dev_menu
        ;;
        "backup+install+app")
            installApp  # not for nix users
            backup
            install
        ;;
        "backup+install")
            backup   # for users who already have the app installed and just want to backup old config and install new one
            install
        ;;
        "installForce")
            install   # for users who just want to install new config without backup, and dont care about old config
        ;;
        "backup")
            backup
        ;;
        "restore")
            restore
        ;;
        *)
            echo "Usage: $0 [dev|backup+install+app|backup+install|installForce|backup|restore|dev]"
            exit 1
        ;;
    esac
fi

