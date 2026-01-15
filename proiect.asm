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
	
	; --- Mesaje si Variabile noi pentru nr_max_octeti 1 si pentru a afisa sirul nou ---
    msg_step6   db 13,10,'6. Max biti 1 (Valoare HEX / Pozitie / NrBiti): $'
    msg_none    db ' Nu exista octet cu minim 3 biti de 1.$'
    msg_step7   db 13,10,'7. Sir rotit (N=suma primi 2 biti) BIN -> HEX:',13,10,'$'
    msg_sep     db ' / $'
    msg_arrow   db ' -> $'
    msg_nl      db 13,10,'$'

    max_val     db 0        ; Numarul maxim de biti gasit
    max_pos     db 0        ; Pozitia in sir (0 based)
    max_oct     db 0        ; Valoarea octetului
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
    lea si, buf_text     ; SI pointează la începutul textului     
    lea di, sir          ; DI pointează la începutul vectorului    
    
    xor cx, cx           ;   CX = 0           
    mov cl, buf_len      ;  CX = numărul de caractere citite       
    cmp cx, 0            ;  Verifică dacă s-a introdus ceva
    je reincearca        ; ; Dacă nu, cere din nou input
   

parsare:
    cmp cx, 0           ; Mai sunt caractere?
    jg continua_parsare  ; Dacă da, continuă
    jmp validare_finala    ; Dacă nu, verifică rezultatul     

continua_parsare:
    ; Sarim peste spatii
    mov al, [si]      ; Citește caracterul curent   
    cmp al, ' '        ; Este spațiu?
    jne incepe_octet    ; Dacă nu, începe citirea unui octet
    inc si             ; Sare peste spațiu
    dec cx
    jmp parsare

incepe_octet:
    cmp cx, 2           ; Avem cel puțin 2 caractere?
    jae ok_2car
    jmp eroare_hex        ; Altfel eroare

ok_2car:
    ; === Octetul 1 (High) ===
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
    sub al, '0'      ; '0'–'9' → 0–9
    jmp n1_gata
n1_lit_mare:
    sub al, 'A'
    add al, 10        ; 'A'–'F' → 10–15
    jmp n1_gata
n1_lit_mica:
    sub al, 'a'
    add al, 10
n1_gata:
    mov ah, al          ; AH = nibble mare          
    inc si                   
    dec cx

    ; ===Octetul 2 (Low) ===
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
    add al, ah       ; AL = octet complet        

    mov [di], al      ; Salvează octetul în vector        
    inc di             ; Treci la următoarea poziție         
    
    mov bl, lungime     ; BL = număr octeți
    inc bl                   ; Crește contorul
    mov lungime, bl        ; Depășește 16?
    
    cmp bl, 16
    ja eroare_len            

    inc si           ; Treci mai departe în text           
    dec cx
    jmp parsare

n1_err_tr: jmp eroare_hex
n2_err_tr: jmp eroare_hex

; === VALIDARE SI ERORI ===
validare_finala:
    mov al, lungime
    cmp al, 8         ;  Minim 8 octeți
    jb eroare_len            
    cmp al, 16           ; Maxim 16 octeți
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

    ; 1. Biti 0-3 din C 
	;facem xor intre octetul superior si cel inferior
    mov al, sir[0]     ;al = primul element din sir    
    and al, 0Fh        ;pastram bitii 0-3 ai octetului inferior      
    xor bx, bx          ; BX = 0   
    mov bl, lungime  ; BL = lungimea sirului
    dec bl              ; BL = lungime - 1 (index ultim element)
    lea si, sir          ; SI = adresa de inceput a sirului
    add si, bx       ; SI = adresa ultimului element         
    mov bl, [si]    ; BL = ultimul element din sir          
    shr bl, 1        ; Deplasam la dreapta octetul superior         
    shr bl, 1        ; (bitii 4–7 ajung in 0–3)
    shr bl, 1        
    shr bl, 1                
    xor al, bl        ;XOR intre cei doi octeti        
    and al, 0Fh              
    mov word ptr C, ax    ; Punem rezultatul in bitii 0–3 ai lui C
   

    ; 2. Biti 4-7
	; OR intre bitii 2–5 (dupa shift) ai tuturor elementelor
    xor bx, bx      ; BL = 0 (acumulator pentru OR)         
    xor cx, cx
    mov cl, lungime ; CX = lungime sir

    lea si, sir ;  ; SI = inceputul sirului

