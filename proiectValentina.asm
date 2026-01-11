
assume cs:code, ds:data

data segment
    ; Mesaje Intrare/Erori 
    msg_in      db 13,10,'Introdu 8..16 octeti HEX cu spatii (ex: 0A FF 12 ...): $'
    msg_ok      db 13,10,'OK: conversie reusita. Octetii sunt in sir[].$'
    msg_badhex  db 13,10,'Eroare: caracter HEX invalid sau format gresit.$'
    msg_badlen  db 13,10,'Eroare: trebuie intre 8 si 16 octeti.$'
    
    ;  Mesaje Rezultate 
    msg_c       db 13,10,'4. Cuvantul C calculat: $'
    msg_sort    db 13,10,'5. Sirul sortat descrescator: $'

    ; Buffer DOS pentru functia 0Ah 
    buf_max     db 80        ; Numar maxim de caractere
    buf_len     db 0         ; Aici DOS va scrie cate caractere a citit
    buf_text    db 80 dup(0) ; Aici va fi textul

    ; Variabile program 
    sir         db 16 dup(0) ; Vectorul de octeti convertiti
    lungime     db 0         ; Numarul real de octeti din sir
    C           dw 0         ; Variabila pentru rezultatul pasului 4
data ends

code segment
start:
    ; Initializare Segment Date
    mov ax, data
    mov ds, ax

reincearca:
    ; Afisare mesaj input
    mov dx, offset msg_in
    mov ah, 09h
    int 21h

    ; Citire text de la tastatura
    mov dx, offset buf_max   
    mov ah, 0Ah
    int 21h

    ; Initializare parsare
    mov lungime, 0
    lea si, buf_text         
    lea di, sir              
    
    xor cx, cx               
    mov cl, buf_len          
    cmp cx, 0
    je reincearca            

parsare:
    cmp cx, 0
    jg continua_parsare
    jmp validare_finala      

continua_parsare:
    ; Sarim peste spatii
    mov al, [si]
    cmp al, ' '
    jne incepe_octet
    inc si
    dec cx
    jmp parsare

incepe_octet:
    cmp cx, 2
    jae ok_2car
    jmp eroare_hex

ok_2car:
    ;  NIBBLE 1 (High) 
    mov al, [si]
    cmp al, '0'
    jb  n1_err_tr
    cmp al, '9'
    jbe n1_cifra
    cmp al, 'A'
    jb  n1_err_tr
    cmp al, 'F'
    jbe n1_lit_mare
    cmp al, 'a'
    jb  n1_err_tr
    cmp al, 'f'
    jbe n1_lit_mica
    jmp n1_err_tr            

n1_cifra:
    sub al, '0'
    jmp n1_gata
n1_lit_mare:
    sub al, 'A'
    add al, 10
    jmp n1_gata
n1_lit_mica:
    sub al, 'a'
    add al, 10
n1_gata:
    mov ah, al               
    inc si                   
    dec cx

    ; NIBBLE 2 (Low)
    mov al, [si]
    cmp al, '0'
    jb  n2_err_tr
    cmp al, '9'
    jbe n2_cifra
    cmp al, 'A'
    jb  n2_err_tr
    cmp al, 'F'
    jbe n2_lit_mare
    cmp al, 'a'
    jb  n2_err_tr
    cmp al, 'f'
    jbe n2_lit_mica
    jmp n2_err_tr

n2_cifra:
    sub al, '0'
    jmp n2_gata
n2_lit_mare:
    sub al, 'A'
    add al, 10
    jmp n2_gata
n2_lit_mica:
    sub al, 'a'
    add al, 10
n2_gata:
    shl ah, 1
    shl ah, 1
    shl ah, 1
    shl ah, 1
    add al, ah               

    mov [di], al             
    inc di                   
    
    mov bl, lungime
    inc bl
    mov lungime, bl
    
    cmp bl, 16
    ja eroare_len            

    inc si                   
    dec cx
    jmp parsare

n1_err_tr: jmp eroare_hex
n2_err_tr: jmp eroare_hex

; VALIDARE SI ERORI 
validare_finala:
    mov al, lungime
    cmp al, 8
    jb eroare_len            
    cmp al, 16
    ja eroare_len            
    
    mov dx, offset msg_ok
    mov ah, 09h
    int 21h
    jmp final
eroare_len:
    mov dx, offset msg_badlen
    mov ah, 09h
    int 21h
    jmp reincearca

eroare_hex:
    mov dx, offset msg_badhex
    mov ah, 09h
    int 21h
    jmp reincearca
final:
mov ax,4C00h
int 21h
code ends
end start