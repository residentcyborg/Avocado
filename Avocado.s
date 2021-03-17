; rax	top of data stack / syscall number
; rbx	temporary
; rcx	unused / destroyed upon syscall
; rdx	syscall

; rsi	syscall
; rdi	syscall
; rbp	data stack
; rsp	code stack

; r8	syscall
; r9	syscall
; r10	syscall
; r11	unused / destroyed upon syscall

; r12	code pointer
; r13	unused
; r14	unused
; r15	unused

; Our stacks grow downward.

%include "platform.s"

%ifdef LINUX
	%define SYS_read 0
	%define SYS_write 1
%elif MACOS
	%define SYS_read 0x2000003
	%define SYS_write 0x2000004
%endif

%define CELL 8
%define PAGE 1000h
%define FLAG 8000000000000000h
%define LINK 0

%macro STRING 2
align CELL
%1:
	%strlen LENGTH %2
	dq LENGTH
	db %2, 0
align CELL
%endmacro

%macro DEFINE 2-3 0
	STRING %1, %2
	dq LINK+%3
	%define LINK %1
.x:
%endmacro

%macro DUP 0
	sub rbp, CELL
	mov [rbp], rax
%endmacro

%macro DROP 1
	mov rax, [rbp+CELL*(%1-1)]
	add rbp, CELL*%1
%endmacro

%macro NEXT 0
	add r12, CELL
	jmp [r12]
%endmacro

section .text

global start

start:
	mov rbp, stack
	xor rax, rax

	mov r12, main.x
	jmp [r12]

lit:
	DUP
	add r12, CELL
	mov rax, [r12]
	NEXT

enter:
	add r12, CELL
	push r12
	mov r12, [r12]
	jmp [r12]

exit:
	pop r12
	NEXT

jump:
	add r12, CELL
	mov r12, [r12]
	jmp [r12]

jump0:
	mov rbx, rax
	DROP 1
	test rbx, rbx
	jz jump
	add r12, CELL
	NEXT

DEFINE dup, "dup"
	DUP
	NEXT

DEFINE drop, "drop"
	DROP 1
	NEXT

DEFINE nip, "nip"		; A, B -- B
	add rbp, CELL
	NEXT

DEFINE over, "over"
	DUP
	mov rax, [rbp+CELL]
	NEXT

DEFINE push, "push"
	push rax
	DROP 1
	NEXT

DEFINE pull, "pull"
	DUP
	pop rax
	NEXT

DEFINE shiftLeft, "shiftLeft"
	shl rax, 1
	NEXT

DEFINE shiftRight, "shiftRight"
	shr rax, 1
	NEXT

DEFINE rotateLeft, "rotateLeft"
	rol rax, 1
	NEXT

DEFINE rotateRight, "rotateRight"
	ror rax, 1
	NEXT

DEFINE not, "!"
	not rax
	NEXT

DEFINE and, "and"
	and [rbp], rax
	DROP 1
	NEXT

DEFINE or, "or"
	or [rbp], rax
	DROP 1
	NEXT

DEFINE xor, "xor"
	xor [rbp], rax
	DROP 1
	NEXT

DEFINE add, "+"
	add [rbp], rax
	DROP 1
	NEXT

DEFINE sub, "-"
	sub [rbp], rax
	DROP 1
	NEXT

DEFINE mul, "*"
	mov rbx, rax
	DROP 1
	mul rbx
	DUP
	mov rax, rdx
	NEXT

DEFINE div, "/"
	mov rbx, rax
	DROP 1
	mov rdx, rax
	DROP 1
	div rbx
	DUP
	mov rax, rdx
	NEXT

DEFINE fetch, "fetch"
	mov rax, [rax]
	NEXT

DEFINE store, "store"
	mov rbx, [rbp]
	mov [rbx], rax
	DROP 2
	NEXT

DEFINE fetchByte, "fetchByte"
	mov al, [rax]
	and rax, 0xFF
	NEXT

DEFINE storeByte, "storeByte"
	mov rbx, [rbp]
	mov [rbx], al
	DROP 2
	NEXT

