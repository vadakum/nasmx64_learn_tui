;-------------------------------------------------------------------------
; mountain.asm
;
; Take a number input from user and print a mountain.
; Note: For the internal function we will follow the 
;       System V AMD64 ABI for function arguments:
;       arg1 -> rdi, arg2 -> rsi, arg3 -> rdx 
;
;
; Program Logic: 
; Loop to fill and print the framebuffer.
; During each iteration we need a start index in the buffer
; and the count of char to be filled in:
; initial start_index = ((x + 1) / 2) - 1 = 5
;             start_index | char_count
;012345       -------------+-----------
;     ^             5     |   1
;    ^^^            4     |   3
;   ^^^^^           3     |   5
;  ^^^^^^^          2     |   7
; ^^^^^^^^^         1     |   9
;^^^^^^^^^^^        0     |   11
;             ------------+-----------
;                idx -= 1 | n += 2  
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > nasm -g -f elf64 mountain.asm && gcc mountain.o -o mountain.bin
; Run the program:
; > ./mountain.bin  
; > Enter an odd base length from 1 to 63 (e.g., 27):  
;-------------------------------------------------------------------------

; Data Section
section .data 
    prompt_msg:      db  "Enter an odd base length from 1 to 63 (e.g., 27): ", 0
        .LEN:        equ $-prompt_msg
    err_msg:         db  "Invalid base length !", 0xA, 0
        .LEN:        equ $-err_msg
    char_disp:       db   '^'
    char_filler:     db   ' '

; BSS Section
section .bss
    input_buffer:    resb 16    ; Buffer to store user input string
           .LEN:     equ 16

    buffer:          resb 64    ; Un-initialized buffer
        .MAX_SZ:     equ  64    

; Code Section
section .text
global main 
main:
    ; Standard prologue
    push rbp
    mov rbp, rsp

    ; Get Base Length from User
    ; 1. Print a prompt message
    mov rax, 1              ; syscall: sys_write
    mov rdi, 1              ; fd: STDOUT
    mov rsi, prompt_msg
    mov rdx, prompt_msg.LEN
    syscall

    ; 2. Read user input from stdin
    mov rax, 0              ; syscall: sys_read
    mov rdi, 0              ; fd: STDIN
    mov rsi, input_buffer
    mov rdx, input_buffer.LEN
    syscall
    ; rax now contains the number of bytes read.

    ; 3. Convert the input string to an integer
    mov rdi, input_buffer   ; Pass buffer address to our atoi function.
    call atoi               ; rax will hold the integer result
    mov rcx, rax            ; rcx = base_length from user

    ; 4. Validate the base_length, to protect buffer access
    mov rax, buffer.MAX_SZ
    sub rax, 1        ; For filling in '\n' in the last byte
    cmp rcx, rax      ; Compare (rcx - rax). `cmp` sets rflags, operands are not modified
    jg  .print_error  ; Jump if rcx(user input) > rax (MAX_SZ)

    ; Also check if the number is odd. 
    ; A odd  number in binary ends with 1 as ...001101 b
    ; A even number in binary ends with 0 as ...001100 b
    ; Number 1 is odd and end with 1         ...000001 b
    test rcx, 1     ; Performs bitwise `and`, only setting flags
    jz .print_error ; Jump if Zero -> jump if even

    ; --- End of User Input Section ---

    ; We will be calling functions (`fill_char`, `print_buffer`) inside a loop.
    ; To preserve loop variables across these function calls, we have two choices:
    ; 1. Use caller-saved registers (like rax, rcx, rdx) and push/pop them around
    ;    each `call`.
    ; 2. Use callee-saved registers (rbx, rbp, r12-r15). The convention states
    ;    that if a function uses these, it must restore them before it returns.
    ;    i.e., They will persist across function calls.

    ; The `main` function is called by the C runtime, making `main` a "callee".
    ; Therefore, we must save any callee-saved registers that would be modified
    ; (to be restored before `main` returns).
    ; We are going to use r12, r13, r14 and r15, push them to stack. Are we are
    ; pushing 4 (8byte) registers the stack stays aligned at 16 bytes.
    push r12
    push r13
    push r14
    push r15   

    ; Assign loop variables to callee-saved registers.
    ; r12 for base_length
    ; r13 for the start_index: loop variant
    ; r14 for the char_count: increases while iterating 
    ; r15 for print_buffer buffer_size 
    mov r12, rcx ; r12 = base_length

    ; Fill the buffer with a filler and '\n'.
    ; Prepare arguments for fill_char
    mov rdi, buffer       ; lea rdi, [buffer] will also work
    mov rsi, r12          ; rsi = base_length
    mov rdx, char_filler  ; rdx = address of char_filler
    call fill_char          
    mov byte [buffer + r12], 0xA ; set buffer[base_length] = '\n'
    mov r15, r12                 ; r15 = base_length
    inc r15                      ; r15 = base_length + 1 (2nd arg for print_buffer)

    ; Calculate start_index = ((x + 1) / 2) - 1
    xor rdx, rdx    ; Clear rdx, as the `div` instruction uses rdx:rax as the dividend
    mov rax, r12    ; rax = base_length
    add rax, 1      ; rax += 1
    mov rbx, 2      ; rbx = divisor
    div rbx         ; rax = (base_length + 1) / 2
    dec rax         ; rax -= 1 = start_index
    mov r13, rax    ; r13 = start_index

    mov r14, 1      ; Set display char_count to 1

