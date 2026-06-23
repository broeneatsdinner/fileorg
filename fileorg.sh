#!/usr/bin/env zsh
# -------------------
# --    fileorg    --
# -------------------

# description: Build file match lists and organize files into a new folder.

# fileorg.sh
#
# Run this from the directory you want to work on, for example:
#	cd ~/Downloads
#	fileorg
#
# This script operates on the current working directory, not the script's
# own install location.
#
# Word-list files:
#	- fileorg-word-list*.txt
#	- The menu can create fileorg-word-list-<name>.txt from comma-separated
#	  search terms.
#	- Existing word lists are selected with selector-interactive.sh before
#	  generating or reviewing a matching file.
#
# Generated output files:
#	- fileorg-matching-files.txt
#	- fileorg-matching-files-<word-list-suffix>.txt
#	- If the generated name already exists, the script preserves existing files
#	  by creating fileorg-matching-files-<suffix>-2.txt,
#	  fileorg-matching-files-<suffix>-3.txt, etc.
#
# Workflow:
#	1. Create a new word list from scratch or maintain fileorg-word-list*.txt
#	   files with one search string per line
#	2. View or edit existing word lists selected with selector-interactive.sh
#	3. Generate a suffix-aware fileorg-matching-files*.txt list from an
#	   existing word list selected with selector-interactive.sh
#	4. Match files in the current directory using the selected word list
#	5. For this first version, order generated matches by macOS Date Added when
#	   available, falling back to file birth time or filename
#	6. View or edit generated matching files selected with selector-interactive.sh
#	7. Run the organizer against a selector-chosen matching file
#
# Organizer safety behavior:
#	- Organizer mode defaults to a dry run.
#	- In dry-run mode, the script only prints what it would do.
#	- No files are moved unless you explicitly choose force mode.
#	- Blank lines in word-list files are ignored.
#	- Blank lines in the matching file are ignored.
#	- Lines in the matching file that do not point to a valid regular file are ignored.
#	- The destination subdirectory must not already exist.
#	- The destination subdirectory is created under the current working directory.

setopt local_options no_nomatch

SCRIPT_DIR="${0:A:h}"
SELECTOR_FILE="${SCRIPT_DIR}/selector-interactive.sh"
STANDARDS_SHELL_DIR="${STANDARDS_SHELL_DIR:-$HOME/Documents/Git/standards/shell}"
WORD_LIST_BASE="fileorg-word-list"
MATCH_FILE_BASE="fileorg-matching-files"
MATCH_FILE_EXT=".txt"
MAIN_MENU_STATUS="Ready."
MAIN_MENU_BODY=""

if [[ -f "$STANDARDS_SHELL_DIR/colors.sh" ]]; then
	source "$STANDARDS_SHELL_DIR/colors.sh" 2>/dev/null || true
fi

: "${ACID_BLUE:=}"
: "${ACID_GREEN:=}"
: "${WARNING:=}"
: "${ERROR:=}"
: "${RESET:=}"

color_path() {
	printf '%s%s%s' "$ACID_BLUE" "$1" "$RESET"
}

color_value() {
	printf '%s%s%s' "$ACID_GREEN" "$1" "$RESET"
}

color_warning() {
	printf '%s%s%s' "$WARNING" "$1" "$RESET"
}

color_error() {
	printf '%s%s%s' "$ERROR" "$1" "$RESET"
}

if [[ ! -f "$SELECTOR_FILE" ]]; then
	printf '%s selector-interactive.sh not found next to fileorg.sh: %s\n' "$(color_error "Error:")" "$(color_path "$SELECTOR_FILE")" >&2
	exit 1
fi

source "$SELECTOR_FILE"

handle_interrupt() {
	printf '\n%s\n' "$(color_warning "Cancelled.")" >&2
	exit 130
}

install_interrupt_trap() {
	trap handle_interrupt INT
}

is_cancel_choice() {
	[[ "$1" == "q" || "$1" == "Q" || "$1" == $'\e' ]]
}

show_usage() {
	cat << EOF
Usage:
	fileorg
	fileorg --view-list
	fileorg --edit-list
	fileorg --build-list
	fileorg --view-matches
	fileorg --edit-matches
	fileorg --organize
	fileorg --organize --force
	fileorg --dry-run
	fileorg -h
	fileorg --help
EOF
}

