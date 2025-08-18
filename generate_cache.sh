#!/bin/bash

WWW_DIR=${1:-"www"}

if [ ! -d "$WWW_DIR" ]; then
    echo "Error: Directory $WWW_DIR not found!"
    echo "Usage: $0 <www_directory>"
    exit 1
fi

OUTPUT_FILE="src/cached_files.asm"
LOOKUP_FILE="src/file_lookup.asm"

echo "Generating cached files from $WWW_DIR..."

cat > "$OUTPUT_FILE" << 'EOF'
# Auto-generated cached files
.section .data

EOF

cat > "$LOOKUP_FILE" << 'EOF'
# Auto-generated file lookup table
.section .data
.align 8

# File lookup table structure: path_ptr, data_ptr, length
file_lookup_table:
EOF

file_count=0

minify_html() {
    sed 's/<!--.*-->//g' | \
    sed 's/>[[:space:]]\+</></g' | \
    sed 's/^[[:space:]]\+//g' | \
    sed 's/[[:space:]]\+$//g' | \
    tr -s ' ' | \
    sed 's/[[:space:]]*=[[:space:]]*/=/g' | \
    tr -d '\n' | tr -d '\r'
}

minify_css() {
    sed 's/\/\*.*\*\///g' | \
    tr -d '\n' | tr -d '\r' | \
    sed 's/[[:space:]]\+/ /g' | \
    sed 's/[[:space:]]*{[[:space:]]*/{/g' | \
    sed 's/[[:space:]]*}[[:space:]]*/}/g' | \
    sed 's/[[:space:]]*;[[:space:]]*/;/g' | \
    sed 's/[[:space:]]*:[[:space:]]*/:/g' | \
    sed 's/[[:space:]]*,[[:space:]]*/,/g' | \
    sed 's/^[[:space:]]\+//g' | \
    sed 's/[[:space:]]\+$//g'
}

minify_js() {
    sed 's/\/\*.*\*\///g' | \
    sed 's/\/\/.*$//g' | \
    sed 's/"[^"]*"/STRING_PLACEHOLDER_&/g' | \ 
    tr -d '\n' | tr -d '\r' | \
    sed 's/[[:space:]]\+/ /g' | \
    sed 's/[[:space:]]*{[[:space:]]*/{/g' | \
    sed 's/[[:space:]]*}[[:space:]]*/}/g' | \
    sed 's/[[:space:]]*;[[:space:]]*/;/g' | \
    sed 's/[[:space:]]*([[:space:]]*(/g' | \
    sed 's/[[:space:]]*)[[:space:]]*/)/g' | \
    sed 's/^[[:space:]]\+//g' | \
    sed 's/[[:space:]]\+$//g'
}

escape_for_asm() {
    sed 's/\\/\\\\/g; s/"/\\"/g'
}

djb2_hash() {
    local string="$1"
    local hash=5381
    local i
    
    for (( i=0; i<${#string}; i++ )); do
        local char=$(printf '%d' "'${string:$i:1}")
        hash=$(( (hash << 5) + hash + char ))
        hash=$(( hash & 0xFFFFFFFF ))
    done
    
    echo $hash
}

for file in $(find "$WWW_DIR" -name "*.html" -o -name "*.css" -o -name "*.js" | sort); do
    rel_path=${file#$WWW_DIR}
    rel_path=${rel_path#/} 
    
    safe_name=$(echo "$rel_path" | tr '/' '_' | tr '.' '_' | tr '-' '_')
    
    original_size=$(wc -c < "$file")

    header="HTTP/1.1 200 OK\r\nConnection: keep-alive\r\n"
    
    echo "Processing: /$rel_path ($original_size bytes)"

    
    case "$file" in
        *.html)
            content=$(cat "$file" | minify_html | escape_for_asm)
            content_len=${#content}
            header+="Content-Type: text/html\r\nContent-Length: ${content_len}\r\n\r\n"
            ;;
        *.css)
            content=$(cat "$file" | minify_css | escape_for_asm)
            content_len=${#content}
            header+="Content-Type: text/css\r\nContent-Length: ${content_len}\r\n\r\n"
            ;;
        *.js)
            content=$(cat "$file" | minify_js | escape_for_asm)
            content_len=${#content}
            header+="Content-Type: text/javascript\r\nContent-Length: ${content_len}\r\n\r\n"
            ;;
        *)
            content=$(cat "$file" | escape_for_asm)
            content_len=${#content}
            ;;
    esac

    hash=$(djb2_hash "/${rel_path}")
    echo "Hash for /${rel_path}: 0x$(printf '%x', $hash)"
    
    minified_size=${#content}
    savings=$((original_size - minified_size))
    percentage=$(( savings * 100 / original_size ))
    
    echo "  Minified: $minified_size bytes (saved $savings bytes, ${percentage}%)"
    
    # echo "path_$safe_name:" >> "$OUTPUT_FILE"
    # echo "    .asciz \"/$rel_path\"" >> "$OUTPUT_FILE"
    # echo "" >> "$OUTPUT_FILE"
    
    echo "cached_$safe_name:" >> "$OUTPUT_FILE"
    echo "    .asciz \"$header\"" >> "$OUTPUT_FILE"
    echo "    .asciz \"$content\"" >> "$OUTPUT_FILE"
    
    echo "cached_${safe_name}_len = . - cached_$safe_name" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    echo "    .quad $hash, cached_$safe_name, cached_${safe_name}_len" >> "$LOOKUP_FILE"
    
    ((file_count++))
done

echo "    .quad 0, 0, 0  # End marker" >> "$LOOKUP_FILE"
echo "" >> "$LOOKUP_FILE"
echo "file_count = $file_count" >> "$LOOKUP_FILE"

echo ""
echo "Generated $file_count cached files:"
echo "  - $OUTPUT_FILE (file data)"
echo "  - $LOOKUP_FILE (lookup table)"
echo ""
echo "Include both files in your assembly with:"
echo "  .include \"$OUTPUT_FILE\""
echo "  .include \"$LOOKUP_FILE\""
