#!/bin/bash

# Formatting sequences
s_bold=$(tput bold)
s_reset=$(tput sgr0)
s_italics=$(tput smul)
s_code=$(tput setaf 3) # Yellow
s_link=$(tput setaf 6) # Cyan

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
    # Print the level of the header on this line (number of leading #s)
    for i in {6..1}; do
        if echo "$1" | grep -q ^$(repeat_char '#' $i); then
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
    # Return 0 iff the given line is a list item,
    # that is, it starts with '- ' or '* ' (+ possibly leading whitespace)
    echo "$1" | grep -qP "^\s*[\-*] "
    return $?
}

is_code_block_separator() {
    # Return 0 if the given line is the start or end of a code block,
    # that is, it starts with '```'
    echo "$1" | grep -qP "^\`\`\`"
    return $?
}

font_styles() {
    # Process font styles (bold, italics, code) in a line or paragraph. Markdown markup
    # is converted into ANSI escape sequences.
    para=$1
    lines=$(echo "$para" |
        sed 's/\(*\|_\|`\|\[\)/'$'\e''\1'$'\e''/g' | # Split paragraph into \e-delimited tokens
        tr '\n' '\t')   # Use \t instead of \n so that we can use a single `read`
                        # if the input is multi-line

    # Which styles are active?
    bold=0
    italics=0
    code=0
    link=0

    # Read the \e-delimited string into array `tokens`
    IFS=$'\e' read -a tokens <<< "${lines}"
    res=""
    for token in "${tokens[@]}"; do
        if [[ -z "$token" ]]; then
            continue # Skip empty lines
        fi
        if [[ "$code" = 1 ]]; then
            # Code is not highlighted; special tokens like _ are printed literally
            if [[ "$token" = '`' ]]; then
                (( code = 1 - code ))
            else
                res+=$(printf '%s' "${s_reset}${s_code}");
                res+=$(printf '%s' "$token")
            fi
        else
            if [[ "$token" = '*' ]]; then
                (( bold = 1 - bold ))
            elif [[ "$token" = '_' ]]; then
                (( italics = 1 - italics ))
            elif [[ "$token" = '`' ]]; then
                (( code = 1 - code ))
            elif [[ "$token" = '[' ]]; then
                (( link = 1 - link ))
            else
                res+=$(printf '%s' "${s_reset}")
                if [[ "$link" = 1 ]]; then res+=$(printf '%s' "${s_link}"); fi
                if [[ "$bold" = 1 ]];    then res+=$(printf '%s' "${s_bold}"); fi
                if [[ "$italics" = 1 ]]; then res+=$(printf '%s' "${s_italics}"); fi
                res+=$(printf '%s' "$token")
            fi
        fi
    done
    res=$(echo "$res" | tr '\t' '\n') # Put newlines back
    echo "${res}${s_reset}"
}

process_paragraph() {
    # Format a paragraph.
    para=$(trim "$1")
    para=$(echo "$para" |
        sed 's/  */ /g' | # Join consecutive spaces into one
        fmt               # Limit to 80 characters per line.
    )
    # Note that `fmt` must be ran before `font_styles` because the latter
    # inserts formatting characters which are not printed but `fmt` includes
    # them in line length count, resulting in extremely short lines
    para=$(font_styles "$para")
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
        trimmed=$(echo "$header" | sed 's/^#* *//g; s/[\[\*_]*//g')
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
        # Bullets instead of '-' or '*' (which would become _ by now); limit line length
        processed_line=$(echo "${line}" | sed 's/^\( *\)[-_]/\1•/' | fmt)
        processed_line=$(process_paragraph "${processed_line}")
        echo "$(repeat_char ' ' $indent_level )${processed_line}"
    done <<< "$list"
}

process_code_block() {
    # Format (or rather, don't reformat) code blocks
    code=$(printf "%s" "$1" | tail -n +2) # Drop first line because we inserted an extra \n
    printf '%s' "${s_code}"
    printf "%s" "$code"
    printf '%s' "${s_reset}"
}

