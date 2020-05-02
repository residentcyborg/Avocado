; rax	top of data stack / syscall number
; rbx	temporary
; rcx	unused (destroyed upon syscall?)
; rdx	syscall

; rsi	syscall
; rdi	syscall
; rbp	data stack
; rsp	code stack

; r8	syscall
; r9	syscall
; r10	syscall
; r11	unused

; r12	code pointer
; r13	code word
; r14	unused
; r15	unused

%define	CELL	8
%define	PAGE	1000h
%define FLAG	8000000000000000h

%macro	DUP	0
	add	rbp,	CELL
	mov	[rbp],	rax
%endmacro

%macro	DROP	0
	mov	rax,	[rbp]
	lea	rbp,	[rbp-CELL]
%endmacro

%macro	NEXT	0
	add	r12,	CELL
	mov	r13,	[r12]
	jmp	r13
%endmacro

section	.text

global	_main

_main:
	mov	rbp,	stack
	xor	rax,	rax
	mov	r12,	start.x
	mov	r13,	[r12]
	jmp	r13

lit:
	DUP
	add	r12,	CELL
	mov	rax,	[r12]
	NEXT

enter:
	add	r12,	CELL
	push	r12
	mov	r12,	[r12]
	mov	r13,	[r12]
	jmp	r13

execute:
	push	r12
	mov	r12,	rax
	DROP
	mov	r13,	[r12]
	jmp	r13

exit:
	pop	r12
	NEXT

jump:
	add	r12,	CELL
	mov	r12,	[r12]
	mov	r13,	[r12]
	jmp	r13

branch0:
	test rax,	rax
	DROP
	jz jump
	add r12,	CELL
	NEXT

branch1:
	test rax,	rax
	DROP
	jnz jump
	add r12,	CELL
	NEXT

align	CELL

if:
	dq	1
	dq	`?`
	dq	0

.x:
	test	rax,	rax
	DROP
	jz	exit
	NEXT

align	CELL

dup:
	dq	3
	dq	`dup`
	dq	if

.x:
	DUP
	NEXT

align	CELL

drop:
	dq	4
	dq	`drop`
	dq	dup

.x:
	DROP
	NEXT

align	CELL

over:
	dq	4
	dq	`over`
	dq	drop

.x:
	lea	rbp,	[rbp+CELL]
	mov	[rbp],	rax
	mov	rax,	[rbp-CELL]
	NEXT

align	CELL

push:
	dq	4
	dq	`push`
	dq	over

.x:
	push	rax
	DROP
	NEXT

align	CELL

pull:
	dq	4
	dq	`pull`
	dq	push

.x:
	DUP
	pop	rax
	NEXT


align	CELL

shiftLeft:
	dq	9
	dq	`shiftLeft`
	dq	pull

.x:
	shl	rax,	1
	NEXT

align	CELL

shiftRight:
	dq	10
	dq	`shiftRight`
	dq	shiftLeft

.x:
	shr	rax,	1
	NEXT

align	CELL

rotateLeft:
	dq	10
	dq	`rotateLeft`
	dq	shiftRight

.x:
	rol	rax,	1
	NEXT

align	CELL

rotateRight:
	dq	11
	dq	`rotateRight`
	dq	rotateLeft

.x:
	ror	rax,	1
	NEXT

align	CELL

not:
	dq	1
	dq	`!`
	dq	rotateRight

.x:
	not	rax
	NEXT

align	CELL

and:
	dq	3
	dq	`and`
	dq	not

.x:
	and	[rbp],	rax
	DROP
	NEXT

align	CELL

or:
	dq	2
	dq	`or`
	dq	and

.x:
	or	[rbp],	rax
	DROP
	NEXT

align	CELL

xor:
	dq	1
	dq	`^`
	dq	or

.x:
	xor	[rbp],	rax
	DROP
	NEXT

align	CELL

add:
	dq	1
	dq	`+`
	dq	xor

.x:
	add	[rbp],	rax
	DROP
	NEXT

align	CELL

sub:
	dq	1
	dq	`-`
	dq	add

.x:
	sub	[rbp],	rax
	DROP
	NEXT

align	CELL

