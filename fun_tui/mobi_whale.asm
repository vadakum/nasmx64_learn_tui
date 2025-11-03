;-------------------------------------------------------------------------
; mobi_whale.asm
;
; Mobi (the whale) responds to left/right arrow keys.
;
; - Use termbox2.h for terminal input/output (it's added as a dependency 
;    in the Makefile). termbox2 is an alternative to ncurses and has 
;    built-in support for popular terminals. It's a single header file 
;    library. 
; - For documentation on termbox2 api, please refer to termbox2/termbox2.h 
;-------------------------------------------------------------------------
; Build:
; > make 
;   or
; > cd termbox2 && make # (run once for creating libtermbox2.a)  
; > nasm -g -f elf64 mobi_whale.asm && gcc -g mobi_whale.o -L ./termbox2 -l termbox2 -o mobi_whale.bin
;-------------------------------------------------------------------------

extern setlocale
extern printf

;**********************************************************
; termbox2  externs and constants from termbox2/auto_gen_*
;**********************************************************
extern tb_init        ; int tb_init(void)
extern tb_shutdown    ; int tb_shutdown(void)
extern tb_print       ; int tb_print(int x, int y, uint64_t fg, uint64_t bg, const char *str)
extern tb_printf      ; int tb_printf(int x, int y, uint64_t fg, uint64_t bg, const char *fmt, ...)
extern tb_set_cell    ; int tb_set_cell(int x, int y, uint32_t ch, uint64_t fg, uint64_t bg)
extern tb_present     ; int tb_present(void)
extern tb_clear       ; int tb_clear(void)
extern tb_attr_width  ; int tb_attr_width()
extern tb_width       ; int tb_width(void)
extern tb_height      ; int tb_height(void)
extern tb_poll_event  ; int tb_poll_event(void *event)
extern tb_peek_event  ; int tb_peek_event(struct tb_event *event, int timeout_ms)
; Return Code
%define TB_OK                  0
; Colors
%define TB_BLACK               0x0001
%define TB_RED                 0x0002
%define TB_GREEN               0x0003
%define TB_YELLOW              0x0004
%define TB_BLUE                0x0005
%define TB_MAGENTA             0x0006
%define TB_CYAN                0x0007
%define TB_WHITE               0x0008
; Attributes
%define TB_BOLD                0x01000000
%define TB_UNDERLINE           0x02000000
%define TB_REVERSE             0x04000000
%define TB_ITALIC              0x08000000
%define TB_BLINK               0x10000000
%define TB_HI_BLACK            0x20000000
%define TB_BRIGHT              0x40000000
%define TB_DIM                 0x80000000
; Events
%define TB_EVENT_KEY 1
%define TB_EVENT_RESIZE 2
%define TB_EVENT_MOUSE 3
; Keys
%define TB_KEY_ESC             0x1b
%define TB_KEY_ARROW_LEFT      (0xffff - 20)
%define TB_KEY_ARROW_RIGHT     (0xffff - 21)
;**********************************************************

%define SYSCALL_CLOCK_GETTIME   228
%define CLOCK_REALTIME          0
%define UPDATE_INTERVAL_MS      150 ; millisec
%define PEEK_EVENT_TIMEOUT_MS   150 ; millisec
%define QUIT_EVENT_LOOP         1   

; Nasm structure macro (for named offsets and fishtype_size)
struc fishtype
    .add_off:   resq 1  ; Address of the fish.(left/right)_buff
    .c_attr_q:  resq 1  ; Color | Attribute
    .x_d:       resd 1  ; x coordinate 
    .y_d:       resd 1  ; y coordinate 
    .dir_d:     resd 1  ; Direction (-1 left, 1 right)
endstruc 

