.global _start
.intel_syntax noprefix

.section .data
log_start: .asciz "Starting client...\n"
log_start_len = 19

log_socket_fail: .asciz "Socket failed\n"
log_sf_len = 14

log_connect_fail: .asciz "Connect failed\n"
log_cf_len = 15

log_socket_close: .asciz "Closed socket\n"
log_sc_len = 14

log_write_fail: .asciz "Write failed\n"
log_wf_len = 13

client_prompt: .asciz "Message: "
client_prompt_len = 9

server_prompt: .asciz "Server: "
server_prompt_len = 8


.section .bss
sock_fd: .space 4
message: .space 8

.section .text
_start:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_start]
    mov rdx, log_start_len
    syscall
    
    # Create the socket
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    syscall

    cmp eax, -1 
    je socket_fail
    mov [sock_fd], eax

    # Connect to the server 
    sub rsp, 16
    mov word ptr [rsp], 2      # AF_INET
    mov word ptr [rsp+2], 0x511f  # port
    mov dword ptr [rsp+4], 0x0100007f  # IP for client or 0 for server
    mov qword ptr [rsp+8], 0   # padding

    mov rax, 42
    mov rdi, [sock_fd]
    mov rsi, rsp
    mov rdx, 16
    syscall

    add rsp, 16
    cmp eax, -1
    je connect_fail

    call chat_loop

    # Close socket 
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
    mov rax, 1
    mov rdi, 1
    lea rsi, [client_prompt]
    mov rdx, client_prompt_len
    syscall

    mov rax, 0 
    mov rdi, 0 
    lea rsi, [message]
    mov rdx, 8
    syscall

    mov rax, 1
    mov rdi, [sock_fd]
    lea rsi, [message]
    mov rdx, 8 
    syscall

    cmp eax, -1
    je write_fail

    mov rax, 0 
    mov rdi, [sock_fd]
    lea rsi, [message]
    mov rdx, 8
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [server_prompt]
    mov rdx, server_prompt_len
    syscall

    mov rax, 1 
    mov rdi, 1
    lea rsi, [message]
    mov rdx, 8
    syscall

    mov al, [message]
    cmp al, 'q'
    jne chat_loop

socket_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_socket_fail]
    mov rdx, log_sf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall

connect_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_connect_fail]
    mov rdx, log_cf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
 
write_fail:
    mov rax, 1
    mov rdi, 1
    lea rsi, [log_write_fail]
    mov rdx, log_wf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