mul:
	dq	1
	dq	`*`
	dq	sub

.x:
	mov	rbx,	rax
	DROP
	mul	rbx
	DUP
	mov	rax,	rdx
	NEXT

align	CELL

div:
	dq	1
	dq	`/`
	dq	mul

.x:
	mov	rbx,	rax
	DROP
	mov	rdx,	rax
	DROP
	div	rbx
	DUP
	mov	rax,	rdx
	NEXT

align	CELL

fetch:
	dq	5
	dq	`fetch`
	dq	div

.x:
	mov	rax,	[rax]
	NEXT

align	CELL

store:
	dq	5
	dq	`store`
	dq	fetch

.x:
	mov	rbx,	[rbp]
	mov	[rbx],	rax
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

fetchByte:
	dq	9
	dq	`fetchByte`
	dq	store

.x:
	mov	al,	[rax]
	and	rax,	0xFF
	NEXT	

align	CELL

storeByte:
	dq	9
	dq	`storeByte`
	dq	fetchByte

.x:
	mov	rbx,	[rbp]
	mov	[rbx],	al
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

read:
	dq	4
	dq	`read`
	dq	store

.x:
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	0		; stdin
	mov	rax,	2000003h	; sys_read
	syscall
	NEXT

align	CELL

write:
	dq	5
	dq	`write`
	dq	read

.x:
	mov	rdx,	rax		; Count.
	mov	rsi,	[rbp]		; Address.
	mov	rdi,	1		; stdout
	mov	rax,	2000004h	; sys_write
	syscall
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

align	CELL

emit:
	dq	4
	dq	`emit`
	dq	write

.x:
	mov	rdx,	1		; Count.
	DUP
	mov	rsi,	rbp		; Address.
	mov	rdi,	1		; stdout
	mov	rax,	2000004h	; sys_write
	syscall
	mov	rax,	[rbp-CELL]
	lea	rbp,	[rbp-CELL*2]
	NEXT

section	.data

align	CELL

negate:
	dq	6
	dq	`negate`
	dq	emit

.x:
	dq	not.x
	dq	lit
	dq	1
	dq	add.x
	dq	exit

swap:
	dq	4
	dq	`swap`
	dq	negate

.x:
	dq	over.x
	dq	push.x
	dq	push.x
	dq	drop.x
	dq	pull.x
	dq	pull.x
	dq	exit

bool:
	dq	4
	dq	`bool`
	dq	swap

.x:
	dq	dup.x
	dq	if.x
	dq	dup.x
	dq	xor.x
	dq	not.x
	dq	exit

negative:
	dq	8
	dq	`negative`
	dq	bool

.x:
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	exit

addressLower:
	dq	12
	dq	`addressLower`
	dq	negative

.x:
	dq	lit
	dq	CELL-1
	dq	and.x
	dq	exit

addressUpper:
	dq	12
	dq	`addressUpper`
	dq	addressLower

.x:
	dq	lit
	dq	~(CELL-1)
	dq	and.x
	dq	exit

addressSplit:
	dq	12
	dq	`addressSplit`
	dq	addressUpper

.x:
	dq	dup.x
	dq	enter
	dq	addressLower.x
	dq	push.x
	dq	enter
	dq	addressUpper.x
	dq	pull.x
	dq	exit

string:
	dq	6
	dq	`string`
	dq	addressSplit

.x:
	dq	dup.x
	dq	push.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	pull.x
	dq	fetch.x
	dq	exit

less:
	dq	4
	dq	`less`
	dq	string

.x:
	dq	over.x
	dq	over.x
	dq	xor.x
	dq	enter
	dq	negative.x
	dq	branch0
	dq	.0

	dq	drop.x
	dq	enter
	dq	negative.x
	dq	exit

.0:
	dq	sub.x
	dq	enter
	dq	negative.x
	dq	exit

terminate:
	dq	9
	dq	`terminate`
	dq	less

.x:
	dq	lit
	dq	0
	dq	storeByte.x
	dq	exit

stringCompare:
	dq	13
	dq	`stringCompare`
	dq	terminate