; Data Section
; This will be our read-only data section
section .data 
    ; Drawing area (frame box), adjust START_X and START_Y to shift the 
    ; entire drawing area
    screen:
        .START_X    equ 5
        .START_Y    equ 2
        .MAX_WIDTH  equ 80
        .MAX_HEIGHT equ 40

    ; Locale for unicode support
    locale:
        .arg1       dd 6
        .arg2:      db 0x0

    ; Termbox2 init failed message
    tb_init_failed_msg: db "Failed to initialize termbox2", 0xA, 0        

    ; Unicode codepoints
    uchar:
        ; https://en.wikipedia.org/wiki/Box-drawing_characters
        ; Define box corners
        .BOX_TOP_LEFT:       equ 0x250C  ; '┌'
        .BOX_TOP_RIGHT:      equ 0x2510  ; '┐'
        .BOX_BOTTOM_LEFT:    equ 0x2514  ; '└'
        .BOX_BOTTOM_RIGHT:   equ 0x2518  ; '┘'
        .BOX_VERT:           equ 0x2502  ; '│', longer than the pipe char '|'
        .BOX_HORIZ:          equ 0x2500  ; '─', wider than the dash char '-' 

    ; Instruction string
    str_instr:      db "o Press <-left / right-> arrow keys to move Mobi the whale.", 0xA,
                    db "o Press ESC to quit.", 0xA,
                    db "o ASCII art (www.asciiart.eu): Riitta Rasmus, Linda Ball, jgs and pr59", 0  
        .START_X:   equ screen.START_X + 1            
        .START_Y:   equ screen.START_Y + screen.MAX_HEIGHT - 3
        .COLOR:     equ (TB_GREEN)

    ; Ocean details
    ocean:
        .str_surf_pat:  db  "~^"
        .SURF_PAT_LEN:  equ $-ocean.str_surf_pat
        .START_X:       equ screen.START_X + 1   
        .COLOR:         equ (TB_BLUE | TB_BOLD)

    ; Whale details
    whale:
        .left_buff:
                    db  "     .               ", 0,
                    db  '    ":"              ', 0,
                    db  "  ___:____     |'\/'|", 0,
                    db  ",'        `.    \  / ", 0,
                    db  "|  0        \___/  | ", 0,
                    db  "^~^~^~^~^~^~^~^~^~^~ ", 0 
        .right_buff:
                    db  "               .     ", 0,
        .COL_SZ     equ $-whale.right_buff                                        
                    db  '              ":"    ', 0, 
                    db  "|'\/'|     ____:___  ", 0,   
                    db  " \  /    ,'        `.", 0,     
                    db  " |  \___/        0  |", 0,
                    db  " ~^~^~^~^~^~^~^~^~^~^", 0
        .ROW_SZ:    equ ($-whale.right_buff) / whale.COL_SZ                                                   
        .START_X:   equ screen.START_X + 15
        .START_Y:   equ screen.START_Y + 15 
        .MAX_LEFT:  equ screen.START_X + 1
        .MAX_RIGHT: equ screen.START_X + screen.MAX_WIDTH - whale.COL_SZ + 1
        .COLOR      equ (TB_CYAN | TB_BRIGHT)
        .str_ouch:  db "Ouch!", 0 
        .OUCH_LEN   equ $-whale.str_ouch      
        .COLOR_OUCH equ TB_RED | TB_BRIGHT | TB_BLINK         

    ; Fish details
    fish:
        .left_buff:
                    db "o  O       ", 0,   
                    db " o   _/_   ", 0,   
                    db "  . /o  \//", 0,       
                    db "    =___/\\", 0,          
                    db "     ''    ", 0
        .right_buff:
                    db "       O  o", 0, 
        .COL_SZ     equ $-fish.right_buff
                    db "   _\_   o ", 0, 
                    db "\\/  o\ .  ", 0,  
                    db "//\___=    ", 0,  
                    db "   ''      ", 0 
        .ROW_SZ     equ ($-fish.right_buff) / fish.COL_SZ
        .START_X    equ whale.START_X
        .START_Y1   equ whale.START_Y + whale.ROW_SZ + 2 
        .COUNT      equ 2 ; 2 fishes
        .COLOR1     equ TB_YELLOW
        .COLOR2     equ (TB_MAGENTA | TB_BRIGHT)

    ;Cloud details
    clouds:
        .buff:
                    db	"                                           _ .   ", 0,
        .COL_SZ     equ $-clouds.buff
                    db	"                                         (  _ )_ ", 0,
                    db	"                                       (_  _(_ ,)", 0,		  
                    db	"    _  _                   _                     ", 0,       
                    db	"   ( `   )_               (  )                   ", 0,          
                    db	"  (    )    `)         ( `  ) . )                ", 0,              
                    db	"(_   (_ .  _) _)      (_, _(  ,_)_)              ", 0                                 
        .ROW_SZ     equ ($-clouds.buff) / clouds.COL_SZ
        .START_X    equ screen.START_X + 2
        .START_Y    equ screen.START_Y + 4
        .COLOR      equ TB_WHITE | TB_DIM 

    ; Helicopter details
    helicopter:
        .buff:
                    db "  -----+-----", 0,
        .COL_SZ     equ $-helicopter.buff                    
                    db "     _,|__   ", 0,
                    db "X====)59\_\  ", 0,
                    db "     \___ _) ", 0,     
                    db "    --`--`--'", 0,
                    db "    \  Hi   \", 0,
                    db "    / Mobi! /", 0,
                    db "    -------- ", 0
        .ROW_SZ     equ ($-helicopter.buff) / helicopter.COL_SZ
        .START_X    equ clouds.START_X + clouds.COL_SZ + 2
        .START_Y    equ screen.START_Y + 2
        .COLOR      equ TB_WHITE

    ; Helicopter blade rotation frames
    heli_blade:
        .frames:
                    db "  *----*----*", 0, 
        .COL_SZ     equ $-heli_blade.frames   
                    db "   *---+---* ", 0, 
                    db "    *--*--*  ", 0, 
                    db "     *-+-*   ", 0, 
                    db "      * *    ", 0  
        .NUM_FRAMES equ ($-heli_blade.frames) / heli_blade.COL_SZ
        .COLOR      equ TB_WHITE | TB_DIM 

    ; Debug format for printf
    debug_num_fmt:  db "Debug print value: %d", 0xA, 0        