process_block() {
    # Process one whole block: a PARAGRAPH/HEADER/LIST/CODE
    block="$1"
    block_type="$2"

    if [[ -z $(trim "$block") ]]; then # Skip empty blocks
        return
    fi

    if [[ "$block_type" = "CODE" ]]; then
        # Do not preprocess code blocks; display them raw
        block=$(process_code_block "$block")
    else
        # Standardize
        block=$(echo "$block" | sed '
            s/*/_/g; s/__/*/g               # use a single * for bold and a single _ for italics
            s/\t/    /g                     # spaces, not tabs
        ')
        # Link text is marked as [text[ so that the same character starts and ends the link.
        if [[ "$show_link_targets" = 0 ]]; then
            block=$(echo "$block" | sed 's/\[\([^\[]*\)\]([^)]*)/\[\1\[/g')
        else
            # Link targets are kept and separated by a space: [ab](cd) -> [ab[ cd
            block=$(echo "$block" | sed 's/\[\([^\[]*\)\]\(([^)]*)\)/\[\1\[ \2/g')
        fi

        if [[ "$block_type" = "LIST" ]]; then
            block=$(process_list "$block")
        elif [[ "$block_type" = "HEADER" ]]; then
            block=$(process_header "$block")
        elif [[ "$block_type" = "PARAGRAPH" ]]; then
            block=$(process_paragraph "$block")
        fi
    fi

    echo "$block"
    echo ""
}

process_all() {
    # Main function, called after arguments have been parsed

    block_type="PARAGRAPH"  # PARAGRAPH/HEADER/LIST/CODE
    cur=""                  # Contents of current block so far

    while IFS= read line; do # `IFS=` so that we do not trim whitespace
        if [[ -z "$line" ]]; then # Empty line
            if [[ "$block_type" = "CODE" ]]; then # Code blocks may span multiple paragraphs.
                cur="${cur}"$'\n'
            else # In other cases, paragraph end means block end
                process_block "$cur" "$block_type"
                cur=""
                block_type="PARAGRAPH"
            fi
        elif is_code_block_separator "$line"; then # Code
            if [[ "$block_type" != "CODE" ]]; then # Start
                process_block "$cur" "$block_type"
                cur=""
                block_type="CODE"
            else # End of code block
                process_block "$cur" "$block_type"
                cur=""
                block_type="PARAGRAPH"
            fi
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
            if [[ "$block_type" = "CODE" ]]; then
                cur="${cur}"$'\n'"${line}"
            elif [[ "$block_type" = "LIST" ]]; then # Continuation of a list item on another line
                cur="${cur} ${line}"
            elif [[ "$block_type" != "PARAGRAPH" ]]; then # Divide between types; flush
                process_block "$cur" "$block_type"
                cur="${line}"
                block_type="PARAGRAPH"
            else # Continuation of a paragraph
                cur="${cur} ${line}"
            fi
        fi
    done < ${input_file}

    process_block "$cur" "$block_type" # Process the last remaining block
}

do_help=0
show_link_targets=0
input_file=/dev/stdin
file_provided=0
return_code=0

while [[ -n "$1" ]]; do
    case "$1" in
    --help)
        do_help=1
        break
        ;;
    -l)
        show_link_targets=1
        ;;
    *)
        if [[ "${file_provided}" = 0 ]]; then
            input_file="$1"
            file_provided=1
        else
            ret_val=1
            do_help=1
            printf "%s\n\n" "More than one input file provided: $1" >&2
            return_code=1
            break
        fi
        ;;
    esac
    shift
done

if [[ "${do_help}" = 1 ]]; then
    cat << EOF
usage: ./mdcat.sh [-l] [--help] [INPUT_FILE]
Pretty-print Markdown files into the terminal. If INPUT_FILE is not
provided, stdin is used.

  --help    print help and exit
  -l        print link targets (by default, they are omitted for clarity)
EOF
    exit $return_code
fi

process_all
