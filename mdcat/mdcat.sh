#!/bin/bash

# Formatting sequences
s_bold=$(tput bold)
s_reset=$(tput sgr0)
s_italics=$(tput smul)
s_code=$(tput setaf 3)

trim() {
    # Omit leading and trailing whitespace
    echo "$1" | sed 's/^ *//;s/ $//'
}

repeat_char() {
    # Given a char c and number n, returns the string ccccccc (c repeated n times)
    c=$1
    n=$2
    printf "$c%.0s" $(seq 1 $2)
}

header_level() {
    # Print the level of the header on this line.
    for i in {6..1}; do
        if echo "$1" | grep -q $(repeat_char '#' $i); then
            echo $i
            return
        fi
    done
    echo 0
}

font_styles() {
    # Process font styles (bold, italics, code) in a line.
    para=$1
    # echo $para | sed 's/\*\*\([^\*]*\)\*\*/'${bold}${under}'\1'$normal'/g'
    lines=$(echo "$para" | sed '
    # s/*/_/g; s/__/*/g       # Use a single * for bold and a single _ for italics
    s/\(*\|_\|`\)/\n\1\n/g     # Split paragraph into lines, where "keywords" are on separate lines
    ')

    # Which styles are active?
    bold=0
    italics=0
    code=0

    res=""
    while IFS= read line; do # Clear IFS so that `read` doesn't trim whitespace
        if [[ -z "$line" ]]; then
            : # Skip empty Lines
        elif [[ "$line" = '*' ]]; then
            (( bold = 1 - bold ))
        elif [[ "$line" = '_' ]]; then
            (( italics = 1 - italics ))
        elif [[ "$line" = '`' ]]; then
            (( code = 1 - code ))
        else
            res+=$(printf "${s_reset}")
            # Todo: do not highlight in inline code blocks
            if [[ "$code" = 1 ]]; then res+=$(printf "${s_code}"); fi
            if [[ "$bold" = 1 ]];    then res+=$(printf "${s_bold}"); fi
            if [[ "$italics" = 1 ]]; then res+=$(printf "${s_italics}"); fi
            
            res+=$(printf "${line}")

        fi
    done <<< "$lines"

    echo "$res"
}

headers() {
    # Format headers, that is, lines beginning with some number of '#'s.
    # Headers are formatted as ==== text ====, where the number of '='s
    # DECREASES with the importance of the header (this is in contrast
    # to Markdown but seems more intuitive).
    level=$(header_level "$1")

    if [[ $level != 0 ]]; then
        decoration="${s_bold}"$(repeat_char '=' $((7-level)))"${s_reset}"
        trimmed=$(echo "$1" | sed 's/^#* *//g')
        echo "$decoration $trimmed $decoration"
    else
        echo "$1"
    fi
}

process_block() {
    # Process the whole block
    para=$(trim "$1")
    if [[ -z $para ]]; then # Skip empty blocks
        return
    fi
    # Use a single * for bold and a single _ for italics
    para=$(echo "$para" | sed 's/*/_/g; s/__/*/g')

    para=$(headers "$para")
    para=$(font_styles "$para")
    echo "$para"
    echo ""
}

block_type="PARAGRAPH" # paragraph/header
cur=""
while read line; do
    if [[ -z "$line" ]]; then # Empty line
        process_block "$cur"
        cur=""
        block_type="PARAGRAPH"
    elif [[ $(header_level "$line") != 0 ]]; then # Header
        process_block "$cur"
        cur="${line}"
        block_type="HEADER"
    else # Not an empty line - paragraph
        # Divide between types
        if [[ "$block_type" != "PARAGRAPH" ]]; then
            process_block "$cur"
            cur=""
        fi
        cur="${cur} ${line}"
        block_type="PARAGRAPH"
    fi
done

process_block "$cur"
