.global _start
.intel_syntax noprefix

.section .bss
.align 64
sock_fd:        .space 8
epoll_fd:       .space 8
client_fd:      .space 8
events_array:   .space 12 * 16
buffer:         .space 1024

.section .data
http_response:
    .ascii "HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: keep-alive\r\n\r\nHello, world!"
http_response_len = . - http_response

.section .text 
_start:
    mov rax, 41
    mov rdi, 2
    mov rsi, 1
    mov rdx, 0
    syscall

    test rax, rax 
    js exit_error

    mov [sock_fd], rax

    sub rsp, 8 

    mov dword ptr [rsp], 1 # optval = 1
    mov rax, 54 # setsockopt syscall
    mov rdi, [sock_fd] # sockfd
    mov rsi, 1 # SOL_SOCKET
    mov rdx, 2 # SO_REUSEADDR
    mov r10, rsp # optval
    mov r8, 4 # optlen
    syscall

    add rsp, 8

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
    test rax, rax
    js exit_error

    mov rax, 50
    mov rdi, [sock_fd]
    mov rsi, 1024
    syscall

    test rax, rax
    js exit_error

    mov rbx, 0 # Worker counter 0 to worker count - 1
    mov r12, 6 # number of workers, 6 since 6 cores

fork_loop:
    cmp rbx, r12
    jge parent_wait             

    mov rax, 57                 
    syscall

    test rax, rax
    js exit_error               
    jnz next_fork               # rax is child_pid, continues forking

    # epoll!!! creates here
    mov rax, 291
    mov rdi, 0
    syscall

    test rax, rax
    js exit_error

    mov [epoll_fd], rax
    
    sub rsp, 12

    mov dword ptr [rsp], 0x80000001 
    mov rax, [sock_fd]
    mov qword ptr [rsp + 4], rax

    mov rax, 233 #epoll_ctl
    mov rdi, [epoll_fd] 
    mov rsi, 1 #epoll ctl add
    mov rdx, [sock_fd]
    mov r10, rsp
    syscall

    add rsp, 12

    test rax, rax
    js exit_error

    jmp event_loop

next_fork:
    inc rbx
    jmp fork_loop

parent_wait:
    sub rsp, 8 # Space for status

inf_wait:
    mov rax, 61 # wait4
    mov rdi, -1 # Any child
    mov rsi, rsp # &status
    mov rdx, 0 # Options
    mov r10, 0 # rusage
    syscall

    cmp rax, -1 # No more children?
    je exit_success             
    jmp inf_wait

    add rsp, 8

event_loop:
    mov rax, 232 # epoll wait
    mov rdi, [epoll_fd]
    lea rsi, [events_array]
    mov rdx, 16
    mov r10, -1
    syscall

    test rax, rax
    jle event_loop

    mov r12, rax # event count
    xor r13, r13

process_events:
    cmp r13, r12
    jge event_loop

    mov rax, r13
    mov rdx, 12 
    mul rdx
    lea r14, [events_array + rax]

    mov r11, qword ptr [r14 + 4] # fd from event
    cmp r11, [sock_fd]
    je handle_new_connection

    jmp handle_client

handle_new_connection:
    mov rax, 288
    mov rdi, [sock_fd]
    xor rsi, rsi
    xor rdx, rdx 
    mov r10, 0x800
    syscall

    test rax, rax
    js next_event

    mov r15, rax

    # add the new client to epoll
    sub rsp, 12

    mov dword ptr [rsp], 0x80000001
    mov qword ptr [rsp + 4], r15 
    mov rax, 233 
    mov rdi, [epoll_fd]
    mov rsi, 1 
    mov rdx, r15
    mov r10, rsp
    syscall

    add rsp, 12

    jmp next_event

handle_client:
    mov r15, r11
    
read_loop:
    mov rax, 0
    mov rdi, r15
    lea rsi, [buffer]
    mov rdx, 1024 
    syscall

    cmp rax, 0
    je client_disconnect

    cmp rax, -11
    je client_respond

    jmp read_loop

client_respond:
    mov rax, 1
    mov rdi, r15
    lea rsi, [http_response]
    mov rdx, http_response_len
    syscall

    jmp next_event

client_disconnect:
    mov rax, 233
    mov rdi, [epoll_fd]
    mov rsi, 2 # EPOLL_CTL_DEL
    mov rdx, r15
    xor r10, r10
    syscall

    mov rax, 3
    mov rdi, r15
    syscall

    jmp next_event

next_event:
    inc r13 
    jmp process_events

exit_error:
    mov rax, 60
    mov rdi, 1
    syscall

exit_success:
    mov rax, 60
    mov rdi, 0
    syscall
