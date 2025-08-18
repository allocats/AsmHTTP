.intel_syntax noprefix

parse_path:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, r15

    lea rsi, [buffer]
    add rsi, 4
    xor rcx, rcx

find_path_end:
    mov al, [rsi + rcx] 
    cmp al, ' '        
    je path_found

    cmp al, '\r'      
    je path_found  

    inc rcx
    jmp find_path_end

path_found:
    mov rdx, rcx
    dec rdx 
    mov r8, rsi

extract_file:
    cmp rdx, 0
    jl no_slash

    mov al, [r8 + rdx]
    cmp al, '/'
    je slash_found 

    dec rdx 
    jmp extract_file

slash_found:
    sub rcx, rdx

    lea r9, [r8]
    add r9, rdx 
    add r9, rcx 
    mov byte ptr [r9], 0

    lea rsi, [r8 + rdx]

    jmp hash_path

no_slash:
    jmp not_found

hash_path:
    mov eax, 5381 # djb2 initial valur
    xor rcx, rcx # clear counter

hash_loop:
    movzx ebx, byte ptr [rsi + rcx] # load nrxt bytr
    cmp ebx, 0 # check for null terminator
    je hash_done            

    mov edx, eax 
    shl eax, 5 
    add eax, edx
    add eax, ebx # add charactrr

    inc rcx                 
    jmp hash_loop

hash_done:
    lea r11, file_lookup_table

lookup_loop:
    cmp qword ptr [r11], 0
    je not_found 

    cmp eax, dword ptr [r11]
    je found_match 

    add r11, 24
    jmp lookup_loop 

found_match:
    mov rax, 1 
    mov rdi, r12
    mov rsi, [r11 + 8]
    mov rdx, [r11 + 16]
    syscall

    jmp function_exit

not_found:
    mov rax, 1 
    mov rdi, r12 
    lea rsi, [cached_404_html]
    mov rdx, cached_404_html_len
    syscall

function_exit:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