set_main_menu_status() {
	MAIN_MENU_STATUS="$1"
}

set_main_menu_body() {
	MAIN_MENU_BODY="$1"
}

clear_main_menu_body() {
	MAIN_MENU_BODY=""
}

show_main_menu_screen() {
	printf '\033[H\033[2J'
	printf '\n'
	printf 'fileorg - current directory: %s\n' "$(color_path "$PWD")"
	printf 'Status: %s\n' "$MAIN_MENU_STATUS"
	printf '\n'

	if [[ -n "$MAIN_MENU_BODY" ]]; then
		printf '%s\n\n' "$MAIN_MENU_BODY"
	fi
}

next_numbered_file() {
	local base="$1"
	local n=1
	local candidate

	candidate="${base}${MATCH_FILE_EXT}"
	if [[ ! -e "$candidate" ]]; then
		printf '%s\n' "$candidate"
		return
	fi

	n=2
	while true; do
		candidate="${base}-${n}${MATCH_FILE_EXT}"
		if [[ ! -e "$candidate" ]]; then
			printf '%s\n' "$candidate"
			return
		fi
		((n++))
	done
}

word_list_suffix() {
	local word_list_file="$1"
	local suffix

	suffix="${word_list_file#${WORD_LIST_BASE}}"
	suffix="${suffix%.txt}"
	suffix="${suffix#-}"

	printf '%s\n' "$suffix"
}

match_file_base_for_word_list() {
	local word_list_file="$1"
	local suffix

	suffix="$(word_list_suffix "$word_list_file")"
	if [[ -n "$suffix" ]]; then
		printf '%s-%s\n' "$MATCH_FILE_BASE" "$suffix"
	else
		printf '%s\n' "$MATCH_FILE_BASE"
	fi
}

next_match_file() {
	local word_list_file="$1"
	local match_file_base

	match_file_base="$(match_file_base_for_word_list "$word_list_file")"
	next_numbered_file "$match_file_base"
}

select_from_files() {
	local prompt="$1"
	shift

	printf '%s\n\n' "$prompt" >&2
	keyboard_select "$@" || {
		install_interrupt_trap
		printf '%s\n' "$(color_warning "Cancelled.")" >&2
		return 130
	}
	install_interrupt_trap
	printf '%s\n' "$keyboard_select_response"
}

