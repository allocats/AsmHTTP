.global _start
.intel_syntax noprefix

.section .data
log_start: .asciz "Starting server...\n"
log_start_len = 19

log_socket_fail: .asciz "Socket failed\n"
log_sf_len = 14

log_bind_fail: .asciz "Bind failed\n"
log_bf_len = 12

log_listen_fail: .asciz "Listen failed\n"
log_lf_len = 14

log_accept_fail: .asciz "Accpet failed\n"
log_af_len = 14

log_socket_close: .asciz "Closed socket\n"
log_sc_len = 14

client_addr_len: .long 16 

.section .bss
sock_fd: .space 4
client_fd: .space 4
client_addr: .space 16

.section .text
_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_start]
    mov rdx, log_start_len 
    syscall

    # Create socket
    mov rax, 41 
    mov rdi, 2 
    mov rsi, 1 
    mov rdx, 0
    syscall

    cmp eax, -1 
    je socket_fail
    mov [sock_fd], eax

    # Bind socket
    sub rsp, 16
    mov word ptr [rsp], 2      # AF_INET
    mov word ptr [rsp+2], 0x511f  # port
    mov dword ptr [rsp+4], 0  # IP for client or 0 for server
    mov qword ptr [rsp+8], 0   # padding

    mov rax, 49
    mov rdi, [sock_fd]
    mov rsi, rsp
    mov rdx, 16
    syscall

    add rsp, 16
    cmp eax, -1
    je bind_fail

    # Listen
    mov rax, 50
    mov rdi, [sock_fd]
    mov rsi, 8
    syscall

    cmp eax, -1
    je listen_fail

    # Accpet
    mov rax, 43
    mov rdi, [sock_fd]
    lea rsi, [client_addr]
    lea rdx, [client_addr_len]
    syscall

    cmp eax, -1
    je accept_fail

    # After accept() and handling one client:
    mov [client_fd], rax
    mov rax, 3
    mov rdi, [client_fd]
    syscall

    # Close server socket 
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

bind_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_bind_fail]
    mov rdx, log_bf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall

listen_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_listen_fail]
    mov rdx, log_lf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall

accept_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_accept_fail]
    mov rdx, log_af_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