pas4_or_loop:
    mov al, [si] ; AL = element curent 
    shr al, 1 ; Deplasam la dreapta 2 pozitii
    shr al, 1                
    and al, 0Fh   ; Pastram 4 biti             
    or bl, al    ; OR cu rezultatele anterioare            
    inc si         ; Trecem la elementul urmator
    loop pas4_or_loop    ; Repetam pentru toate elementele
    shl bl, 1        ; Mutam rezultatul in pozitia 4–7        
    shl bl, 1
    shl bl, 1
    shl bl, 1
    or byte ptr C, bl   ; Inseram bitii 4–7 in C     

    ; 3. Biti 8-15
    xor ax, ax             ; AX = 0 (suma)  
    xor cx, cx
    mov cl, lungime        ; CX = lungime sir
    lea si, sir
pas4_sum_loop:
    xor bx, bx
    mov bl, [si]           ; BL = element curent
    add ax, bx             ; Adunam la suma
    inc si                  ; Repetam
    loop pas4_sum_loop
    mov byte ptr [C+1], al  ; Byte-ul superior al lui C = suma (AL)

    ; --- AFISARE C (WORD) ---
    mov ah, 09h
    mov dx, offset msg_c        ; Afisam mesajul "C = "
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
    jbe pc_digit     ; Daca e cifra 0–9
    add dl, 37h      ; 'A'-10
    jmp pc_print
pc_digit:
    add dl, 30h      ; '0'
pc_print:
    mov ah, 02h      ;  Afisam caracterul
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
    lea si, sir              ;; SI = inceput sir
    mov dl, cl               ; DL contor intern
sort_int:
    mov al, [si]		; AL = element curent
    mov bl, [si+1]       ; BL = element urmator
    cmp al, bl
    jae no_swap              ; Descrescator

    ; Swap
    mov [si], bl             
    mov [si+1], al           
no_swap:
    inc si          ; Avansam in sir
    dec dl             ; Continuam bucla interioara
    jnz sort_int     ;  Continuam bucla exterioara
    
    dec cl                   
    jnz sort_ext

pasul_5_afisare:
    ; --- AFISARE SIR SORTAT ---
    mov ah, 09h
    mov dx, offset msg_sort   ; Mesaj "Sir sortat:"
    int 21h

    lea si, sir
    xor cx, cx
    mov cl, lungime            ;CX = lungime sir
    
print_sir_loop:
     mov bl, [si]                ; BL = element curent
    
    ;Octetul high
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
    
   ;Octetul low
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
    
    inc si              ; Urmatorul element
    loop print_sir_loop
; ============================
;  MAX BITI DE 1
; ============================
    mov ah, 09h
    mov dx, offset msg_step6
    int 21h

    ; Initializare variabile
    mov max_val, 0
    
    lea si, sir
    xor ch, ch          ; CH va fi indexul curent (0..lungime-1)

cauta_max_loop:
    cmp ch, lungime
    je afisare_max      ; Daca am terminat sirul, mergem la afisare

    mov bl, [si]        ; Luam octetul curent
    
    ; Numaram bitii de 1 din BL
    mov al, bl          ; Facem o copie in AL sa o distrugem
    xor dl, dl          ; DL = contor biti pentru acest octet
    mov cl, 8           ; 8 biti de verificat

numara_biti:
    shl al, 1           ; Shiftam stanga, bitul iese in Carry Flag (CF)
    jnc nu_e_unu
    inc dl              ; Daca CF=1, incrementam contorul
nu_e_unu:
    ; Nu folosim LOOP pentru a proteja CH ---
    dec cl              ; Scadem manual CL
    jnz numara_biti     ; Daca CL nu e 0, sare inapoi
    ; ------------------------------------------------------------

    ; Verificare conditie: minim 3 biti
    cmp dl, 3
    jb urmatorul_octet

    ; Verificare daca e maxim
    cmp dl, max_val
    jbe urmatorul_octet ; Daca nu e mai mare strict, trecem mai departe
    
    ; Am gasit un nou maxim
    mov max_val, dl
    mov max_pos, ch
    mov max_oct, bl

