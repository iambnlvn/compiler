; this is a simple program that prints a number to the console

global _print

; r15 - arg
; use reg
; rax, rcx, rdx, rbx, r10, r8, rsi

section .data
    variable dq 0
    del dq 10
section .bss
    string resb 31

section .text
_handle_neg:
    neg qword[variable]
    jmp init_string
_print:
   mov qword[variable], r15
   
   push rax
   push rcx
   push rdx
   push r10
   push rsi
   push r8
   push rbx

    
   mov rbx, 1
   shl rbx, 63
   and rbx, [variable]
   shr rbx, 63
   mov rax, 0 
   cmp rax, rbx    
   js _handle_neg
init_string:
    mov qword[string + 29], 10
    mov rcx, qword[variable]
    mov r8, 28
    jrcxz _value_is_zero
_cycle:
    jrcxz _check_sign
    mov rax, rcx
    mov rdx, 0
    div qword[del]
    mov rcx, rax
    add rdx, 48
    mov byte[string + r8], dl
    dec r8
    jmp _cycle
_value_is_zero:
    mov byte[string + r8], 48
    dec r8 
_check_sign:
    mov rax, 0
    cmp rax, rbx
    js _add_neg
    jz _handle_pos
_add_neg:
    mov byte[string + r8], 45
    jmp _output_to_console
_handle_pos:
    inc r8
_output_to_console: 
    mov rax, 1
    mov rdi, 1
    mov rdx, 31
    mov r15, string
    add r15, r8
    mov rsi, r15
    syscall    
exit:
    mov r15, qword[variable]
    pop rbx
    pop r8
    pop rsi
    pop r10
    pop rdx
    pop rcx
    pop rax   
    ret