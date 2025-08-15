#!/usr/bin/env bash

# -i included files
# -e excluded files
# -d delete files
# -r replace files

include_files=()
exclude_files=()
replace_files=()
delete_files=()

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -i | --include"
    echo "  -e | --exclude"
    echo "  -d | --delete"
    echo "  -r | --replace"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--include)
            shift 
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                include_files+=("$1")
                shift
            done
            ;;
        -e|--exclude)
            shift 
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                exclude_files+=("$1")
                shift
            done
            ;;
        -r|--replace)
            shift 
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                replace_files+=("$1")
                shift
            done
            ;;
        -d|--delete)
            shift 
            while [[ $# -gt 0 && ! $1 =~ ^- ]]; do
                delete_files+=("$1")
                shift
            done
            ;;
        -*)
            echo "Error: Unknown arg"
            show_usage
            exit 1
            ;;
        *) 
            echo "skipping"
            shift
            ;;
    esac
done

print_array() {
    local name=$1
    local -n arr=$2

    if [[ ${#arr[@]} -gt 0 ]]; then 
        echo ""
        echo "$name:"

        for item in "${arr[@]}"; do
            echo " - $item"
        done
    else 
        echo "$name: (none)"
    fi 
}

print_array "include" include_files
print_array "exclude" exclude_files
print_array "delete" delete_files
print_array "replace" replace_files

for path in "${include_files[@]}"; do
    find "$path" -type f | while read file; do 
        buffer_name=$(echo "$file" | sed 's/[^a-zA-Z0-9]/_/g')
        buffer_size=$(stat -c%s "$file")
        buffer_size=(buffer_size + 7) &~ 7
        echo "${buffer_name}_buffer .space $buffer_size"
    done
done
