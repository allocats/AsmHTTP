.global _start
.intel_syntax noprefix

.section .data
prompt: .asciz "Starting server...\n"
prompt_len = 20

prompt_socket_fail: .asciz "Socket failed\n"
prompt_sf_len = 15

.section .bss
sock_fd: .space 4

.section .text
_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [prompt]
    mov rdx, prompt_len
    syscall

    /* Create socket */
    mov rax, 41 
    mov rdi, 2 
    mov rsi, 1 
    mov rdx, 0
    syscall

    cmp eax, -1 
    je socket_fail
    mov [sock_fd], eax


    /* Closesocket */
    mov rax, 3
    mov rdi, [sock_fd]
    syscall

    mov rax, 60
    mov rdi, 0
    syscall

socket_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [prompt_socket_fail]
    mov rdx, prompt_sf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