DEFINE read, "read"
	mov rdx, rax		; Count.
	mov rsi, [rbp]		; Address.
	mov rdi, 0		; stdin
	mov rax, SYS_read	; sys_read
	syscall
	NEXT

DEFINE write, "write"
	mov rdx, rax		; Count.
	mov rsi, [rbp]		; Address.
	mov rdi, 1		; stdout
	mov rax, SYS_write	; sys_write
	syscall
	DROP 2
	NEXT

section	.data

DEFINE	execute,	"execute"
	dq	push.x
	dq	exit

DEFINE	negate,	"negate"
	dq	not.x
	dq	lit
	dq	1
	dq	add.x
	dq	exit

DEFINE	bool,	"bool"
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	dup.x
	dq	xor.x
	dq	not.x

.then:
	dq	exit

DEFINE	isZero,	"isZero"
	dq	enter
	dq	bool.x
	dq	not.x
	dq	exit

DEFINE	negative,	"negative"
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	exit

DEFINE	less,	"less"
	dq	over.x
	dq	over.x
	dq	xor.x
	dq	enter
	dq	negative.x

.if:
	dq	jump0
	dq	.else

	dq	drop.x

	dq	jump
	dq	.then	
.else:

	dq	sub.x

.then:
	dq	enter
	dq	negative.x
	dq	exit

DEFINE	more,	"more"
	dq	lit
	dq	1
	dq	add.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	exit

DEFINE	lesser,	"lesser"
	dq	over.x
	dq	over.x
	dq	enter
	dq	less.x

.if:
	dq	jump0
	dq	.else

	dq	drop.x

	dq	jump
	dq	.then
.else:

	dq	nip.x

.then:
	dq	exit

DEFINE	string,	"string"
	dq	dup.x
	dq	push.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	pull.x
	dq	fetch.x
	dq	exit

DEFINE	stringAdvance,	"stringAdvance"
	dq	dup.x
	dq	push.x
	dq	over.x
	dq	push.x
	dq	nip.x
	dq	add.x
	dq	pull.x
	dq	pull.x
	dq	sub.x
	dq	dup.x
	dq	enter
	dq	negative.x

.if:
	dq	jump0
	dq	.then

	dq	add.x
	dq	lit
	dq	0

.then:
	dq	exit

DEFINE	interleave, "interleave"		; A, B, C, D -- A, C, B, D
	dq	push.x
	dq	over.x
	dq	push.x
	dq	nip.x
	dq	pull.x
	dq	pull.x
	dq	exit

DEFINE	stringCompare,	"stringCompare"		; string1Address, string1Size, string2Address, string2Size -- comparisonValue
	dq	enter
	dq	interleave.x
	dq	xor.x

.if:	; If string sizes are not equal
	dq	jump0
	dq	.then

	; Drop the string addresses and return error
	dq	drop.x
	dq	drop.x
	dq	lit
	dq	-1
	dq	exit

.then:
.begin:
	dq	over.x
	dq	over.x
	dq	fetchByte.x
	dq	push.x
	dq	fetchByte.x
	dq	pull.x

	dq	xor.x
	dq	enter
	dq	isZero.x

	dq	over.x
	dq	fetchByte.x
	dq	and.x

.while:
	dq	jump0
	dq	.do
	
	dq	lit
	dq	1
	dq	add.x
	dq	push.x

	dq	lit
	dq	1
	dq	add.x
	dq	pull.x

	dq	jump
	dq	.begin
.do:

	dq	drop.x
	dq	fetchByte.x
	dq	exit

DEFINE	memoryCopy,	"memoryCopy"	; addressDestination, addressSource, size -- addressDestination
	; Save destination address underneath to use later as the return value
	dq	push.x
	dq	push.x
	dq	dup.x
	dq	pull.x
	dq	pull.x

.begin:
	dq	dup.x