; BSS Section
section .bss
    ; Screen info
    screen_info:
        .height_d:  resd 1
        .width_d:   resd 1
    
    ; Ocean info
    ocean_info:
        .surface_buff  resb screen.MAX_WIDTH

    ;Helicopter blade info
    heli_blade_info:
        .curr_frame_addr_ptr:   resq 1
        .curr_frame_index_d:    resd 1            
        .dir_d:                 resd 1 

    ; Fish infos
    ; Allocate multiple fishes using fishtype
    fish_infos: resb fishtype_size * fish.COUNT 

    ; Whale info
    whale_info:
        .add_ptr:   resq 1
        .x_d:       resd 1 
        .y_d:       resd 1

    ; Keep track of time in millisec
    last_update_time_ms:   resq 1

    ; Timespec for clock_gettime syscall
    timespec: 
        .tv_sec:    resq 1
        .tv_nsec:   resq 1

    ; Termbox tb_event argument
    tb_event:
        .type_b: resb 1  ; one of  `TB_EVENT_*` constants
        .mod_b:  resb 1  ; bitwise `TB_MOD_*` constants
        .key_w:  resw 1  ; one of  `TB_KEY_*` constants
        .char_d: resd 1  ; a Unicode codepoint
        .w_d:    resd 1  ; resize width
        .h_d:    resd 1  ; resize height
        .x_d:    resd 1  ; mouse x
        .y_d:    resd 1  ; mouse y

; Code Section
section .text
global main
main: 
    push rbp
    mov rbp, rsp
    ; Set locale for unicode support
    ; termbox2 requires this for unicode chars
    call set_locale
    ; Init termbox2
    call tb_init
    cmp rax, TB_OK
    jne .tb_init_failed

    ; Initialize time
    call get_current_time_ms
    mov [last_update_time_ms], rax
    ; Initialize variables
    call init_drawing_states

.event_loop:
    call tb_clear
    ; Drawings
    call draw_frame_box
    call draw_footer_text
    call draw_clouds    
    call draw_helicopter
    call draw_ocean
    call draw_fishes
    call draw_whale
    ; Request display
    call tb_present
    ; Handle events, rax = return value
    call handle_events 
    cmp rax, QUIT_EVENT_LOOP
    je .quit
    ; Else continue loop 
    jmp .event_loop

.tb_init_failed:
    mov rdi, tb_init_failed_msg
    xor rax, rax ; variadic
    call printf

.quit:
    call tb_shutdown
    ; Cleanup
    leave
    ret

; Function: set_locale
; Args:
;   None
set_locale:
    push rbp
    mov rbp, rsp

    mov edi, [locale.arg1]
    mov rsi, locale.arg2
    call setlocale 
    ; Cleanup
    leave
    ret

; Function: init 
; Args:
;   None
init_drawing_states:
    push rbp
    mov rbp, rsp

    lea rax, [whale.right_buff]
    mov [whale_info.add_ptr], rax
    mov dword [whale_info.x_d], whale.START_X
    mov dword [whale_info.y_d], whale.START_Y
    call fill_ocean_surface
    call fill_fish_infos
    call fill_heli_blade_info
    ; Cleanup
    leave
    ret

