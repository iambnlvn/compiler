global _start
extern _print
section .data
a dq 0
b dq 0
section .text
_start:
push 1111111
pop qword[a]
push 3
pop qword[b]
loop1:
push qword[b]
push qword[a]
pop r8
pop r9
cmp r8, r9
ja pos1
push 0
jmp neg1
pos1:
push 1
neg1:
pop r8
cmp r8, 0
jne start2
jmp end2
start2:
push 2
push qword[b]
pop r8
pop r9
imul r8, r9
push r8
pop r8
mov qword[b], r8
push qword[b]
pop r15
call _print
jmp loop1
end2:
exit:
mov rax, 60
syscall
