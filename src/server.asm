.global _start
.intel_syntax noprefix

.section .data
log_start: .asciz "Starting server...\n"
log_start_len = 19

log_socket_fail: .asciz "Socket failed\n"
log_sf_len = 14

log_socket_close: .asciz "Closed socket\n"
log_sc_len = 14

.section .bss
sock_fd: .space 4

.section .text
_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_start]
    mov rdx, log_start_len 
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
    
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_socket_close]
    mov rdx, log_sc_len
    syscall

    mov rax, 60
    mov rdi, 0
    syscall

socket_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_socket_fail]
    mov rdx, log_sf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