; Function: handle_events
; Args: 
;   None
; Return: 
;   rax = 0 for success, QUIT_EVENT_LOOP if esc is pressed    
handle_events:
    push rbp
    mov rbp, rsp

    push rbx    ; Use Callee saved.
    sub rsp, 8  ; Align stack (16 bytes).

    ; Call tb_peek_event with timeout
    mov rdi, tb_event
    mov rsi, PEEK_EVENT_TIMEOUT_MS

    call tb_peek_event ; rax will have result
    cmp rax, TB_OK
    je .check_and_process_event 

    ; Assuming there are no errors, call time_update_handler
    ; to update time / call timer events
    call time_update_handler
    jmp .ret_success
.check_and_process_event:
    call time_update_handler
    cmp byte [tb_event.type_b], TB_EVENT_KEY
    je .process_key_event
    ; TODO: Handle other events like TB_EVENT_RESIZE
    jmp .ret_success
.process_key_event:
    mov ebx, [tb_event.key_w]

    cmp rbx, TB_KEY_ARROW_LEFT  
    je .process_key_arrow_left

    cmp rbx, TB_KEY_ARROW_RIGHT
    je .process_key_arrow_right
    
    cmp rbx, TB_KEY_ESC
    je .process_key_esc

    ; Handle other keys
    jmp .ret_success
.process_key_arrow_left:
    call move_whale_left
    jmp .ret_success
.process_key_arrow_right:
    call move_whale_right
    jmp .ret_success
.process_key_esc:    
    jmp .ret_quit
.ret_success:
    mov rax, 0
    jmp .done
.ret_quit:
    mov rax, QUIT_EVENT_LOOP
    jmp .done
.done:
    ; Cleanup
    add rsp, 8 
    pop rbx
    leave
    ret

; Function: time_update_handler
; Args:
;   None
time_update_handler:
    push rbp
    mov rbp, rsp

    call get_current_time_ms        ; rax = current_time_ms
    mov rcx, rax                    ; Save the current time.    
    mov rdx, [last_update_time_ms]  ; Get last update time.  
    sub rax, rdx                    ; current_time_ms - last_update_time_ms
    cmp rax, UPDATE_INTERVAL_MS     ; Check if its time to call on_time_update.
    jl .done
    ; Update last_update_time_ms
    mov [last_update_time_ms], rcx
    call on_time_update
.done:
    ; Cleanup
    leave
    ret

; Function: on_time_update -- do all the background drawing
; Args:
;   None
on_time_update:
    push rbp
    mov rbp, rsp

    call move_fishes
    call move_helicopter_blades
    ; Cleanup
    leave
    ret
    
; Function: save_screen_dim -- TODO: unused
; Args:
;   None
save_screen_dim:
    push rbp
    mov rbp, rsp

    call tb_width                   
    mov [screen_info.width_d], eax  ; Save width
    call tb_height
    mov [screen_info.height_d], eax ; Save height
    ; Cleanup
    leave
    ret

; Function: move_fishes 
; Args:
;   None
move_fishes:
    push rbp
    mov rbp, rsp

    xor rcx, rcx   ; FishCounter
.loop_fishes:
    ; Point rsi the address of next fish_info x coordinate address
    ; lea rsi, [fish_infos + (fishtype_size * FishCounter) + fishtype.x_d]
    mov rax, fishtype_size
    mul rcx 
    lea rsi, [fish_infos + rax]
    mov edx, dword [rsi + fishtype.x_d] ; edx = value of x coordinate

    add edx, dword [rsi + fishtype.dir_d]

    cmp edx, screen.START_X + 1
    jle .flip_right

    cmp edx, screen.START_X + screen.MAX_WIDTH - fish.COL_SZ
    jg .flip_left

    ; Continue in the same direction
    jmp .update_x_coord
.flip_right:
    mov dword [rsi + fishtype.dir_d], 1
    mov qword [rsi + fishtype.add_off], fish.right_buff
    mov edx, screen.START_X + 1
    jmp .update_x_coord
.flip_left:
    mov dword [rsi + fishtype.dir_d], -1
    mov qword [rsi + fishtype.add_off], fish.left_buff
    sub edx, 1  ; or edx = screen.START_X + screen.MAX_WIDTH - fish.COL_SZ
    jmp .update_x_coord
.update_x_coord:
    mov dword [rsi + fishtype.x_d], edx
    inc rcx
    cmp rcx, fish.COUNT
    jl .loop_fishes
    ; Cleanup
    leave
    ret

; Function: move_helicopter_blades
; Args: 
;   None
move_helicopter_blades:
    push rbp 
    mov rbp, rsp

    mov ecx, dword [heli_blade_info.curr_frame_index_d] 
    add ecx, dword [heli_blade_info.dir_d]
    cmp ecx, heli_blade.NUM_FRAMES 
    jge .backward
    cmp ecx, 0 
    jl .forward 
    jmp .done