.x:
	dq	push.x
	dq	enter
	dq	swap.x
	dq	pull.x
	dq	enter
	dq	.equalLength
	dq	push.x
	dq	drop.x
	dq	drop.x
	dq	pull.x
	dq	exit

.equalLength:
	dq	sub.x
	dq	dup.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	if.x
	dq	drop.x
	dq	enter
	dq	.loop
	dq	drop.x
	dq	fetchByte.x
	dq	pull.x
	dq	drop.x
	dq	exit

.loop:
	dq	over.x
	dq	over.x
	dq	dup.x
	dq	fetchByte.x
	dq	push.x
	dq	fetchByte.x
	dq	push.x
	dq	fetchByte.x
	dq	pull.x
	dq	xor.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	pull.x
	dq	and.x
	dq	if.x
	dq	lit
	dq	1
	dq	add.x
	dq	push.x
	dq	lit
	dq	1
	dq	add.x
	dq	pull.x
	dq	jump
	dq	.loop

start:
	dq	5
	dq	`start`
	dq	stringCompare

.x:
	dq	lit
	dq	prompt
	dq	enter
	dq	string.x
	dq	write.x

	dq	lit
	dq	inputPointer

	dq	lit
	dq	input
	dq	lit
	dq	PAGE

	dq	read.x

	dq	over.x
	dq	add.x
	dq	enter
	dq	terminate.x

	dq	store.x

	dq	lit
	dq	codePointer
	dq	lit
	dq	code
	dq	store.x

	dq	jump
	dq	token.x

compile:
	dq	7
	dq	`compile`
	dq	start

.x:
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

compileLiteral:
	dq	14
	dq	`compileLiteral`
	dq	compile

.x:
	dq	lit
	dq	lit
	dq	enter
	dq	compile.x
	dq	enter
	dq	compile.x
	dq	exit

skipWhitespace:
	dq	14
	dq	`skipWhitespace`
	dq	compileLiteral

.x:
	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	1
	dq	over.x
	dq	lit
	dq	`!`
	dq	enter
	dq	less.x
	dq	push.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	pull.x
	dq	and.x
	dq	if.x
	dq	lit
	dq	1
	dq	add.x
	dq	jump
	dq	skipWhitespace.x

extractToken:
	dq	12
	dq	`extractToken`
	dq	skipWhitespace

.x:
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

	dq	dup.x
	dq	fetchByte.x
	dq	lit
	dq	`!`
	dq	over.x
	dq	lit
	dq	7Fh
	dq	enter
	dq	less.x
	dq	push.x
	dq	enter
	dq	less.x
	dq	not.x
	dq	pull.x
	dq	and.x

	dq	if.x
	dq	jump
	dq	.x

; Extract next token from the input.

token:
	dq	5
	dq	`token`
	dq	extractToken

.x:
	dq	lit
	dq	inputPointer
	dq	fetch.x

	dq	enter
	dq	skipWhitespace.x
	
	dq	dup.x
	dq	fetchByte.x
	dq	branch1
	dq	.0

	dq	drop.x

	dq	lit
	dq	exit
	dq	enter
	dq	compile.x

	dq	enter
	dq	code

	dq	jump
	dq	start.x

.0:
	dq	push.x

	dq	lit
	dq	output
	dq	lit
	dq	output+CELL

	dq	pull.x

	dq	enter
	dq	extractToken.x

	dq	push.x

	dq	dup.x
	dq	enter
	dq	terminate.x

	dq	lit
	dq	output+CELL
	dq	sub.x
	dq	store.x

	dq	lit
	dq	inputPointer
	dq	pull.x
	dq	store.x

	dq	jump
	dq	literal.x

isDigit:
	dq	7
	dq	`isDigit`
	dq	token

.x:
	dq	lit
	dq	`0`
	dq	sub.x

	dq	lit
	dq	0

	dq	lit
	dq	base
	dq	fetch.x	

	dq	div.x
	dq	drop.x

	dq	exit

points2Sign:
	dq	11
	dq	`points2Sign`
	dq	isDigit

.x:
	dq	fetchByte.x
	dq	lit
	dq	`-`
	dq	sub.x
	dq	exit

isLiteral:
	dq	9
	dq	`isLiteral`
	dq	points2Sign

