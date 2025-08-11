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
response:
    .asciz "HTTP/1.0 200 OK\r\n\r\n"

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

    # parse the request!
    call parse_request

    mov rdi, [client_fd]
    mov rax, 3
    syscall

    jmp accept_connection

parse_request:
    # todo parse duh >_>
