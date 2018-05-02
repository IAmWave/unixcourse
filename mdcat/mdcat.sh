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
    if [[ "$n" -le 0 ]]; then
        return
    fi
    printf "$c%.0s" $(seq 1 $2)
}

get_header_level() {
    # Print the level of the header on this line.
    for i in {6..1}; do
        if echo "$1" | grep -q $(repeat_char '#' $i); then
            echo $i
            return
        fi
    done
    echo 0
}

count_leading_chars() {
    # Given a string s and a character c, print how many occurrences
    # of c there are at the beginning of s
    echo "$1" | awk -F'[^'"$2"']' '{print length($1)}'
}

is_list_item() {
    # Return 0 if the given line is a list item,
    # that is, it starts with '- ' (+ possibly leading whitespace)
    echo "$1" | grep -qP "^\s*\- "
    return $?
}

font_styles() {
    # Process font styles (bold, italics, code) in a line.
    para=$1
    # echo $para | sed 's/\*\*\([^\*]*\)\*\*/'${bold}${under}'\1'$normal'/g'
    lines=$(echo "$para" | sed '
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
            res+=$(printf -- "${line}") # -- so that there is no formatting
        fi
    done <<< "$lines"

    echo "$res${s_reset}"
}

process_paragraph() {
    para=$1
    para=$(trim "$para")
    para=$(font_styles "$para")
    para=$(echo "$para" | sed '
    s/  */ /g # Join consecutive spaces into one
    ')
    echo "$para"
}

process_header() {
    # Format headers, that is, lines beginning with some number of '#'s.
    # Headers are formatted as ==== text ====, where the number of '='s
    # DECREASES with the importance of the header (this is in contrast
    # to Markdown but seems more intuitive).
    level=$(get_header_level "$1")
    header=$(trim "$1")

    if [[ $level != 0 ]]; then
        decoration="${s_bold}"$(repeat_char '=' $((7-level)))"${s_reset}"
        trimmed=$(echo "$header" | sed 's/^#* *//g')
        echo "$decoration $trimmed $decoration"
    else
        echo "$1"
    fi
}

process_list() {
    # Format lists. Indent levels are standardized, the only thing that matters
    # is their relative size.
    list="$1"
    indents=(-1) # Dummy negative indentation to avoid an empty stack
    while IFS= read line; do
        indent=$(count_leading_chars "$line" " ")
        # We keep a stack of indent sizes and pop it so that it is strictly increasing
        while [[ "$indent" -le "${indents[-1]}" ]]; do
            indents=("${indents[@]::${#indents[@]}-1}")
        done
        indents+=($indent)
        stack_size="${#indents[@]}"
        indent_level=$((1 + (stack_size - 2) * 4))
        processed_line=$(echo "${line}" | sed 's/^\( *\)-/\1•/') # Bullets instead of '-'s
        processed_line=$(process_paragraph "${processed_line}")
        echo "$(repeat_char ' ' $indent_level )${processed_line}"
    done <<< "$list"
}

process_block() {
    # Process one whole block: a PARAGRAPH/HEADER/LIST
    block="$1"
    block_type="$2"
    if [[ -z $(trim "$block") ]]; then # Skip empty blocks
        return
    fi
    # Use a single * for bold and a single _ for italics
    block=$(echo "$block" | sed 's/*/_/g; s/__/*/g')
    if [[ "$block_type" = "LIST" ]]; then
        block=$(process_list "$block")
    elif [[ "$block_type" = "HEADER" ]]; then
        block=$(process_header "$block")
    elif [[ "$block_type" = "PARAGRAPH" ]]; then
        block=$(process_paragraph "$block")
    fi

    echo "$block"
    echo ""
}

block_type="PARAGRAPH" # PARAGRAPH/HEADER/LIST
cur=""
while IFS= read line; do # Do not trim whitespace
    if [[ -z "$line" ]]; then # Empty line
        process_block "$cur" "$block_type"
        cur=""
        block_type="PARAGRAPH"
    elif [[ $(get_header_level "$line") != 0 ]]; then # Header
        # Flush `cur`; headers are one-line only.
        process_block "$cur" "$block_type"
        cur="${line}"
        block_type="HEADER"
    elif is_list_item "$line"; then # List item
        if [[ "$block_type" != "LIST" ]]; then # There may be a paragraph block before a list
            process_block "$cur" "$block_type"
            cur="${line}"
            block_type="LIST"
        else
            cur="${cur}"$'\n'"${line}"
        fi
    else # None of the above
        if [[ "$block_type" = "LIST" ]]; then # Continuation of a list item on another line
            cur="${cur} ${line}"
        elif [[ "$block_type" != "PARAGRAPH" ]]; then # Divide between types; flush
            process_block "$cur" "$block_type"
            cur="${line}"
            block_type="PARAGRAPH"
        else # Continuation of a paragraph
            cur="${cur} ${line}"
        fi
    fi
done

process_block "$cur" "$block_type"