.x:
	dq	dup.x
	dq	enter
	dq	points2Sign.x
	dq	branch1
	dq	.loop

	dq	lit
	dq	1
	dq	add.x

	dq	dup.x
	dq	fetchByte.x
	dq	branch1
	dq	.loop

	dq	drop.x
	dq	lit
	dq	-1
	dq	exit

.loop:
	dq	dup.x
	dq	fetchByte.x
	dq	branch1
	dq	.0

	dq	drop.x
	dq	lit
	dq	0
	dq	exit

.0:
	dq	dup.x
	dq	fetchByte.x
	dq	enter
	dq	isDigit.x
	dq	branch0
	dq	.1

	dq	drop.x
	dq	lit
	dq	-1
	dq	exit

.1:
	dq	lit
	dq	1
	dq	add.x

	dq	jump
	dq	.loop

tokenError:
	dq	10
	dq	`tokenError`
	dq	isLiteral

.x:
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
	dq	exit

literal:
	dq	7
	dq	`literal`
	dq	tokenError

.x:
	dq	lit
	dq	output+CELL
	dq	enter
	dq	isLiteral.x
	dq	branch1
	dq	find.x

	dq	lit
	dq	output+CELL
	dq	dup.x

	dq	enter
	dq	points2Sign.x	
	dq	branch1
	dq	.unsigned

	dq	lit
	dq	1
	dq	add.x

	dq	enter
	dq	convertSigned.x

	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	branch0
	dq	.error

	dq	enter
	dq	compileLiteral.x

	dq	jump
	dq	token.x

.unsigned:
	dq	enter
	dq	convertUnsigned.x

	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	branch1
	dq	.error

	dq	enter	
	dq	compileLiteral.x

	dq	jump
	dq	token.x

.error:
	dq	drop.x
	dq	enter
	dq	tokenError.x
	dq	jump
	dq	start.x

convertSigned:
	dq	13
	dq	`convertSigned`
	dq	literal

.x:
	dq	lit
	dq	0

.loop:
	dq	over.x
	dq	fetchByte.x

	dq	dup.x
	dq	branch0
	dq	.exit

	dq	lit
	dq	`0`
	dq	sub.x

	dq	push.x
	dq	push.x

	dq	lit
	dq	1
	dq	add.x

	dq	pull.x
	dq	lit
	dq	base
	dq	fetch.x
	dq	mul.x

	dq	branch1
	dq	.exit3

	dq	pull.x
	dq	add.x

	dq	dup.x
	dq	lit
	dq	FLAG
	dq	enter
	dq	less.x
	dq	branch1
	dq	.exit2

	dq	jump
	dq	.loop

.exit3:
	dq	pull.x
	dq	drop.x
	dq	drop.x
	dq	drop.x
	dq	lit
	dq	0
	dq	exit

.exit:
	dq	drop.x
.exit2:
	dq	push.x
	dq	drop.x
	dq	pull.x
	dq	enter
	dq	negate.x
	dq	exit

convertUnsigned:
	dq	15
	dq	`convertUnsigned`
	dq	convertSigned

.x:
	dq	lit
	dq	0

.loop:
	dq	over.x
	dq	fetchByte.x

	dq	dup.x
	dq	branch0
	dq	.exit

	dq	lit
	dq	`0`
	dq	sub.x

	dq	push.x
	dq	push.x

	dq	lit
	dq	1
	dq	add.x

	dq	pull.x
	dq	lit
	dq	base
	dq	fetch.x
	dq	mul.x

	dq	branch1
	dq	.exit3

	dq	pull.x
	dq	add.x

	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	branch1
	dq	.exit2

	dq	jump
	dq	.loop

.exit3:
	dq	pull.x
	dq	drop.x
	dq	drop.x
	dq	drop.x
	dq	lit
	dq	FLAG
	dq	exit

.exit:
	dq	drop.x
.exit2:
	dq	push.x
	dq	drop.x
	dq	pull.x
	dq	exit

native:
	dq	6
	dq	`native`
	dq	convertUnsigned

.x:
	dq	lit
	dq	link
	dq	fetch.x
	dq	lit
	dq	negate
	dq	enter
	dq	less.x
	dq	not.x

	dq	if.x

	dq	lit
	dq	enter

	dq	enter
	dq	compile.x

	dq	exit

