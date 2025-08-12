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
    .ascii "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
http_200_len = . - http_200

http_404: 
    .ascii "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nNot Found"
http_404_len = . - http_404

default_response: 
    .ascii "<h1>Hello from x86 asm :3</h1>"
default_response_len = . - default_response

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

    cmp rax, 0 
    jle close_and_exit

    mov r15, rax # len of sys_read()

    call parse_request

    mov rdi, [client_fd]
    mov rax, 3
    syscall

    mov rax, 60
    mov rdi, 0 
    syscall

parse_request:
    # todo 
    lea rdi, [buffer]

    mov eax, dword ptr [rdi]
    mov ebx, 0x20544547
    cmp eax, ebx
    jne send_404

    add rdi, 4
    mov rsi, rdi # start of file path, rdi will point to end

    call find_path_end

find_path_end:
    cmp byte ptr [rdi], ' '
    je path_found
    inc rdi
    cmp rdi, buffer + 1024 
    je send_404
    jmp find_path_end


path_found:
    sub rdi, rsi
    mov rcx, rdi

    cmp rcx, 255
    jae send_404

    cmp byte ptr [rsi], '/'
    jne copy_path
    inc rsi
    dec rcx

copy_path:
    lea rdi, [file_path_buffer]
    rep movsb
    mov byte ptr [rdi], 0

    lea rdi, [file_path_buffer]
    cmp byte ptr [rdi], 0 
    je send_default

    jmp open_file

open_file:
    mov rax, 2 
    lea rdi, [file_path_buffer]
    mov rsi, 0 
    syscall

    cmp rax, 0 
    js send_404
    
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
    jle skip_content 

    call send_200_headers

    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [file_buffer]
    mov rdx, r13 
    syscall
    ret
skip_content:
    call send_200_headers
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
    mov rdi, [client_fd]
    lea rsi, [default_response]
    mov rdx, default_response_len
    syscall
    
    ret

send_404:
    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [http_404]
    mov rdx, http_404_len
    syscall
    
    ret

close_and_exit:
    mov rax, 3
    mov rdi, [client_fd]
    syscall 

    mov rax, 60
    mov rdi, 0 
    syscall