.backward:
    mov dword [heli_blade_info.dir_d], -1
    mov ecx, heli_blade.NUM_FRAMES - 1
    jmp .done
.forward:    
    mov dword [heli_blade_info.dir_d], 1
    mov ecx, 1
    jmp .done
.done:  
    ; Update frame_index and address
    mov dword [heli_blade_info.curr_frame_index_d], ecx
    ; heli_blade.frames + rcx * heli_blade.COL_SZ
    mov rax, heli_blade.COL_SZ
    mul rcx
    lea rsi, [heli_blade.frames +  rax]
    mov [heli_blade_info.curr_frame_addr_ptr], rsi 
    ; Cleanup
    leave
    ret

; Function: move_whale_left
; Args: 
;   None
move_whale_left:
    push rbp
    mov rbp, rsp

    mov rsi, whale.left_buff
    mov [whale_info.add_ptr], rsi
    mov eax, [whale_info.x_d]
    dec eax
    cmp eax, whale.MAX_LEFT
    jge .move                   ; If greater or equal, move
    jmp .done                   ; else, stop
.move:
    mov [whale_info.x_d], eax
.done:
    leave
    ret

; Function: move_whale_right
; Args: 
;   None
move_whale_right:
    push rbp
    mov rbp, rsp

    mov rax, whale.right_buff
    mov [whale_info.add_ptr], rax
    mov eax, [whale_info.x_d]
    inc eax
    cmp eax, whale.MAX_RIGHT
    jle .move                   ; If less or equal, move
    jmp .done                   ; else, stop  
.move:
    mov [whale_info.x_d], eax
.done:
    leave
    ret

; Function: draw_ocean
; Args:
;   None
draw_ocean:
    push rbp
    mov rbp, rsp
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rdi, ocean.START_X          ; 1. x
    mov rsi, [whale_info.y_d]       
    add rsi, whale.ROW_SZ - 1       ; 2. y + ROW_SZ
    mov rdx, TB_BLUE | TB_BOLD      ; 3. fg
    mov rcx, 0                      ; 4. bg
    mov r8, ocean_info.surface_buff ; 5. String address
    call tb_print
    ; Cleanup
    leave
    ret

; Function: draw_fishes
; Args:
;   None
draw_fishes:
    push rbp
    mov rbp, rsp

    push rbx
    push r12 
    push r13
    sub rsp, 8     ; Align stack

    xor r12, r12   ; Fish counter
.loop_fishes:
    ; Point r13 the address of next fish_info
    ; lea r13, [fish_infos + (fishtype_size * Fish counter)]
    mov rax, fishtype_size
    mul r12 
    lea r13, [fish_infos + rax]
    ; Reset Row counter
    xor rbx, rbx                  ; rbx = rowcount  = 0
.loop_fish_rows:
    ; Get x coordinate or the fish buffer
    mov rdi, [r13 + fishtype.x_d] ; rdi = x
    ; Get y coordinate or the fish row
    mov rsi, [r13 + fishtype.y_d] ; rsi = y
    add rsi, rbx                  ; rsi = y + rowcount
    ; Calculate starting buffer of the fish row buffer
    ; addr = [r13 + fishtype.add_off] + (rowcount * fish.COL_SZ)
    mov rax, fish.COL_SZ
    mul rbx                                ; rax = rowcount * fish.COL_SZ
    mov r8, qword [r13 + fishtype.add_off] ; r8 = base address
    add r8, rax
    ; Get color attribute
    mov rdx, qword [r13 + fishtype.c_attr_q]
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rcx, 0                ; 4. bg
    call tb_print

    inc rbx                   ; Current fish rowcount += 1
    cmp rbx, fish.ROW_SZ      
    jl .loop_fish_rows        

    inc r12                   ; Select next fish  
    cmp r12, fish.COUNT
    jl .loop_fishes
    ; Cleanup
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    leave
    ret

; Function: fill_ocean_surface -- Fills the ocean surface buffer with a 
; repeating pattern.
; Args:
;   None
fill_ocean_surface:
    push rbp
    mov rbp, rsp

    push rbx 

    mov rdi, ocean_info.surface_buff  ; Surface buffer.
    mov rsi, ocean.str_surf_pat       ; Source pattern.
    mov rcx, screen.MAX_WIDTH - 1     ; Num bytes to fill (leaving space for null terminator).
    xor rbx, rbx                      ; Index for the pattern.