.while:
	dq	jump0
	dq	.do

	dq	push.x

	dq	over.x
	dq	over.x
	dq	fetchByte.x
	dq	storeByte.x

	dq	lit
	dq	1
	dq	add.x
	dq	push.x
	dq	lit
	dq	1
	dq	add.x
	dq	pull.x

	dq	pull.x
	dq	lit
	dq	1
	dq	sub.x

	dq	jump
	dq	.begin
.do:

	dq	drop.x
	dq	drop.x
	dq	drop.x
	dq	exit

DEFINE	stringTerminate,	"stringTerminate"	; stringPointer, stringSize -- stringPointer, stringSize
	; Save string descriptor for use as return values
	dq	over.x
	dq	over.x

	; Terminate the string
	dq	add.x
	dq	lit
	dq	0
	dq	storeByte.x
	dq	exit

DEFINE	stringCopy, 	"stringCopy"	; stringPointerDestination, stringSizeDestination, stringPointerSource, stringSizeSource -- stringPointerDestination, stringSizeDestination
	dq	enter
	dq	interleave.x
	dq	enter
	dq	lesser.x

	; Save lesser string size for later
	dq	dup.x
	dq	push.x

	dq	enter
	dq	memoryCopy.x

	dq	pull.x

	; Put destination string head
	dq	over.x
	dq	lit
	dq	CELL
	dq	sub.x
	dq	over.x
	dq	store.x

	dq	enter
	dq	stringTerminate.x
	dq	exit

DEFINE	compile,	"compile"
	dq	push.x
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	pull.x
	dq	store.x

	dq	lit
	dq	codePointer
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	store.x
	dq	exit

DEFINE	range,	"range"
	dq	push.x
	dq	over.x
	dq	push.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	pull.x
	dq	pull.x
	dq	enter
	dq	more.x
	dq	not.x
	dq	and.x
	dq	exit

DEFINE	skipWhitespace,	"skipWhitespace"
	dq	over.x
	dq	dup.x
	dq	push.x

.begin:
	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	1
	dq	lit
	dq	20h
	dq	enter
	dq	range.x

.while:
	dq	jump0
	dq	.do

	dq	lit
	dq	1
	dq	add.x

	dq	jump
	dq	.begin
.do:

	dq	pull.x
	dq	sub.x
	dq	enter
	dq	stringAdvance.x
	dq	exit

DEFINE	wordLength,	"wordLength"
	dq	dup.x

.begin:
	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	`!`
	dq	lit
	dq	`~`
	dq	enter
	dq	range.x

.while:
	dq	jump0
	dq	.do

	dq	lit
	dq	1
	dq	add.x
	
	dq	jump
	dq	.begin
.do:

	dq	over.x
	dq	sub.x
	dq	exit

DEFINE	isLiteralUnsigned,	"isLiteralUnsigned"
	dq	dup.x
	dq	fetchByte.x

.if:
	dq	jump0
	dq	.then

.begin:
	dq	dup.x
	dq	fetchByte.x
	
	dq	dup.x
	dq	lit
	dq	`0`
	dq	sub.x
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	lit
	dq	1
	dq	sub.x
	dq	enter
	dq	range.x
	dq	and.x

.while:
	dq	jump0
	dq	.do

	dq	lit
	dq	1
	dq	add.x

	dq	jump
	dq	.begin
.do:

	dq	fetchByte.x
	dq	enter
	dq	isZero.x
	dq	exit

.then:
	dq	drop.x
	dq	lit
	dq	0
	dq	exit

DEFINE	isLiteral,	"isLiteral"
	dq	lit
	dq	output+CELL

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	`-`
	dq	sub.x
	dq	enter
	dq	isZero.x

.if:
	dq	jump0
	dq	.then

	dq	lit
	dq	1
	dq	add.x

.then:
	dq	enter
	dq	isLiteralUnsigned.x
	dq	exit

DEFINE	literalUnsigned,	"literalUnsigned"
	dq	lit
	dq	0
	dq	dup.x
	dq	push.x

.begin:
	dq	over.x
	dq	fetchByte.x
	dq	pull.x
	dq	dup.x
	dq	push.x
	dq	enter
	dq	isZero.x
	dq	and.x

