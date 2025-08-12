.global _start
.intel_syntax noprefix

.section .bss
sock_fd: 
    .space 8

client_fd: 
    .space 8

buffer:
    .space 1024

file_path_buffer:
    .space 256

file_buffer:
    .space 4096

.section .data
http_200:
    .asciz "HTTP/1.0 200 OK\r\n\r\n"
http_200_len = . - http_200 

index_path:
    .asciz "index.html"

.section .text
_start:
    mov rax, 41 
    mov rdi, 2 
    mov rsi, 1 
    mov rdx, 0
    syscall

    mov qword ptr [sock_fd], rax

    sub rsp, 16

    mov word ptr [rsp], 2
    mov word ptr [rsp + 2], 0x511f
    mov dword ptr [rsp + 4], 0  
    mov qword ptr [rsp + 8], 0  

    mov rax, 49
    mov rdi, [sock_fd]
    mov rsi, rsp
    mov rdx, 16
    syscall

    add rsp, 16

    mov rax, 50
    mov rdi, [sock_fd]
    mov rsi, 8
    syscall

    jmp accept_connection
    
accept_connection:
    mov rax, 43
    mov rdi, [sock_fd]
    mov rsi, 0x0
    mov rdx, 0x0
    syscall

    mov qword ptr [client_fd], rax
    mov rax, 57
    syscall

    cmp rax, 0
    je serve_connection

    mov rdi, [client_fd]
    mov rax, 3
    syscall

    jmp accept_connection

serve_connection:
    mov rax, 0 
    mov rdi, [client_fd]
    lea rsi, [buffer]
    mov rdx, 1024
    syscall

    mov r15, rax # len of sys_read()

    call parse_request

    mov rdi, [client_fd]
    mov rax, 3
    syscall

    jmp accept_connection

parse_request:
    # todo 
    lea rdi, [buffer]

    mov eax, dword ptr [rdi]
    mov ebx, 0x20544547
    cmp eax, ebx
    jne send_404

    add rdi, 4
    mov rsi, rdi # start of file path, rdi will point to end

    call fine_path_end

fine_path_end:
    cmp byte ptr [rdi], ' '
    je path_found
    inc rdi
    cmp rdi, buffer + 1024 
    je send_404
    jmp fine_path_end


path_found:
    sub rdi, rsi
    mov rcx, rdi

    cmp rcx, 255
    jae send_404

    lea rdi, [file_path_buffer]
    rep movsb
    mov byte ptr [rdi], 0

    lea rdi, [file_path_buffer]
    cmp byte ptr [rdi], '/'
    jne open_file
    cmp byte ptr [rdi + 1], 0 
    je send_default

open_file:
    mov rax, 2 
    lea rdi, [file_path_buffer]
    mov rsi, 0 
    syscall

    cmp rax, 0 
    je send_404
    
    mov r14, rax # fd 

    mov rax, 0 
    mov rdi, r14 
    lea rsi, [file_buffer]
    mov rdx, 4095 
    syscall

    mov r13, rax # file size

    mov rax, 3
    mov rdi, r14
    syscall 

    cmp r13, 0
    je send_404

    call send_200_headers

    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [file_buffer]
    mov rdx, r13 
    syscall
    ret

send_200_headers:
    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [http_200]
    mov rdx, http_200_len
    syscall
    ret

send_default:
    call send_200_headers

    mov rax, 1 
    
    ret

send_404:
    ret