skipString:
	dq	10
	dq	`skipString`
	dq	native

.x:
	dq	enter
	dq	string.x

	dq	lit
	dq	~FLAG
	dq	and.x

	dq	enter
	dq	addressSplit.x

	dq	push.x
	dq	add.x
	dq	pull.x

	dq	if.x
	dq	lit
	dq	CELL
	dq	add.x
	dq	exit

immediate:
	dq	9
	dq	`immediate`
	dq	skipString

.x:
	dq	lit
	dq	link
	dq	fetch.x
	dq	fetch.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	if.x
	
	dq	lit
	dq	link
	dq	fetch.x

	dq	enter
	dq	skipString.x

	dq	lit
	dq	CELL
	dq	add.x

	dq	execute

	dq	exit

mediate:
	dq	7
	dq	`mediate`
	dq	immediate

.x:
	dq	lit
	dq	link
	dq	fetch.x
	dq	fetch.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	if.x

	dq	enter
	dq	native.x

	dq	lit
	dq	link
	dq	fetch.x

	dq	enter
	dq	skipString.x

	dq	lit
	dq	CELL
	dq	add.x

	dq	enter
	dq	compile.x

	dq	exit

find:
	dq	4
	dq	`find`
	dq	mediate

.x:
	dq	lit
	dq	link
	dq	lit
	dq	number
	dq	store.x

.find:
	dq	enter
	dq	.not_found
	dq	enter
	dq	.found
	dq	lit
	dq	link
	dq	lit
	dq	link
	dq	fetch.x
	dq	enter
	dq	skipString.x
	dq	fetch.x
	dq	store.x
	dq	jump
	dq	.find

.not_found:
	dq	lit
	dq	link
	dq	fetch.x
	dq	enter
	dq	bool.x
	dq	not.x
	dq	if.x
	dq	enter
	dq	tokenError.x
	dq	jump
	dq	start.x

.found:
	dq	lit
	dq	output
	dq	enter
	dq	string.x
	dq	lit
	dq	link
	dq	fetch.x
	dq	enter
	dq	string.x
	dq	lit
	dq	~FLAG
	dq	and.x
	dq	enter
	dq	stringCompare.x
	dq	enter
	dq	bool.x
	dq	not.x

	dq	if.x

	dq	enter
	dq	immediate.x

	dq	enter
	dq	mediate.x

.exit:
	dq	pull.x
	dq	drop.x
	dq	jump
	dq	token.x

binary:
	dq	6|FLAG
	dq	`binary`
	dq	find

.x:
	dq	lit
	dq	base
	dq	lit
	dq	2
	dq	store.x
	dq	exit

decimal:
	dq	7|FLAG
	dq	`decimal`
	dq	binary

.x:
	dq	lit
	dq	base
	dq	lit
	dq	10
	dq	store.x
	dq	exit

number:
	dq	1
	dq	`.`
	dq	decimal

.signed:
	dq	dup.x
	dq	lit
	dq	FLAG
	dq	and.x
	dq	branch1
	dq	.negative

.natural:
	dq	dup.x
	dq	lit
	dq	0
	dq	lit
	dq	base
	dq	fetch.x
	dq	div.x
	dq	push.x
	dq	dup.x
	dq	branch1
	dq	.recurse
	dq	drop.x

.print:
	dq	drop.x
	dq	pull.x
	dq	lit
	dq	`0`
	dq	add.x
	dq	emit.x
	dq	exit

.recurse:
	dq	enter
	dq	.natural
	dq	jump
	dq	.print

.negative:
	dq	enter
	dq	negate.x
	dq	lit
	dq	`-`
	dq	emit.x
	dq	jump
	dq	.natural

base:
	dq	10

error:
	dq	3
	dq	` ?\n`

prompt:
	dq	2
	dq	`# `

section	.bss

align	PAGE

stack:
	resb	PAGE

input:
	resb	PAGE

output:
	resb	PAGE

code:
	resb	PAGE

codePointer:
	resq	1

inputPointer:
	resq	1

link:
	resq	1