.fill_loop:
    cmp rcx, 0
    jle .done
    mov al, [rsi + rbx]               ; Get a char from the pattern
    mov [rdi], al                     ; and copy it to the buffer.
    inc rdi                           
    inc rbx                           
    cmp rbx, ocean.SURF_PAT_LEN       ; Check if we need to wrap the pattern.
    jne .no_wrap
    xor rbx, rbx                      ; Wrap the pattern index back to 0.
.no_wrap:
    dec rcx
    jmp .fill_loop
.done:
    mov byte [rdi], 0                ; Null-terminate the buffer
    ;Clean up
    pop rbx
    leave
    ret

; Function: fill_fish_infos
; Args:
;   None
fill_fish_infos:
    push rbp
    mov rbp, rsp
    ; Fill first fish 
    lea rdi, [fish_infos]
    mov qword [rdi + fishtype.add_off], fish.left_buff
    mov qword [rdi + fishtype.c_attr_q], fish.COLOR1
    mov dword [rdi + fishtype.x_d], fish.START_X
    mov dword [rdi + fishtype.y_d], fish.START_Y1
    mov dword [rdi + fishtype.dir_d], -1
    ; Fill second fish
    add rdi, fishtype_size
    mov qword [rdi + fishtype.add_off], fish.right_buff
    mov qword [rdi + fishtype.c_attr_q], fish.COLOR2
    mov dword [rdi + fishtype.x_d], fish.START_X
    mov dword [rdi + fishtype.y_d], fish.START_Y1 + fish.ROW_SZ
    mov dword [rdi + fishtype.dir_d], 1
    ; Cleanup
    leave
    ret

; Function: fill_heli_blade_info
; Args:
;   None
fill_heli_blade_info:
    push rbp
    mov rbp, rsp

    mov rsi, heli_blade.frames 
    mov [heli_blade_info.curr_frame_addr_ptr], rsi
    mov dword [heli_blade_info.curr_frame_index_d], 0
    mov dword [heli_blade_info.dir_d], 1
    ; Cleanup
    leave
    ret

; Function: draw_helicopter
; Args: 
;   None
draw_helicopter:
    push rbp
    mov rbp, rsp

    push rbx
    sub rsp, 8      ; Align stack

    xor rbx, rbx    ; rbx = helicopter.buff rowcount
.loop_rows:
    ; Get y coordinate 
    mov rsi, helicopter.START_Y  ; rsi = y
    add rsi, rbx                 ; rsi = y + rowcount
    ; Calculate the starting address of the row buffer
    ; addr = [helicopter.buff + (rowcount * helicopter.COL_SZ) ]
    mov rax, helicopter.COL_SZ
    mul rbx                          ; rax = rowcount * helicopter.COL_SZ
    cmp rax, 0
    je .load_blade_frame
    lea r8, [helicopter.buff + rax]  ; r8 = row address
    mov rdx, helicopter.COLOR        ; 3. fg attr
    jmp .proceed
.load_blade_frame:
    mov r8, [heli_blade_info.curr_frame_addr_ptr]  ; r8 = row address
    mov rdx, heli_blade.COLOR                        ; 3. fg attr
.proceed:    
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate 
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rdi, helicopter.START_X  ; 1. x
    mov rcx, 0                   ; 4. bg attr
    call tb_print

    inc rbx                      ; rowcount += 1
    cmp rbx, helicopter.ROW_SZ   ; Check row limit
    jl .loop_rows                
    ; Cleanup
    add rsp, 8
    pop rbx
    leave
    ret

; Function: draw_clouds
; Args: 
;   None
draw_clouds:
    push rbp
    mov rbp, rsp

    push rbx
    sub rsp, 8      ; Align stack

    xor rbx, rbx    ; rbx = clouds.buff rowcount
.loop_rows:
    ; Get y coordinate 
    mov rsi, clouds.START_Y  ; rsi = y
    add rsi, rbx             ; rsi = y + rowcount
    ; Calculate the starting address of the row buffer
    ; addr = [clouds.buff + (rowcount * clouds.COL_SZ) ]
    mov rax, clouds.COL_SZ
    mul rbx                      ; rax = rowcount * clouds.COL_SZ
    lea r8, [clouds.buff + rax]  ; r8 = row address
    
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate 
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rdi, clouds.START_X  ; 1. x
    mov rdx, clouds.COLOR    ; 3. fg attr
    mov rcx, 0               ; 4. bg attr
    call tb_print

    inc rbx                  ; rowcount += 1
    cmp rbx, clouds.ROW_SZ   
    jl .loop_rows            
    ; Cleanup
    add rsp, 8
    pop rbx
    leave
    ret

