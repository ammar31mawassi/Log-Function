;;; disc-log.asm
;;; Computer Architecture - Assignment 2
;;;
;;; Starter shell only.  The assignment logic is intentionally left as TODOs.
;;; Base this work on the lecturer's examples in current/.
section .data
fmt_long_double:
	db `%Lg\0`
fmt_usage:
	db `Usage:\n	<program> <base> <number> <epsilon>\n\0`
fmt_answer:
	db `log_{%.18Lg}(%.18Lg) = %.18Lg\n\0`
section .bss
a:	; Base
	rest 1
b:	; Number
	rest 1
e:	; Epsilon
	rest 1
base:
	rest 1
number:
	rest 1
answer:
	rest 1
section .text


extern printf, fprintf, stderr, sscanf, exit
global main

main:
	;;; Same code as code-0023
	push rbp		; save the caller's frame pointer
	mov rbp, rsp		; establish this function's stack frame
	sub rsp, 8*1
	and rsp, -16		; keep the stack aligned for C-library calls

	;;; TODO 1: Validate argc and parse a, b, and epsilon. DONE!! WOOOOO
	cmp rdi, 4
	jne .usage

	mov qword [rbp - 8*1], rsi ; argv
	mov rdi, qword [rsi + 8*1] ; argv[1] == a
	mov rsi, fmt_long_double   ; format for one (long double)
	mov rdx, a		   ; &a
	mov rax, 0		   ; no fp registers used
	call sscanf		   ; try to read one (long double)
	cmp rax, 1		   ; if failed, 
	jne .usage		   ; ...complain!

	mov rbx, qword [rbp - 8*1] ; argv
	mov rdi, qword [rbx + 8*2] ; argv[1] == b
	mov rsi, fmt_long_double   ; format for one (long double)
	mov rdx, b		   ; &b
	mov rax, 0		   ; no fp registers used
	call sscanf		   ; try to read one (long double)
	cmp rax, 1		   ; if failed, 
	jne .usage		   ; ...complain!

	mov rbx, qword [rbp - 8*1] ; argv
	mov rdi, qword [rbx + 8*3] ; argv[2] == epsilon
	mov rsi, fmt_long_double   ; format for one (long double)
	mov rdx, e		   ; &epsilon
	mov rax, 0		   ; no fp registers used
	call sscanf		   ; try to read one (long double)
	cmp rax, 1		   ; if failed,
	jne .usage		   ; ...complain!

	;;; TODO 2: Implement the required discrete-logarithm algorithm.
	fninit
	fld tword[a]
	fstp tword[base] ; base = a
	fld tword[b]
	fstp tword[number] ; number = b
	call .log_algo
	fstp tword [answer]
	;;; TODO 3: Print the result, or print usage to stderr on error.
	fld tword[answer]
	fld tword[b]
	fld tword[a]
	sub rsp, 16*3
	mov rdi, fmt_answer ; fmt for printing the answer
	fstp tword [rsp]	; [rsp] <-- a
	fstp tword [rsp + 16*1]	; [rsp] <-- b
	fstp tword [rsp + 16*2]	; [rsp] <-- answer
	mov rax, 0		; no fp registers in use
	call printf
	jmp .done

.log_algo: ;;; For this function base -> a, number -> b
	fld tword [number]
	fld tword [base]        ; ST0 = a, ST1 = b
	fucomip st1
	ja .a_greater	; a > b
	fstp st0             ; remove remaining b when branch is not taken
	fld tword [number]       ; ST0 = b
	fld tword [base]       ; ST0 = a, ST1 = b
	fdivp                ; ST0 = b/a
	fld tword [e]       ; ST0 = epsilon, ST1 = b/a
	fld1                 ; ST0 = 1, ST1 = epsilon, ST2 = b/a
	faddp                 ; ST0 = 1+epsilon, ST1 = b/a
	fucomip st1          ; compare 1+epsilon with b/a; pop ST0
	ja .close_enough     ; 1+epsilon > b/a
	fstp tword [number]		; next_number = (b/a)
	call .log_algo
	fld1                    ; ST0=1, ST1=recursive result
	faddp                   ; ST0=recursive result + 1
	ret

.a_greater: ;we need to flip them
	fstp st0
	fld tword [number]
	fld tword [base]	; ST0 = base, ST1 = number
	fstp tword [number] 	; number = old_base
	fstp tword[base]	; base = old_number
	call .log_algo	; log_b(a)
	fld1                    ; ST0=1, ST1=result
	fxch st1                ; ST0=result, ST1=1
	fdivp                   ; ST0=1/result
	ret

.close_enough:	; we finished
	fstp st0               ; discard b/a
	fld1                    ; return value = 1
	ret

.done:
	fninit			; reset the x87 subsystem
	mov rax, 0		; status: OK
	mov rsp, rbp		; restore the stack pointer
	pop rbp			; point fp to the previous frame
	ret

.usage:
	mov rdi, qword [stderr]	; errors go to FILE *stderr
	mov rsi, fmt_usage	; fmt for usage
	mov rax, 0		; no fp registers in use
	call fprintf
	mov rax, -1		; status: ERROR
	call exit

section .note.GNU-stack noalloc noexec
