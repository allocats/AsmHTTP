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

log_read_fail: .asciz "Read failed\n"
log_rf_len = 12

log_write_fail: .asciz "Write failed\n"
log_wf_len = 13

client_prompt: .asciz "\nMessage: "
client_prompt_len = 10 

server_prompt: .asciz "\nServer: "
server_prompt_len = 9 

disconnect_msg: .ascii "Disconnected.\n"
disconnect_msg_len = . - disconnect_msg

.section .bss
sock_fd: .space 8 
message: .space 128
message_len: .space 8

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

    cmp rax, -1 
    je socket_fail
    mov qword ptr [sock_fd], rax

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
    cmp rax, -1
    je connect_fail

    jmp chat_loop

close_chat:
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

    mov rax, 1
    mov rdi, 1
    lea rsi, [client_prompt]
    mov rdx, client_prompt_len
    syscall

    mov rax, 0 
    mov rdi, 0 
    lea rsi, [message]
    mov rdx, 127
    syscall

    cmp rax, -1
    je write_fail

    mov [message_len], rax

    mov rbx, rax
    dec rbx
    cmp byte ptr [message + rbx], 10
    jne skip_newline_removal 
    mov byte ptr [message + rbx], 0 
    dec qword ptr [message_len]

skip_newline_removal:
    mov al, [message]
    cmp al, 'q'
    je close_chat

    mov rax, 1 
    mov rdi, qword ptr [sock_fd]
    lea rsi, [message]
    mov rdx, [message_len]
    syscall

    cmp rax, -1
    je write_fail

    lea rdi, [message]
    mov rcx, 128
    xor al, al
    rep stosb

    mov rax, 0 
    mov rdi, qword ptr [sock_fd]
    lea rsi, [message]
    mov rdx, 127
    syscall 

    cmp rax, 0 
    je close_chat
    cmp rax, -1
    je read_fail

    mov [message_len], rax
    mov rbx, rax
    mov byte ptr [message + rbx], 0 

    mov rax, 1 
    mov rdi, 1 
    lea rsi, [server_prompt]
    mov rdx, server_prompt_len
    syscall 

    mov rax, 1 
    mov rdi, 1 
    lea rsi, [message]
    mov rdx, [message_len]
    syscall

    jmp chat_loop


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
    mov rax, 3
    mov rdi, qword ptr [sock_fd]
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [log_connect_fail]
    mov rdx, log_cf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
 
write_fail:
    mov rax, 3
    mov rdi, qword ptr [sock_fd]
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [log_write_fail]
    mov rdx, log_wf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall

read_fail:
    mov rax, 3
    mov rdi, qword ptr [sock_fd]
    syscall

    mov rax, 1
    mov rdi, 1
    lea rsi, [log_read_fail]
    mov rdx, log_rf_len
    syscall

    mov rax, 60
    mov rdi, 1 
    syscall