; Function: draw_whale
; Args: 
;   None
draw_whale:
    push rbp
    mov rbp, rsp

    push rbx
    sub rsp, 8      ; Align stack

    xor rbx, rbx    ; rbx = whale(l/r) rowcount
.loop_rows:
    ; Get x coordinate
    mov rdi, [whale_info.x_d] 
    ; Get y coordinate or the whale row
    mov rsi, [whale_info.y_d]  ; rsi = y
    add rsi, rbx               ; rsi = y + rowcount
    ; Calculate the starting address of the whale (left/right) row buffer
    ; addr = [whale_info.add_ptr] + (rowcount * whale.COL_SZ)
    mov rax, whale.COL_SZ
    mul rbx                             ; rax = rowcount * whale.COL_SZ
    mov r8, qword [whale_info.add_ptr]  ; r8 = base address of whale(left/right)buff
    add r8, rax                         ; r8 = starting row address
    
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rdx, whale.COLOR  ; 3. fg attr
    mov rcx, 0            ; 4. bg attr
    call tb_print

    inc rbx                 ; rowcount += 1
    cmp rbx, whale.ROW_SZ   
    jl .loop_rows           

    ; Check if the whale has hit the boundary and draw "Ouch!"
    cmp dword [whale_info.x_d], whale.MAX_LEFT
    je .left_boundary_touched

    cmp dword [whale_info.x_d], whale.MAX_RIGHT
    je .right_boundary_touched
    jmp .done

.left_boundary_touched:
    mov edi, [whale_info.x_d] ; rdi = arg1: x coord
    call draw_ouch  
    jmp .done

.right_boundary_touched:
    mov edi, [whale_info.x_d]
    add edi, (whale.COL_SZ - whale.OUCH_LEN)
    call draw_ouch

.done:
    ;Cleanup
    add rsp, 8
    pop rbx
    leave
    ret

; Function: draw_ouch
; Args:
;   rdi: x coordinate
draw_ouch:
    push rbp
    mov rbp, rsp
    ; Prepare tb_print
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate (of starting row)
    ; 3. rdx, fg attr
    ; 4. rcx, bg attr
    ; 5. r8, string address
    mov rsi, [whale_info.y_d] ; 1. x coor
    add rsi, whale.ROW_SZ     ; 2. y + ROW_SZ
    mov rdx, whale.COLOR_OUCH ; 3. fg attr
    mov rcx, 0                ; 4. bg attr
    mov r8, whale.str_ouch    ; 5. string address
    call tb_print
    ; Cleanup
    leave
    ret

; Function: draw_footer_text - str_instr is a long text 
;           with 0xA (new lines) in between. Use tb_set_cell
;           and handle the text placement
; Args:
;   None
draw_footer_text:
    push rbp
    mov rbp, rsp

    push rbx
    push r12
    push r13
    sub rsp, 8                 ; Align stack

    xor rbx, rbx               ; buffer index
    mov r12, str_instr.START_X ; r12 = x
    mov r13, str_instr.START_Y ; r12 = y
.println:
    inc r12                    ; x = x + 1
    movzx eax, byte [str_instr + rbx]
    test rax, rax
    jz .done
    cmp al, 0xA
    je .new_line
    jmp .set_cell
.new_line: 
    mov r12, str_instr.START_X 
    inc r13         ; y = y + 1
    jmp .next_char  ; skip 0xA char
.set_cell:
    ; Prepare tb_set_cell
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, char
    ; 4. rcx, fg attr
    ; 5. r8,  bg attr
    mov rdi, r12             ; 1. x
    mov rsi, r13             ; 2. y
    mov rdx, rax             ; 3. char 
    mov rcx, str_instr.COLOR ; 4. fg
    mov r8, 0                ; 5. bg
    call tb_set_cell
.next_char:
    inc rbx
    jmp .println
.done:
    ; Cleanup
    add rsp, 8 
    pop r13
    pop r12   
    pop rbx
    leave
    ret