.while:
	dq	jump0
	dq	.do

	dq	lit
	dq	base
	dq	fetch.x
	dq	mul.x
	dq	pull.x
	dq	drop.x
	dq	push.x

	dq	over.x
	dq	fetchByte.x
	dq	lit
	dq	`0`
	dq	sub.x
	dq	add.x

	dq	push.x
	dq	lit
	dq	1
	dq	add.x
	dq	pull.x

	dq	jump
	dq	.begin
.do:

	dq	nip.x
	dq	pull.x
	dq	exit

DEFINE	literal,	"literal"
	dq	lit
	dq	output+CELL

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	`-`
	dq	sub.x

.if:
	dq	jump0
	dq	.else

	dq	enter
	dq	literalUnsigned.x

	dq	push.x
	dq	dup.x
	dq	enter
	dq	negative.x

	dq	jump
	dq	.then
.else:

	dq	lit
	dq	1
	dq	add.x

	dq	enter
	dq	literalUnsigned.x

	dq	push.x
	dq	enter
	dq	negate.x

	dq	lit		;
	dq	FLAG		;
	dq	or.x		;

	dq	dup.x
	dq	enter
	dq	negative.x
	dq	not.x

.then:
	dq	pull.x
	dq	or.x
	dq	exit

DEFINE	naturalRecurse,	"naturalRecurse"
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	div.x
	dq	push.x
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	naturalRecurse.x

.then:
	dq	lit
	dq	output+CELL
	dq	lit
	dq	output
	dq	fetch.x
	dq	add.x

	dq	pull.x
	dq	lit
	dq	`0`
	dq	add.x
	dq	storeByte.x

	dq	lit
	dq	output
	dq	dup.x
	dq	fetch.x
	dq	lit
	dq	1
	dq	add.x
	dq	store.x
	dq	exit

DEFINE	natural,	"natural"
	dq	lit
	dq	output
	dq	lit
	dq	0
	dq	store.x

	dq	enter
	dq	naturalRecurse.x

	dq	drop.x

	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	write.x
	dq	exit

DEFINE	number,	"."
	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	negate.x

	dq	lit
	dq	~FLAG
	dq	and.x

	dq	lit
	dq	output
	dq	lit
	dq	`-`
	dq	storeByte.x

	dq	lit
	dq	output
	dq	lit
	dq	1
	dq	write.x

.then:
	dq	jump
	dq	natural.x

DEFINE	binary,	"binary",	FLAG
	dq	lit
	dq	base
	dq	lit
	dq	2
	dq	store.x
	dq	exit

DEFINE	decimal,	"decimal",	FLAG
	dq	lit
	dq	base
	dq	lit
	dq	10
	dq	store.x
	dq	exit

DEFINE	if,	"if",	FLAG
	dq	lit
	dq	jump0
	dq	enter
	dq	compile.x
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	lit
	dq	0
	dq	enter
	dq	compile.x
	dq	exit

DEFINE	else,	"else",	FLAG
	dq	lit
	dq	jump
	dq	enter
	dq	compile.x
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	push.x
	dq	lit
	dq	0
	dq	enter
	dq	compile.x
	dq	enter
	dq	then.x
	dq	pull.x
	dq	exit

DEFINE	then,	"then",	FLAG
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	store.x
	dq	exit

DEFINE	begin,	"begin",	FLAG
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	exit

DEFINE	while,	"while",	FLAG
	dq	jump
	dq	if.x

DEFINE	do,	"do",	FLAG
	dq	lit
	dq	codePointer
	dq	fetch.x
	dq	lit
	dq	CELL*2
	dq	add.x
	dq	store.x

	dq	lit
	dq	jump
	dq	enter
	dq	compile.x
	dq	enter
	dq	compile.x
	dq	exit

DEFINE	stringSkip,	"stringSkip"
	dq	enter
	dq	string.x
	dq	lit
	dq	~(CELL-1)
	dq	and.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	add.x
	dq	exit

