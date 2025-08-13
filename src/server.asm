.global _start
.intel_syntax noprefix

.section .bss
sock_fd:        .space 8
epoll_fd:       .space 8
client_fd:       .space 8
events_array:   .space 16 * 16

.section .data
http_response:
    .asciz "HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\nHello, world!"
http_response_len = . - http_response

.section .text 
_start:
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    syscall

    mov [sock_fd], rax

    sub rsp, 16

    mov word ptr [rsp], 2 
    mov word ptr [rsp + 2], 0x901f
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
    mov rsi, 1024
    syscall

    # epoll!!! creates here
    mov rax, 291
    xor rdi, rdi
    syscall

    mov [epoll_fd], rax
    
    sub rsp, 12

    mov rax, 233
    mov rdi, [epoll_fd]
    mov rsi, 1 
    mov rdx, [sock_fd]
    
    mov r11, [sock_fd]
    mov dword ptr [rsp], 1
    mov qword ptr [rsp + 4], r11
    mov r10, rsp
    syscall

    add rsp, 12

event_loop:
    mov rax, 232
    mov rdi, [epoll_fd]
    mov rsi, events_array
    mov rdx, 16
    mov r10, -1
    syscall

    cmp rax, 0
    jle event_loop

    mov r12, rax # event count
    xor r13, r13

process_events:
    cmp r13, r12
    jge event_loop

    mov r14, r13
    imul r14, 16 # get offset to top of stack of events
    lea r15, [events_array + r14]

    mov r11, qword ptr [r15 + 4] # fd from event
    
    cmp r11, [sock_fd]
    je handle_new_connection

    jmp handle_client

handle_new_connection:
    mov rax, 43
    mov rdi, [sock_fd]
    mov rsi, 0
    mov rdx, 0
    syscall

    cmp rax, 0
    js next_event

    mov [client_fd], rax

    # add the new client to epoll
    sub rsp, 16

    mov rax, 233
    mov rdi, [epoll_fd]
    mov rsi, 1 
    mov rdx, [client_fd]

    mov r11, [client_fd]
    mov dword ptr [rsp], 1
    mov qword ptr [rsp + 4], r11
    mov r10, rsp
    syscall

    add rsp, 16

    jmp next_event

handle_client:
    mov rax, 0
    mov rdi, r11 
    lea rsi, [buffer]
    mov rdx, 4096
    syscall

    cmp rax, 0
    jle close_client

    mov rax, 1 
    mov rdi, r11 
    lea rsi, [http_response]
    mov rdx, http_response_len
    syscall

close_client:
    mov rax, 233 
    mov rdi, [epoll_fd]
    mov rsi, 3
    mov rdx, r11 # client_fd
    mov r10, 0
    syscall

    mov rax, 3
    mov rdi, r11 
    syscall

next_event:
    inc r13 # next event
    jmp process_events
