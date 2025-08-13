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
html_ext:
    .asciz "html"
html_ext_len = . - html_ext

css_ext:
    .asciz "css"
css_ext_len = . - css_ext

js_ext:
    .asciz "js"
js_ext_len = . - js_ext

get_req: 
    .asciz "GET "

post_req: 
    .asciz "POST"

http_200_html: 
    .ascii "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n"
http_200_html_len = . - http_200_html

http_200_css: 
    .ascii "HTTP/1.1 200 OK\r\nContent-Type: text/css\r\nConnection: close\r\n\r\n"
http_200_css_len = . - http_200_css

http_200_js: 
    .ascii "HTTP/1.1 200 OK\r\nContent-Type: application/javascript\r\nConnection: close\r\n\r\n"
http_200_js_len = . - http_200_js

http_404: 
    .ascii "HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\nConnection: close\r\n\r\nNot Found"
http_404_len = . - http_404

default_response: 
    .ascii "<h1>Hello from x86 asm :3</h1>"
default_response_len = . - default_response

ext_table:
    .long ext_html, case_html
    .long ext_css,  case_css
    .long ext_js,   case_js
    .long 0,        case_default 

.section .text
_start:
    mov rax, 41 
    mov rdi, 2 
    mov rsi, 1 
    mov rdx, 0
    syscall

    mov qword ptr [sock_fd], rax

    sub rsp, 16

    mov word ptr [rsp], 2 # af_inet ipv4
    mov word ptr [rsp + 2], 0x901f # port 8080
    mov dword ptr [rsp + 4], 0  # localhost 
    mov qword ptr [rsp + 8], 0  # padding since it expects 16 bytes

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

    mov r15, rax # bytes read 

    call parse_request

    mov rdi, [client_fd]
    mov rax, 3
    syscall

    mov rax, 60
    mov rdi, 0 
    syscall

parse_request:
    ret

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

    # call right header 
    call get_extension

    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [file_buffer]
    mov rdx, r13 
    syscall
    ret

get_extension:
    lea rdi, [file_path_buffer]

    
get_path_end:
    cmp byte ptr [rdi], ' '
    je found_end
    inc rdi
    cmp rdi, buffer + 1024
    je send_404
    jmp get_path_end

skip_content:
    call send_200_html
    ret

send_200_html:
    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [http_200_html]
    mov rdx, http_200_html_len
    syscall

    ret

send_200_css:
    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [http_200_css]
    mov rdx, http_200_css_len
    syscall

    ret

send_200_js:
    mov rax, 1 
    mov rdi, [client_fd]
    lea rsi, [http_200_js]
    mov rdx, http_200_js_len
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