DEFINE	find,	"find"
.begin:
	dq	fetch.x
	dq	lit
	dq	~FLAG
	dq	and.x
	dq	dup.x
	dq	dup.x

.if:
	dq	jump0
	dq	.then

	dq	enter
	dq	string.x
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	enter
	dq	stringCompare.x

.then:
.while:
	dq	jump0
	dq	.do

	dq	enter
	dq	stringSkip.x

	dq	jump
	dq	.begin
.do:

	dq	exit

DEFINE	token,	"token"
.begin:
	dq	enter
	dq	skipWhitespace.x

	dq	over.x
	dq	fetchByte.x

.while:
	dq	jump0
	dq	.do

	dq	over.x
	dq	enter
	dq	wordLength.x
	dq	push.x
	dq	push.x

	dq	lit
	dq	output+CELL
	dq	lit
	dq	PAGE-CELL
	dq	pull.x
	dq	pull.x
	dq	enter
	dq	stringCopy.x

	dq	nip.x

	dq	enter
	dq	stringAdvance.x

	dq	push.x		; Push input string size
	dq	push.x		; Push input string pointer

	dq	enter
	dq	isLiteral.x

.if1:
	dq	jump0
	dq	.then1

	dq	enter
	dq	literal.x

.if2:
	dq	jump0
	dq	.then2

	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	write.x

	dq	lit
	dq	overflow
	dq	enter
	dq	string.x
	dq	write.x

	dq	pull.x		; Pull input string pointer
	dq	pull.x		; Pull input string size
	dq	drop.x		; Drop input string size
	dq	drop.x		; Drop input string pointer
	dq	drop.x		; Drop literal's erroneous conversion
	dq	exit

.then2:
	dq	lit
	dq	lit
	dq	enter
	dq	compile.x
	dq	enter
	dq	compile.x

	dq	pull.x
	dq	pull.x
	dq	jump
	dq	token.x

.then1:
	dq	lit
	dq	last

	dq	enter
	dq	find.x

	dq	dup.x

.if3:
	dq	jump0
	dq	.else3

	dq	enter
	dq	stringSkip.x
	dq	dup.x
	dq	fetch.x
	dq	lit
	dq	FLAG
	dq	and.x

.if4:
	dq	jump0
	dq	.else4

	dq	enter
	dq	execute.x

	dq	jump
	dq	.then4
.else4:

	dq	dup.x

	dq	lit
	dq	execute
	dq	enter
	dq	less.x
	dq	not.x

.if5:
	dq	jump0
	dq	.then5

	dq	lit
	dq	enter

	dq	enter
	dq	compile.x

.then5:
	dq	lit
	dq	CELL
	dq	add.x

	dq	enter
	dq	compile.x

.then4:
	dq	jump
	dq	.then3
.else3:
	dq	drop.x
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	write.x
	dq	lit
	dq	error
	dq	enter
	dq	string.x
	dq	write.x
	dq	pull.x
	dq	pull.x
	dq	drop.x
	dq	drop.x
	dq	exit

.then3:
	dq	pull.x		; Pull input string pointer
	dq	pull.x		; Pull input string size

	dq	jump
	dq	.begin
.do:

	dq	drop.x		; Drop input string size
	dq	drop.x		; Drop input string pointer

	dq	lit
	dq	exit
	dq	enter
	dq	compile.x

	dq	jump
	dq	code

DEFINE	main,	"main"
	dq	lit
	dq	prompt
	dq	enter
	dq	string.x
	dq	write.x

	dq	lit
	dq	input
	dq	lit
	dq	PAGE

	dq	read.x

	dq	enter
	dq	stringTerminate.x

	dq	lit
	dq	codePointer
	dq	lit
	dq	code
	dq	store.x

	dq	enter
	dq	token.x

	dq	jump
	dq	main.x

base:
	dq	10

last:
	dq	LINK

STRING error, ` ?\n`
STRING overflow, ` !\n`
STRING prompt, `# `

section .bss

align PAGE

	resb PAGE
stack:

input:
	resb PAGE

output:
	resb PAGE

code:
	resb PAGE

codePointer:
	resb CELL
