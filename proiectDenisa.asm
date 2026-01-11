assume cs:code, ds:data

data segment
    ; --- Mesaje Intrare/Erori ---
    msg_in      db 13,10,'Introdu 8..16 octeti HEX cu spatii (ex: 0A FF 12 ...): $'
    msg_ok      db 13,10,'OK: conversie reusita. Octetii sunt in sir[].$'
    msg_badhex  db 13,10,'Eroare: caracter HEX invalid sau format gresit.$'
    msg_badlen  db 13,10,'Eroare: trebuie intre 8 si 16 octeti.$'
    
    ; --- Mesaje Rezultate ---
    msg_c       db 13,10,'4. Cuvantul C calculat: $'
    msg_sort    db 13,10,'5. Sirul sortat descrescator: $'

    ; --- Buffer DOS pentru functia 0Ah ---
    buf_max     db 80        ; Numar maxim de caractere
    buf_len     db 0         ; Aici DOS va scrie cate caractere a citit
    buf_text    db 80 dup(0) ; Aici va fi textul

    ; --- Variabile program ---
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
    ; === NIBBLE 1 (High) ===
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

    ; === NIBBLE 2 (Low) ===
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

; === VALIDARE SI ERORI ===
validare_finala:
    mov al, lungime
    cmp al, 8
    jb eroare_len            
    cmp al, 16
    ja eroare_len            
    
    mov dx, offset msg_ok
    mov ah, 09h
    int 21h
    jmp pasul_4

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


; ============================
;  CALCUL C SI AFISARE
; ============================
pasul_4:
    mov C, 0                 

    ; 1. Biti 0-3
    mov al, sir[0]           
    and al, 0Fh              
    xor bx, bx               
    mov bl, lungime
    dec bl                   
    lea si, sir
    add si, bx               
    mov bl, [si]             
    shr bl, 1                
    shr bl, 1
    shr bl, 1
    shr bl, 1                
    xor al, bl               
    and al, 0Fh              
    mov word ptr C, ax       

    ; 2. Biti 4-7
    xor bx, bx               
    xor cx, cx
    mov cl, lungime
    lea si, sir
pas4_or_loop:
    mov al, [si]
    shr al, 1
    shr al, 1                
    and al, 0Fh              
    or bl, al                
    inc si
    loop pas4_or_loop
    shl bl, 1                
    shl bl, 1
    shl bl, 1
    shl bl, 1
    or byte ptr C, bl        

    ; 3. Biti 8-15
    xor ax, ax               
    xor cx, cx
    mov cl, lungime
    lea si, sir
pas4_sum_loop:
    xor bx, bx
    mov bl, [si]
    add ax, bx
    inc si
    loop pas4_sum_loop
    mov byte ptr [C+1], al

    ; --- AFISARE C (WORD) ---
    mov ah, 09h
    mov dx, offset msg_c
    int 21h

    mov bx, C        ; Luam valoarea lui C
    mov cx, 4        ; 4 cifre hexa
print_c_loop:
    rol bx, 1        ; Rotim stanga 4 pozitii (sa aducem nibble-ul sus)
    rol bx, 1
    rol bx, 1
    rol bx, 1
    
    mov dl, bl
    and dl, 0Fh      ; Pastram ultimii 4 biti
    
    cmp dl, 9
    jbe pc_digit
    add dl, 37h      ; 'A'-10
    jmp pc_print
pc_digit:
    add dl, 30h      ; '0'
pc_print:
    mov ah, 02h
    int 21h
    loop print_c_loop


; ============================
; SORTARE SI AFISARE
; ============================
    cmp lungime, 2
    jb pasul_5_afisare       ; Daca < 2 elem, nu sortam, doar afisam

    xor cx, cx
    mov cl, lungime
    dec cl                   ; N-1
sort_ext:
    lea si, sir
    mov dl, cl               ; DL contor intern
sort_int:
    mov al, [si]
    mov bl, [si+1]
    cmp al, bl
    jae no_swap              ; Descrescator

    ; Swap
    mov [si], bl
    mov [si+1], al
no_swap:
    inc si
    dec dl
    jnz sort_int
    
    dec cl                   
    jnz sort_ext

pasul_5_afisare:
    ; --- AFISARE SIR SORTAT ---
    mov ah, 09h
    mov dx, offset msg_sort
    int 21h

    lea si, sir
    xor cx, cx
    mov cl, lungime
    
print_sir_loop:
    mov bl, [si]
    
    ; High Nibble
    mov dl, bl
    shr dl, 1
    shr dl, 1
    shr dl, 1
    shr dl, 1
    cmp dl, 9
    jbe ps_d1
    add dl, 37h
    jmp ps_p1
ps_d1: add dl, 30h
ps_p1:
    mov ah, 02h
    int 21h
    
    ; Low Nibble
    mov dl, bl
    and dl, 0Fh
    cmp dl, 9
    jbe ps_d2
    add dl, 37h
    jmp ps_p2
ps_d2: add dl, 30h
ps_p2:
    mov ah, 02h
    int 21h
    
    ; Spatiu
    mov dl, ' '
    int 21h
    
    inc si
    loop print_sir_loop

final:
    mov ax, 4C00h
    int 21h

code ends
end start