create_word_list() {
	local suffix
	local terms_line
	local word_list_file
	local term
	local terms

	while true; do
		printf 'Enter word-list name suffix: ' >&2
		read -r suffix

		if is_cancel_choice "$suffix"; then
			printf '%s\n' "$(color_warning "Cancelled.")" >&2
			return 130
		fi

		if [[ -z "$suffix" ]]; then
			printf '%s\n' "$(color_warning "Word-list suffix cannot be blank.")" >&2
			continue
		fi

		if [[ "$suffix" == *[!A-Za-z0-9_-]* ]]; then
			printf '%s\n' "$(color_warning "Use only letters, numbers, underscores, and hyphens.")" >&2
			continue
		fi

		word_list_file="${WORD_LIST_BASE}-${suffix}.txt"
		if [[ -e "$word_list_file" ]]; then
			printf '%s %s\n' "$(color_warning "That word-list file already exists:")" "$(color_path "$word_list_file")" >&2
			continue
		fi

		break
	done

	while true; do
		printf 'Enter comma-separated search terms: ' >&2
		read -r terms_line

		if is_cancel_choice "$terms_line"; then
			printf '%s\n' "$(color_warning "Cancelled.")" >&2
			return 130
		fi

		terms=()
		for term in "${(@s:,:)terms_line}"; do
			term="${term#"${term%%[![:space:]]*}"}"
			term="${term%"${term##*[![:space:]]}"}"
			[[ -z "$term" ]] && continue
			terms+=("$term")
		done

		if (( ${#terms[@]} == 0 )); then
			printf '%s\n' "$(color_warning "At least one search term is required.")" >&2
			continue
		fi

		break
	done

	printf '%s\n' "${terms[@]}" > "$word_list_file" || return 1
	printf '%s word-list file: %s\n' "$(color_value "Created")" "$(color_path "$word_list_file")" >&2
	printf '%s\n' "$word_list_file"
}

select_existing_word_list() {
	local word_list_files

	word_list_files=(${WORD_LIST_BASE}*.txt(N.))

	if (( ${#word_list_files[@]} == 0 )); then
		printf 'No %s*.txt files found in current directory: %s\n' "$(color_path "$WORD_LIST_BASE")" "$(color_path "$PWD")" >&2
		printf '%s\n' "$(color_warning "Use option 1 to create a new word list first.")" >&2
		return 1
	fi

	select_from_files "Choose word list to use:" "${word_list_files[@]}"
}

select_match_file() {
	local match_files
	local prompt="${1:-Choose matching file to organize:}"

	match_files=(${MATCH_FILE_BASE}*.txt(N.))

	if (( ${#match_files[@]} == 0 )); then
		printf '%s no %s*.txt file found in current directory: %s\n' "$(color_error "Error:")" "$(color_path "$MATCH_FILE_BASE")" "$(color_path "$PWD")" >&2
		return 1
	fi

	select_from_files "$prompt" "${match_files[@]}"
}

date_added_sort_key() {
	local file="$1"
	local date_added
	local birth_time

	if command -v mdls >/dev/null 2>&1; then
		date_added="$(mdls -raw -name kMDItemDateAdded -- "$file" 2>/dev/null)"
		if [[ -n "$date_added" && "$date_added" != "(null)" && "$date_added" != "null" ]]; then
			printf '0:%s\n' "$date_added"
			return
		fi
	fi

	if birth_time="$(stat -f '%B' -- "$file" 2>/dev/null)" && [[ "$birth_time" != "0" && "$birth_time" != "-1" ]]; then
		printf '1:%s\n' "$birth_time"
		return
	fi

	printf '2:%s\n' "$file"
}

print_date_added_ordered_files() {
	local file
	local sort_key

	for file in "$@"; do
		sort_key="$(date_added_sort_key "$file")"
		printf '%s\t%s\n' "$sort_key" "$file"
	done | sort -t '	' -k1,1 -k2,2 | cut -f2-
}

build_list() {
	local out_file
	local word_list_file="$1"
	local clean_word_list
	local files
	local matched_files

	if [[ ! -f "$word_list_file" ]]; then
		printf '%s selected word-list file not found: %s\n' "$(color_error "Error:")" "$(color_path "$word_list_file")" >&2
		return 1
	fi

	out_file="$(next_match_file "$word_list_file")"
	clean_word_list="$(mktemp -t fileorg-word-list.XXXXXX)" || return 1
	grep -v '^[[:space:]]*$' "$word_list_file" > "$clean_word_list"

	printf 'Using word-list file: %s\n' "$(color_path "$word_list_file")"
	printf 'Generating %s in: %s\n' "$(color_path "$out_file")" "$(color_path "$PWD")"

	files=(*(.N))
	if (( ${#files[@]} == 0 )); then
		: > "$out_file"
	else
		matched_files=("${(@f)$(printf '%s\n' "${files[@]}" | grep -iFf "$clean_word_list")}")
		if (( ${#matched_files[@]} == 1 )) && [[ -z "${matched_files[1]}" ]]; then
			matched_files=()
		fi
		print_date_added_ordered_files "${matched_files[@]}" > "$out_file"
	fi

	rm -f -- "$clean_word_list"

	printf '%s Review/edit %s before organizing files.\n' "$(color_value "Done.")" "$(color_path "$out_file")"
}

create_and_build_list() {
	local word_list_file

	word_list_file="$(create_word_list)" || return $?
	build_list "$word_list_file"
}

build_list_from_existing_word_list() {
	local word_list_file

	word_list_file="$(select_existing_word_list)" || return $?
	build_list "$word_list_file"
}

print_word_list() {
	local word_list_file="$1"

	printf 'Word-list file: %s\n' "$(color_path "$word_list_file")"
	awk '{ printf "%6d  %s\n", NR, $0 }' "$word_list_file"
}

print_match_file() {
	local match_file="$1"

	printf 'Matching-files list: %s\n' "$(color_path "$match_file")"
	awk '{ printf "%6d  %s\n", NR, $0 }' "$match_file"
}

edit_text_file() {
	local file="$1"
	local editor
	local -a editor_cmd

	editor="${VISUAL:-${EDITOR:-/usr/bin/nano}}"
	editor_cmd=("${(@z)editor}")

	"${editor_cmd[@]}" "$file"
}

view_existing_word_list() {
	local word_list_file

	word_list_file="$(select_existing_word_list)" || return $?
	print_word_list "$word_list_file"
}

edit_existing_word_list() {
	local word_list_file

	word_list_file="$(select_existing_word_list)" || return $?

	printf 'Editing word-list file: %s\n' "$(color_path "$word_list_file")"
	edit_text_file "$word_list_file" || return $?
	print_word_list "$word_list_file"
}

view_existing_match_file() {
	local match_file

	match_file="$(select_match_file "Choose matching-files list to view:")" || return $?
	print_match_file "$match_file"
}

edit_existing_match_file() {
	local match_file

	match_file="$(select_match_file "Choose matching-files list to edit:")" || return $?

	printf 'Editing matching-files list: %s\n' "$(color_path "$match_file")"
	edit_text_file "$match_file" || return $?
	print_match_file "$match_file"
}

prompt_for_destination_dir() {
	local dest_dir

	while true; do
		printf 'Enter destination subdirectory name to create under %s: ' "$PWD" >&2
		read -r dest_dir

		if is_cancel_choice "$dest_dir"; then
			printf '%s\n' "$(color_warning "Cancelled.")" >&2
			return 130
		fi

		if [[ -z "$dest_dir" ]]; then
			printf '%s\n' "$(color_warning "Destination name cannot be blank.")" >&2
			continue
		fi

		if [[ "$dest_dir" == "." || "$dest_dir" == ".." ]]; then
			printf '%s\n' "$(color_warning "Please choose a real subdirectory name.")" >&2
			continue
		fi

		if [[ "$dest_dir" == /* ]]; then
			printf '%s\n' "$(color_warning "Please enter a relative subdirectory name, not an absolute path.")" >&2
			continue
		fi

		if [[ -e "$dest_dir" ]]; then
			printf '%s %s\n' "$(color_warning "That path already exists:")" "$(color_path "$dest_dir")" >&2
			printf '%s\n' "$(color_warning "Choose another destination name.")" >&2
			continue
		fi

		printf '%s\n' "$dest_dir"
		return
	done
}

organize_files() {
	local force="$1"
	local match_file
	local file
	local dest_dir
	local target_path

	match_file="$(select_match_file)" || return $?
	printf 'Using matching file: %s\n' "$(color_path "$match_file")"

	dest_dir="$(prompt_for_destination_dir)" || return $?

	if (( ! force )); then
		printf 'Running in %s mode against: %s\n' "$(color_warning "dry-run")" "$(color_path "$match_file")"
		printf 'Would create destination directory: %s\n' "$(color_path "$dest_dir")"
	else
		mkdir -p -- "$dest_dir" || return 1
		[[ -d "$dest_dir" ]] || return 1
		printf '%s destination directory: %s\n' "$(color_value "Created")" "$(color_path "$dest_dir")"
	fi

	while IFS= read -r file; do
		[[ -z "$file" ]] && continue
		[[ ! -f "$file" ]] && continue

		target_path="${dest_dir}/${file:t}"

		if [[ -e "$target_path" ]]; then
			if (( ! force )); then
				printf 'Would skip (target exists): %s -> %s\n' "$(color_path "$file")" "$(color_path "$target_path")"
			else
				printf '%s %s -> %s\n' "$(color_warning "Skipping (target exists):")" "$(color_path "$file")" "$(color_path "$target_path")"
			fi
			continue
		fi

		if (( ! force )); then
			printf 'Would move: %s -> %s/\n' "$(color_path "$file")" "$(color_path "$dest_dir")"
			continue
		fi

		mv -- "$file" "$dest_dir/" || return 1
		printf '%s %s -> %s/\n' "$(color_value "Moved:")" "$(color_path "$file")" "$(color_path "$dest_dir")"

	done < "$match_file"
}

show_menu() {
	local word_list_files
	local word_list_file
	local word_list_count

	show_main_menu_screen

	word_list_files=(${WORD_LIST_BASE}*.txt(N.))
	word_list_count=${#word_list_files[@]}

	printf '1) Start a new word list from scratch\n'
	printf '2) View an existing word list\n'
	printf '3) Edit an existing word list\n'
	printf '4) Generate a new %s*.txt from an existing word list\n' "$(color_path "$MATCH_FILE_BASE")"
	if (( word_list_count == 1 )); then
		printf '     1 word list found:\n'
	elif (( word_list_count == 0 )); then
		printf '     0 word lists found:\n'
	else
		printf '     %d word lists found:\n' "$word_list_count"
	fi
	if (( word_list_count == 0 )); then
		printf '       [none]\n'
	else
		for word_list_file in "${word_list_files[@]}"; do
			printf '       %s\n' "$(color_path "$word_list_file")"
		done
	fi
	printf '5) View an existing %s*.txt\n' "$(color_path "$MATCH_FILE_BASE")"
	printf '6) Edit an existing %s*.txt\n' "$(color_path "$MATCH_FILE_BASE")"
	printf '7) Choose a %s*.txt file to move files into a new subdirectory\n' "$(color_path "$MATCH_FILE_BASE")"
	printf '8) Quit\n'
	printf '\n'
	printf 'Choose an option: '
}

main() {
	local arg1="${1:-}"
	local arg2="${2:-}"
	local choice
	local force=0
	local created_word_list
	local word_list_name
	local word_list_output
	local match_file_name
	local match_output

	install_interrupt_trap

	case "$arg1" in
		--view-list)
			view_existing_word_list
			return
			;;
		--edit-list)
			edit_existing_word_list
			return
			;;
		--build-list)
			build_list_from_existing_word_list
			return
			;;
		--view-matches)
			view_existing_match_file
			return
			;;
		--edit-matches)
			edit_existing_match_file
			return
			;;
		--organize)
			if [[ "$arg2" == "--force" ]]; then
				organize_files 1
				return
			else
				organize_files 0
				return
			fi
			;;
		--dry-run)
			organize_files 0
			return
			;;
		-h|--help)
			show_usage
			return
			;;
		'')
			;;
		*)
			show_usage >&2
			return 1
			;;
	esac

	while true; do
		show_menu
		read -r choice

		case "$choice" in
			q|Q|$'\e')
				printf 'Exiting.\n'
				return
				;;
			1)
				created_word_list="$(create_word_list)" || return $?
				set_main_menu_status "Created word list ${created_word_list}."
				set_main_menu_body "Created word-list file: ${created_word_list}"
				continue
				;;
			2)
				word_list_output="$(view_existing_word_list)" || return $?
				word_list_name="${word_list_output%%$'\n'*}"
				word_list_name="${word_list_name#Word-list file: }"
				set_main_menu_status "Viewed word list ${word_list_name}."
				set_main_menu_body "$word_list_output"
				continue
				;;
			3)
				word_list_output="$(edit_existing_word_list)" || return $?
				set_main_menu_status "Edited word list."
				set_main_menu_body "$word_list_output"
				continue
				;;
			4)
				match_output="$(build_list_from_existing_word_list)" || return $?
				set_main_menu_status "Generated matching-files list."
				set_main_menu_body "$match_output"
				continue
				;;
			5)
				match_output="$(view_existing_match_file)" || return $?
				match_file_name="${match_output%%$'\n'*}"
				match_file_name="${match_file_name#Matching-files list: }"
				set_main_menu_status "Viewed matching-files list ${match_file_name}."
				set_main_menu_body "$match_output"
				continue
				;;
			6)
				match_output="$(edit_existing_match_file)" || return $?
				set_main_menu_status "Edited matching-files list."
				set_main_menu_body "$match_output"
				continue
				;;
			7)
				printf 'Run organizer in dry-run mode or with force mode? [dry-run/force, default: dry-run]: '
				read -r choice

				case "$choice" in
					q|Q|$'\e')
						printf '%s\n' "$(color_warning "Cancelled.")" >&2
						return 130
						;;
					force)
						force=1
						;;
					dry-run|'')
						force=0
						;;
					*)
						printf '%s\n' "$(color_error "Invalid choice.")" >&2
						return 1
						;;
				esac

				organize_files "$force"
				set_main_menu_status "Organizer completed."
				clear_main_menu_body
				return
				;;
			8)
				printf 'Exiting.\n'
				return
				;;
			*)
				printf '%s\n' "$(color_error "Invalid choice.")"
				;;
		esac
	done
}

main "$@"