.loop_start: 
    ; Prepare arguments for fill_char
    lea rdi, [buffer + r13] ; buffer + start_index
    mov rsi, r14            ; rsi = char_count
    mov rdx, char_disp      ; rdx = addess of char
    call fill_char

    ; Prepare arguments for print_buffer
    mov rdi, buffer
    mov rsi, r15
    call print_buffer

    dec r13         ; start_index -= 1
    add r14, 2      ; char_count += 2
    cmp r13, 0      ; loop until the start_index is less than 0
    jge .loop_start ; Jump if Greater or Equal to 0

    ; Clean up
    ; Restore the callee-saved registers we used. This must be in the reverse
    ; order of how they were pushed onto the stack.
    pop r15
    pop r14
    pop r13
    pop r12
    
    mov rdi, 0  ; exit code 0 (success)
    jmp exit

.print_error:
    ; Print the error message and exit with a non-zero status code
    mov rax, 1          ; syscall: sys_write
    mov rdi, 2          ; fd: STDERR
    mov rsi, err_msg
    mov rdx, err_msg.LEN
    syscall

    mov rdi, 1          ; exit code 1 (failure)
    jmp exit

exit:
    ; Standard epilogue
    leave
    ; Exit
    mov rax, 60 ; rax = sys_exit = 60
    syscall     


; Function: atoi -- Converts an ASCII string of digits to an integer.
; Args: 
;   rdi: address of the string
; Return: 
;   rax: integer value
atoi:
    ; Standard prologue
    push rbp
    mov rbp, rsp

    xor rax, rax        ; Clear rax, our accumulator for the final number.
    xor rcx, rcx        ; Clear rcx, used to hold the current character.
                        ; rax and rcx are Caller-Saved Registers, so we don't
                        ; have to save their previous values here.
.next_char:
    mov cl, [rdi]       ; Dereference one char from the string.
    inc rdi             ; Point to the next character for the next iteration.

    ; Check if the character is a digit. If not, we're done.
    cmp cl, '0'
    jl .done            ; If less than '0' (e.g., null terminator), jump to done
    cmp cl, '9'
    jg .done            ; If greater than '9' (e.g., newline), jump to done.

    ; Convert the ASCII character to its integer value.
    ; Subtracting '0' from the ASCII char would give us the actual number value 
    ; e.g; '4' - '0' => (52 - 48 = 4)
    sub cl, '0'

    ; Add the digit to our accumulator.
    ; First, multiply the current total by 10.
    imul rax, rax, 10
    ; Then, add the new digit.
    add rax, rcx

    jmp .next_char     ; loop
.done:
    leave   ; Standard epilogue
    ret     ; The result is in rax.

; Function: fill_char -- fill buffer with a char count times
; Args:
;  rdi: address of buffer
;  rsi: count
;  rdx: address to char
fill_char:
    push rbp
    mov rbp, rsp
    ; We will use the `rep stosb` instruction, an efficient way to fill
    ; a portion of the passed in buffer. `stosb` stores the byte from `al` into 
    ; the memory location pointed to by rdi, and then increments/decrements rdi.
    ; `rep` repeats the `stosb` instruction rcx times.

    ; Setup for `rep stosb`:
    ; al: The byte value to be stored.
    ; rdi: The destination address.
    ; rcx: The number of times to repeat the operation.
    mov al, [rdx]  ; al = char to fill
    mov rdi, rdi   ; rdi = buffer
    mov rcx, rsi   ; rcx = count
    rep stosb
    
    leave
    ret

; Function: print_buffer -- print buffer to STDOUT
; Args:
;   rdi: address of buffer
;   rsi: buffer size
print_buffer:
    push rbp
    mov rbp, rsp

    mov rax, 1     ; syscall number: SYS_WRITE
    mov rdx, rsi   ; arg3: number of bytes
    mov rsi, rdi   ; arg2: buffer to write
    mov rdi, 1     ; arg1: file descriptor: STDOUT    
    syscall  
    
    leave
    ret         