urmatorul_octet:
    inc si
    inc ch
    jmp cauta_max_loop

afisare_max:
    cmp max_val, 0
    je nu_exista_max

    ; 1. Afisare Valoare Octet (HEX)
    mov bl, max_oct
    
    ; Octetul high
    mov dl, bl
    shr dl, 1
    shr dl, 1
    shr dl, 1
    shr dl, 1
    cmp dl, 9
    jbe pm_d1
    add dl, 37h
    jmp pm_p1
pm_d1: add dl, 30h
pm_p1: mov ah, 02h
    int 21h
    
    ; Octetul low
    mov dl, bl
    and dl, 0Fh
    cmp dl, 9
    jbe pm_d2
    add dl, 37h
    jmp pm_p2
pm_d2: add dl, 30h
pm_p2: int 21h

    ; Separator
    mov ah, 09h
    mov dx, offset msg_sep
    int 21h

    ; 2. Afisare Pozitie
    mov dl, max_pos
    inc dl
    
    cmp dl, 10
    jb poz_o_cifra
    
    push dx
    mov dl, '1'
    mov ah, 02h
    int 21h
    pop dx
    sub dl, 10

poz_o_cifra:
    add dl, 30h
    mov ah, 02h
    int 21h

    ; Separator
    mov ah, 09h
    mov dx, offset msg_sep
    int 21h

    ; 3. Afisare Numar Biti
    mov dl, max_val
    add dl, 30h
    mov ah, 02h
    int 21h
    jmp pasul_7_start

nu_exista_max:
    mov ah, 09h
    mov dx, offset msg_none
    int 21h
; ============================
; CALCUL SUMA BITI SI ROTIRE
; ============================
pasul_7_start:
    mov ah, 09h
    mov dx, offset msg_step7
    int 21h

    lea si, sir
    xor ch, ch          ; CH = contor general elemente
    
loop_rotire:
    cmp ch, lungime
    je final_program

    mov bl, [si]        ; BL = octetul original
    
    ; a) Calcul suma primilor 2 biti (bit 0 si bit 1)
    ; N = (Bit0) + (Bit1)
    mov al, bl
    and al, 1           ; al = valoarea bitului 0 (0 sau 1)
    
    mov ah, bl
    and ah, 2           ; ah = valoarea bitului 1 (0 sau 2)
    shr ah, 1           ; ah devine 0 sau 1
    
    add al, ah          ; AL = N (suma, poate fi 0, 1 sau 2)
    
    ; b) Rotire stanga cu N pozitii
    mov cl, al          ; Mutam N in CL pentru rotire
    cmp cl, 0
    je setare_print     ; Daca N=0, nu rotim
    rol bl, cl          ; Rotire efectiva (BL se modifica)

setare_print:
    ; c) Afisare BINAR (8 biti)
    ; NU folosim PUSH CX aici pentru ca evitam LOOP
    mov cl, 8
    mov bh, bl          ; Copie pentru afisare binara

print_bin:
    shl bh, 1           ; Scoatem bitul cel mai semnificativ in Carry
    jc e_unu
    mov dl, '0'
    jmp scrie_bit
e_unu:
    mov dl, '1'
scrie_bit:
    mov ah, 02h
    int 21h
    
    
    dec cl              ; Scadem doar CL (nu atingem CH)
    jnz print_bin       ; Daca CL != 0, continuam


    ; Sageata separator
    mov ah, 09h
    mov dx, offset msg_arrow
    int 21h

    ; d) Afisare HEX
    ; High Nibble
    mov dl, bl
    shr dl, 1
    shr dl, 1
    shr dl, 1
    shr dl, 1
    cmp dl, 9
    jbe p7_d1
    add dl, 37h
    jmp p7_p1
p7_d1: add dl, 30h
p7_p1:
    mov ah, 02h
    int 21h

    ; Low Nibble
    mov dl, bl
    and dl, 0Fh
    cmp dl, 9
    jbe p7_d2
    add dl, 37h
    jmp p7_p2
p7_d2: add dl, 30h
p7_p2:
    mov ah, 02h
    int 21h

    ; Linie noua
    mov ah, 09h
    mov dx, offset msg_nl
    int 21h

    inc si
    inc ch
    jmp loop_rotire

final_program:
    mov ax, 4C00h
    int 21h
code ends
end start
