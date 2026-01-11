assume cs:code, ds:data
data segment

data ends

mov ax,data
mov ds,ax


mov ax,4C00h
int 21h

code ends
end start