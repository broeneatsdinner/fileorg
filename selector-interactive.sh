#!/usr/bin/env bash
# -----------------------------------
# --    selector-interactive.sh    --
# -----------------------------------

# Arrow key/Enter menu in shell
# https://unix.stackexchange.com/questions/146570/arrow-key-enter-menu

# Pass back a string from a function
# https://stackoverflow.com/questions/3236871/how-to-return-a-string-value-from-a-bash-function

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
function select_option {

	# little helpers for terminal print control and key input
	local ESC
	ESC=$(printf "\033")
	cursor_blink_on()  { printf '%s' "${ESC}[?25h"; }
	cursor_blink_off() { printf '%s' "${ESC}[?25l"; }
	cursor_up()        { printf '%s' "${ESC}[$1A"; }
	clear_line()       { printf '%s' "${ESC}[2K"; }
	print_option()     { printf '   %s ' "$1"; }
	print_selected()   { printf '  %s %s %s' "${ESC}[7m" "$1" "${ESC}[27m"; }
	selector_cleanup() {
		cursor_blink_on
		printf '\n'
	}
	selector_interrupt() {
		selector_cleanup
		trap - INT
		return 130
	}
	key_input() {
		local key
		local rest

		if [[ -n "${ZSH_VERSION:-}" ]]; then
			IFS= read -r -s -k 1 key </dev/tty

			if [[ "$key" == "$ESC" ]]; then
				IFS= read -r -s -t 0.1 -k 2 rest </dev/tty || rest=""
				key="${key}${rest}"
			fi
		else
			read -r -s -n3 key 2>/dev/null >&2
		fi

		if [[ "$key" == "${ESC}[A" ]]; then printf '%s\n' up; fi
		if [[ "$key" == "${ESC}[B" ]]; then printf '%s\n' down; fi
		if [[ "$key" == "q" || "$key" == "Q" ]]; then printf '%s\n' cancel; fi
		if [[ "$key" == "$ESC" ]]; then printf '%s\n' cancel; fi
		if [[ -z "$key" || "$key" == $'\n' || "$key" == $'\r' ]]; then printf '%s\n' enter; fi
	}

	# initially print empty new lines (scroll down if at bottom of screen)
	for opt; do printf "\n"; done

	# Keep the cursor visible if the selector is interrupted during input.
	trap selector_interrupt INT
	cursor_blink_off

	local option_count=$#
	local selected=0
	while true; do
		# Redraw the reserved option lines without asking the terminal for its
		# cursor position. ESC[6n responses can leak visibly in real terminals.
		cursor_up "$option_count"
		local idx=0
		for opt; do
			printf '\r'
			clear_line
			if [ $idx -eq $selected ]; then
				print_selected "$opt"
			else
				print_option "$opt"
			fi
			printf '\n'
			((idx++))
		done

		# user key control
		case "$(key_input)" in
			enter) break;;
			cancel)
				selected=130
				break
				;;
			up)    ((selected--));
				   if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi;;
			down)  ((selected++));
				   if [ $selected -ge $# ]; then selected=0; fi;;
		esac
	done

	selector_cleanup
	trap - INT

	return $selected
}

# echo "Select one option using up/down keys and enter to confirm:"
# echo

# options=("one" "two" "three")

# select_option "${options[@]}"
# choice=$?

# echo "Choosen index = $choice"
# echo "        value = ${options[$choice]}"

function select_opt {
	select_option "$@" 1>&2
	local result=$?
	printf '%s\n' "$result"
	return $result
}

# case "$(select_opt "Yes" "No" "Cancel")" in
#     0) echo "selected Yes";;
#     1) echo "selected No";;
#     2) echo "selected Cancel";;
# esac

# options=("Yes" "No" "${array[@]}") # join arrays to add some variable array
# case "$(select_opt "${options[@]}")" in
# 	0) echo "selected Yes";;
# 	1) echo "selected No";;
# 	*) echo "selected ${options[$?]}";;
# esac

keyboard_select()
{
	local options=("$@")
	local selected
	local selected_index
	local selected_status

	selected="$(select_opt "${options[@]}")"
	selected_status=$?
	if [[ $selected_status -eq 130 ]]; then
		return 130
	fi

	if [[ -n "${ZSH_VERSION:-}" ]]; then
		selected_index=$((selected + 1))
	else
		selected_index=$selected
	fi

	keyboard_select_response="${options[$selected_index]}"
	return 0
}

# options=(
# "one"
# "two"
# "three"
# )

# echo "Select one option using up/down keys and enter to confirm:"
# echo
# keyboard_select "${options[@]}" # Sets $keyboard_select variable
# echo "you are the bomb $keyboard_select_response"