; Function: draw_frame_box 
; Args:
;   None
draw_frame_box:
    push rbp
    mov rbp, rsp

    push rbx
    ; Use tb_set_cell to draw the frame box
    ; The args of tb_set_cell are:
    ; 1. rdi, x coordinate
    ; 2. rsi, y coordinate
    ; 3. rdx, char
    ; 4. rcx, fg attr
    ; 5. r8,  bg attr
    ; These registers are caller saved, so we can't reuse them
    ; across tb_set_cell call. We will reset them each time.

    ; 1. Draw the frame box corners
    ; Top-left corner 
    mov rdi, screen.START_X     
    mov rsi, screen.START_Y     
    mov rdx, uchar.BOX_TOP_LEFT
    mov rcx, TB_RED
    mov r8, 0                   
    call tb_set_cell
    ; 1.a. Bottom-left corner
    mov rdi, screen.START_X     
    mov rsi, screen.START_Y + screen.MAX_HEIGHT  
    mov rdx, uchar.BOX_BOTTOM_LEFT
    mov rcx, TB_RED
    mov r8, 0                   
    call tb_set_cell
    ; 1.b. Top-right corner
    mov rdi, screen.START_X + screen.MAX_WIDTH
    mov rsi, screen.START_Y                  
    mov rdx, uchar.BOX_TOP_RIGHT                
    mov rcx, TB_RED
    mov r8, 0                   
    call tb_set_cell
    ; Bottom-right corner
    mov rdi, screen.START_X + screen.MAX_WIDTH
    mov rsi, screen.START_Y + screen.MAX_HEIGHT  
    mov rdx, uchar.BOX_BOTTOM_RIGHT                
    mov rcx, TB_RED
    mov r8, 0                   
    call tb_set_cell
    ; 2. Draw the frame box vertical borders
    xor rbx, rbx
.loop_vert_borders:
    ; 2.a. Left vertical border
    mov rdi, screen.START_X         ; x = x start pos     
    mov rsi, screen.START_Y + 1     ; y = y start pos
    add rsi, rbx                    ; y = y + rbx
    mov rdx, uchar.BOX_VERT
    mov rcx, TB_WHITE           
    mov r8, 0                   
    call tb_set_cell
    ; 2.b. Right vertical border
    mov rdi, screen.START_X + screen.MAX_WIDTH  ; x = x end pos    
    mov rsi, screen.START_Y + 1     ; y = start pos 
    add rsi, rbx                    ; y = y + rbx
    mov rdx, uchar.BOX_VERT
    mov rcx, TB_WHITE           
    mov r8, 0                   
    call tb_set_cell
    inc rbx                         ; rbx = rbx + 1
    cmp rbx, screen.MAX_HEIGHT - 1
    jl .loop_vert_borders
    ; 3. Draw the frame box horizontal borders
    xor rbx, rbx
.loop_horiz_borders:
    ; 3.a Top horizontal border
    mov rdi, screen.START_X + 1 ; x = start pos
    add rdi, rbx                ; x = x + rbx
    mov rsi, screen.START_Y     ; y = y start pos    
    mov rdx, uchar.BOX_HORIZ
    mov rcx, TB_WHITE           
    mov r8, 0                   
    call tb_set_cell
    ; 3.b Bottom horizontal border
    mov rdi, screen.START_X + 1 ; x = start pos
    add rdi, rbx                ; x = x + rbx
    mov rsi, screen.START_Y + screen.MAX_HEIGHT  ; y = y start pos
    mov rdx, uchar.BOX_HORIZ
    mov rcx, TB_WHITE           
    mov r8, 0                   
    call tb_set_cell

    ; 3.c Additional Bottom line before str_instr text 
    mov rdi, str_instr.START_X    ; x = start pos
    add rdi, rbx                   ; x = x + rbx
    mov rsi, str_instr.START_Y - 1 ; y = y start pos
    mov rdx, '~'
    mov rcx, TB_BLUE
    mov r8, 0                   
    call tb_set_cell

    inc rbx
    cmp rbx, screen.MAX_WIDTH - 1
    jl .loop_horiz_borders
    ; Clean up
    pop rbx
    leave
    ret

; Function: get_current_time_ms - get current time in milliseconds
; Args:
;   None
; Return:
;   rax: current time in milliseconds
get_current_time_ms:
    push rbp
    mov rbp, rsp

    ; syscall: clock_gettime(CLOCK_REALTIME, &timespec)
    mov rax, SYSCALL_CLOCK_GETTIME
    mov rdi, CLOCK_REALTIME
    mov rsi, timespec
    syscall
    ; ((timespec.tv_sec * 1000000000) + timespec.tv_nsec ) / 1000000    
    mov rax, [timespec.tv_sec]
    mov rcx, 1000000000
    mul rcx
    add rax, [timespec.tv_nsec]  ; rax is in nanoseconds 
    ; Convert nanoseconds to milliseconds
    mov rcx, 1000000
    div rcx
    ; Clean up
    leave
    ret

