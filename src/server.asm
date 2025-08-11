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

log_accept_fail: .asciz "Accept failed\n"
log_af_len = 14

log_read_fail: .asciz "Read failed\n"
log_rf_len = 12

log_socket_close: .asciz "Closed socket\n"
log_sc_len = 14

client_prompt: .asciz "\nClient: "
client_prompt_len = 9 

server_prompt: .asciz "\nMessage: "
server_prompt_len = 10

client_addr_len: .long 16 

disconnect_msg: .ascii "Client disconnected.\n"
disconnect_msg_len = . - disconnect_msg

.section .bss
sock_fd: .space 8 
client_fd: .space 8 
client_addr: .space 16
message: .space 128
message_len: .space 8

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

    cmp rax, -1 
    je socket_fail
    mov qword ptr [sock_fd], rax

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
    cmp rax, -1
    je bind_fail

    # Listen
    mov rax, 50
    mov rdi, [sock_fd]
    mov rsi, 8
    syscall

    cmp rax, -1
    je listen_fail

    # Accpet
    mov rax, 43
    mov rdi, [sock_fd]
    lea rsi, [client_addr]
    lea rdx, [client_addr_len]
    syscall

    cmp rax, -1
    je accept_fail

    mov qword ptr [client_fd], rax

    jmp chat_loop

close_chat:
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

chat_loop:
    lea rdi, [message]
    mov rcx, 128
    xor al, al 
    rep stosb

    mov rax, 0 
    mov rdi, [client_fd]
    lea rsi, [message]
    mov rdx, 127
    syscall

    cmp rax, 0
    je client_disconnected
    cmp rax, -1
    je read_fail

    mov [message_len], rax

    mov rbx, rax
    mov byte ptr [message + rbx], 0

    mov rax, 1
    mov rdi, 1
    lea rsi, [client_prompt]
    mov rdx, client_prompt_len
    syscall

    mov rax, 1 
    mov rdi, 1 
    lea rsi, [message]
    mov rdx, [message_len]
    syscall

    mov al, [message]
    cmp al, 'q'
    je close_chat

    mov rax, 1
    mov rdi, 1
    lea rsi, [server_prompt]
    mov rdx, server_prompt_len
    syscall

    lea rdi, [message]
    mov rcx, 128
    xor al, al
    rep stosb

    mov rax, 0
    mov rdi, 0
    lea rsi, [message]
    mov rdx, 127
    syscall

    cmp rax, -1
    je read_fail
    
    mov [message_len], rax

    mov rbx, rax
    dec rbx
    cmp byte ptr [message + rbx], 10
    jne skip_newline_removal 
    mov byte ptr [message + rbx], 0
    dec qword ptr [message_len]

skip_newline_removal:
    mov rax, 1
    mov rdi, [client_fd]
    lea rsi, [message]
    mov rdx, [message_len] 
    syscall

    jmp chat_loop

client_disconnected:
    mov rax, 1 
    mov rdi, 1
    lea rsi, [disconnect_msg]
    mov rdx, disconnect_msg_len
    syscall

    jmp close_chat

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

read_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_read_fail]
    mov rdx, log_rf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
