	.text
	.file	"break_div.c"
	.globl	scan                            # -- Begin function scan
	.p2align	4, 0x90
	.type	scan,@function
scan:                                   # @scan
	.cfi_startproc
# %bb.0:
	movl	%edx, %ecx
                                        # kill: def $esi killed $esi def $rsi
	cmpl	$2, %esi
	jge	.LBB0_2
# %bb.1:
	movl	%ecx, %eax
	retq
.LBB0_2:
	movl	%ecx, %r9d
	andl	$7, %r9d
	movl	%esi, %eax
	shrl	%eax
	decl	%eax
	decl	%esi
	cmpl	%esi, %eax
	cmovbl	%eax, %esi
	incl	%esi
	cmpl	$8, %esi
	jae	.LBB0_4
# %bb.3:
	xorl	%r10d, %r10d
	movl	%ecx, %r8d
	jmp	.LBB0_25
.LBB0_4:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r14
	.cfi_def_cfa_offset 24
	pushq	%rbx
	.cfi_def_cfa_offset 32
	.cfi_offset %rbx, -32
	.cfi_offset %r14, -24
	.cfi_offset %rbp, -16
	xorl	%eax, %eax
	testl	%r9d, %r9d
	sete	%al
	movl	%esi, %r10d
	andl	$-8, %r10d
	movd	%ecx, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm1                # xmm1 = xmm1[0,0,0,0]
	pcmpeqd	%xmm2, %xmm2
	pxor	%xmm1, %xmm2
	pslld	$31, %xmm2
	movmskps	%xmm2, %r8d
	movl	%r8d, %r11d
	andb	$2, %r11b
	shrb	%r11b
	movl	%r8d, %ebx
	andb	$4, %bl
	shrb	$2, %bl
	movl	%r8d, %ebp
	shrb	$3, %bpl
	pxor	%xmm2, %xmm2
	xorl	%r14d, %r14d
	jmp	.LBB0_6
	.p2align	4, 0x90
.LBB0_5:                                #   in Loop: Header=BB0_6 Depth=1
	movdqa	%xmm1, %xmm7
	pslld	$31, %xmm7
	psrad	$31, %xmm7
	movdqa	%xmm7, %xmm8
	pandn	%xmm5, %xmm8
	pxor	%xmm8, %xmm4
	paddd	%xmm4, %xmm0
	pandn	%xmm6, %xmm7
	pxor	%xmm7, %xmm3
	paddd	%xmm3, %xmm2
	addq	$8, %r14
	cmpq	%r14, %r10
	je	.LBB0_22
.LBB0_6:                                # =>This Inner Loop Header: Depth=1
	movdqu	(%rdi,%r14,4), %xmm4
	movdqu	16(%rdi,%r14,4), %xmm3
                                        # implicit-def: $xmm5
	testb	$1, %r8b
	je	.LBB0_7
# %bb.14:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm5
	testb	%r11b, %r11b
	jne	.LBB0_15
.LBB0_8:                                #   in Loop: Header=BB0_6 Depth=1
	testb	%bl, %bl
	je	.LBB0_9
.LBB0_16:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm6
	shufps	$48, %xmm5, %xmm6               # xmm6 = xmm6[0,0],xmm5[3,0]
	shufps	$132, %xmm6, %xmm5              # xmm5 = xmm5[0,1],xmm6[0,2]
	testb	%bpl, %bpl
	je	.LBB0_10
	jmp	.LBB0_17
	.p2align	4, 0x90
.LBB0_7:                                #   in Loop: Header=BB0_6 Depth=1
	testb	%r11b, %r11b
	je	.LBB0_8
.LBB0_15:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm6
	punpcklqdq	%xmm5, %xmm6            # xmm6 = xmm6[0],xmm5[0]
	shufps	$226, %xmm5, %xmm6              # xmm6 = xmm6[2,0],xmm5[2,3]
	movaps	%xmm6, %xmm5
	testb	%bl, %bl
	jne	.LBB0_16
.LBB0_9:                                #   in Loop: Header=BB0_6 Depth=1
	testb	%bpl, %bpl
	je	.LBB0_10
.LBB0_17:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm6
	shufps	$228, %xmm5, %xmm6              # xmm6 = xmm6[0,1],xmm5[2,3]
	shufps	$36, %xmm6, %xmm5               # xmm5 = xmm5[0,1],xmm6[2,0]
.LBB0_10:                               #   in Loop: Header=BB0_6 Depth=1
                                        # implicit-def: $xmm6
	testb	$1, %r8b
	je	.LBB0_11
# %bb.18:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm6
	testb	%r11b, %r11b
	jne	.LBB0_19
.LBB0_12:                               #   in Loop: Header=BB0_6 Depth=1
	testb	%bl, %bl
	je	.LBB0_13
.LBB0_20:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	shufps	$48, %xmm6, %xmm7               # xmm7 = xmm7[0,0],xmm6[3,0]
	shufps	$132, %xmm7, %xmm6              # xmm6 = xmm6[0,1],xmm7[0,2]
	testb	%bpl, %bpl
	je	.LBB0_5
	jmp	.LBB0_21
	.p2align	4, 0x90
.LBB0_11:                               #   in Loop: Header=BB0_6 Depth=1
	testb	%r11b, %r11b
	je	.LBB0_12
.LBB0_19:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	punpcklqdq	%xmm6, %xmm7            # xmm7 = xmm7[0],xmm6[0]
	shufps	$226, %xmm6, %xmm7              # xmm7 = xmm7[2,0],xmm6[2,3]
	movaps	%xmm7, %xmm6
	testb	%bl, %bl
	jne	.LBB0_20
.LBB0_13:                               #   in Loop: Header=BB0_6 Depth=1
	testb	%bpl, %bpl
	je	.LBB0_5
.LBB0_21:                               #   in Loop: Header=BB0_6 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	shufps	$228, %xmm6, %xmm7              # xmm7 = xmm7[0,1],xmm6[2,3]
	shufps	$36, %xmm7, %xmm6               # xmm6 = xmm6[0,1],xmm7[2,0]
	jmp	.LBB0_5
.LBB0_22:
	paddd	%xmm0, %xmm2
	pshufd	$238, %xmm2, %xmm0              # xmm0 = xmm2[2,3,2,3]
	paddd	%xmm2, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r8d
	cmpq	%rsi, %r10
	popq	%rbx
	.cfi_def_cfa_offset 24
	popq	%r14
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	.cfi_restore %rbx
	.cfi_restore %r14
	.cfi_restore %rbp
	jne	.LBB0_25
.LBB0_23:
	movl	%r8d, %eax
	retq
	.p2align	4, 0x90
.LBB0_24:                               #   in Loop: Header=BB0_25 Depth=1
	addl	%r11d, %r8d
	incq	%r10
	cmpq	%r10, %rsi
	je	.LBB0_23
.LBB0_25:                               # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%r10,4), %r11d
	testl	%r9d, %r9d
	je	.LBB0_24
# %bb.26:                               #   in Loop: Header=BB0_25 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r9d
	xorl	%eax, %r11d
	jmp	.LBB0_24
.Lfunc_end0:
	.size	scan, .Lfunc_end0-scan
	.cfi_endproc
                                        # -- End function
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function main
.LCPI1_0:
	.long	0                               # 0x0
	.long	1                               # 0x1
	.long	2                               # 0x2
	.long	3                               # 0x3
.LCPI1_1:
	.long	2654435761                      # 0x9e3779b1
	.long	2654435761                      # 0x9e3779b1
	.long	2654435761                      # 0x9e3779b1
	.long	2654435761                      # 0x9e3779b1
.LCPI1_2:
	.long	2027808452                      # 0x78dde6c4
	.long	2027808452                      # 0x78dde6c4
	.long	2027808452                      # 0x78dde6c4
	.long	2027808452                      # 0x78dde6c4
.LCPI1_3:
	.long	8                               # 0x8
	.long	8                               # 0x8
	.long	8                               # 0x8
	.long	8                               # 0x8
	.text
	.globl	main
	.p2align	4, 0x90
	.type	main,@function
main:                                   # @main
	.cfi_startproc
# %bb.0:
	pushq	%rbp
	.cfi_def_cfa_offset 16
	pushq	%r15
	.cfi_def_cfa_offset 24
	pushq	%r14
	.cfi_def_cfa_offset 32
	pushq	%r13
	.cfi_def_cfa_offset 40
	pushq	%r12
	.cfi_def_cfa_offset 48
	pushq	%rbx
	.cfi_def_cfa_offset 56
	pushq	%rax
	.cfi_def_cfa_offset 64
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movl	$2048, %ebx                     # imm = 0x800
	movl	$65536, %r14d                   # imm = 0x10000
	movl	$4096, %r13d                    # imm = 0x1000
	cmpl	$2, %edi
	jl	.LBB1_4
# %bb.1:
	movq	%rsi, %r12
	movl	%edi, %ebp
	movq	8(%rsi), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtol@PLT
	movq	%rax, %r14
	cmpl	$2, %ebp
	je	.LBB1_4
# %bb.2:
	movq	16(%r12), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %r13
	cmpl	$4, %ebp
	jb	.LBB1_4
# %bb.3:
	movq	24(%r12), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %rbx
.LBB1_4:
	movl	$2, %eax
	cmpl	$1048576, %r14d                 # imm = 0x100000
	ja	.LBB1_45
# %bb.5:
	testq	%r13, %r13
	je	.LBB1_45
# %bb.6:
	cmpq	$1000000, %r13                  # imm = 0xF4240
	ja	.LBB1_45
# %bb.7:
	movl	%r14d, %r15d
	leaq	4(,%r15,4), %rdi
	callq	malloc@PLT
	testq	%rax, %rax
	je	.LBB1_11
# %bb.8:
	movq	%rax, %r12
	testl	%r14d, %r14d
	je	.LBB1_17
# %bb.9:
	cmpl	$8, %r14d
	jae	.LBB1_12
# %bb.10:
	xorl	%eax, %eax
	jmp	.LBB1_15
.LBB1_11:
	movl	$1, %eax
	jmp	.LBB1_45
.LBB1_12:
	movl	%r15d, %eax
	andl	$2147483640, %eax               # imm = 0x7FFFFFF8
	movd	%ebx, %xmm0
	pshufd	$0, %xmm0, %xmm0                # xmm0 = xmm0[0,0,0,0]
	movl	%r15d, %ecx
	shrl	$3, %ecx
	andl	$268435455, %ecx                # imm = 0xFFFFFFF
	shlq	$5, %rcx
	movdqa	.LCPI1_0(%rip), %xmm1           # xmm1 = [0,1,2,3]
	xorl	%edx, %edx
	movdqa	.LCPI1_1(%rip), %xmm2           # xmm2 = [2654435761,2654435761,2654435761,2654435761]
	movdqa	.LCPI1_2(%rip), %xmm3           # xmm3 = [2027808452,2027808452,2027808452,2027808452]
	movdqa	.LCPI1_3(%rip), %xmm4           # xmm4 = [8,8,8,8]
	.p2align	4, 0x90
.LBB1_13:                               # =>This Inner Loop Header: Depth=1
	movdqa	%xmm1, %xmm5
	pmuludq	%xmm2, %xmm5
	pshufd	$232, %xmm5, %xmm5              # xmm5 = xmm5[0,2,2,3]
	pshufd	$245, %xmm1, %xmm6              # xmm6 = xmm1[1,1,3,3]
	pmuludq	%xmm2, %xmm6
	pshufd	$232, %xmm6, %xmm6              # xmm6 = xmm6[0,2,2,3]
	punpckldq	%xmm6, %xmm5            # xmm5 = xmm5[0],xmm6[0],xmm5[1],xmm6[1]
	paddd	%xmm0, %xmm5
	movdqu	%xmm5, (%r12,%rdx)
	paddd	%xmm3, %xmm5
	movdqu	%xmm5, 16(%r12,%rdx)
	paddd	%xmm4, %xmm1
	addq	$32, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB1_13
# %bb.14:
	cmpq	%r15, %rax
	je	.LBB1_17
.LBB1_15:
	imull	$1640531535, %eax, %edx         # imm = 0x61C8864F
	movl	%ebx, %ecx
	subl	%edx, %ecx
	.p2align	4, 0x90
.LBB1_16:                               # =>This Inner Loop Header: Depth=1
	movl	%ecx, (%r12,%rax,4)
	incq	%rax
	addl	$-1640531535, %ecx              # imm = 0x9E3779B1
	cmpq	%rax, %r15
	jne	.LBB1_16
.LBB1_17:
	movl	%r14d, %ecx
	shrl	%ecx
	decl	%ecx
	leal	-1(%r14), %eax
	cmpl	%eax, %ecx
	cmovael	%eax, %ecx
	incl	%ecx
	movl	%ecx, %edi
	andl	$-8, %edi
	xorl	%r8d, %r8d
	pcmpeqd	%xmm0, %xmm0
	xorl	%esi, %esi
	movq	%r13, (%rsp)                    # 8-byte Spill
	jmp	.LBB1_19
	.p2align	4, 0x90
.LBB1_18:                               #   in Loop: Header=BB1_19 Depth=1
	addl	%r10d, %esi
	imull	$1664525, %ebx, %ebx            # imm = 0x19660D
	addl	$1013904223, %ebx               # imm = 0x3C6EF35F
	movl	%ebx, (%r12)
	incq	%r8
	cmpq	%r13, %r8
	je	.LBB1_44
.LBB1_19:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_24 Depth 2
                                        #     Child Loop BB1_42 Depth 2
	movl	%ebx, %r10d
	cmpl	$2, %r14d
	jl	.LBB1_18
# %bb.20:                               #   in Loop: Header=BB1_19 Depth=1
	movl	%ebx, %r9d
	andl	$7, %r9d
	cmpl	$8, %ecx
	jae	.LBB1_22
# %bb.21:                               #   in Loop: Header=BB1_19 Depth=1
	xorl	%r11d, %r11d
	movl	%ebx, %r10d
	jmp	.LBB1_42
	.p2align	4, 0x90
.LBB1_22:                               #   in Loop: Header=BB1_19 Depth=1
	xorl	%eax, %eax
	testl	%r9d, %r9d
	sete	%al
	movd	%ebx, %xmm1
	movd	%eax, %xmm2
	pshufd	$0, %xmm2, %xmm2                # xmm2 = xmm2[0,0,0,0]
	movdqa	%xmm2, %xmm3
	pxor	%xmm0, %xmm3
	pslld	$31, %xmm3
	movmskps	%xmm3, %r10d
	movl	%r10d, %r11d
	andb	$2, %r11b
	shrb	%r11b
	movl	%r10d, %ebp
	andb	$4, %bpl
	shrb	$2, %bpl
	movl	%r10d, %r13d
	shrb	$3, %r13b
	pxor	%xmm3, %xmm3
	xorl	%r15d, %r15d
	jmp	.LBB1_24
	.p2align	4, 0x90
.LBB1_23:                               #   in Loop: Header=BB1_24 Depth=2
	movdqa	%xmm2, %xmm8
	pslld	$31, %xmm8
	psrad	$31, %xmm8
	movdqa	%xmm8, %xmm9
	pandn	%xmm6, %xmm9
	pxor	%xmm9, %xmm5
	paddd	%xmm5, %xmm1
	pandn	%xmm7, %xmm8
	pxor	%xmm8, %xmm4
	paddd	%xmm4, %xmm3
	addq	$8, %r15
	cmpq	%r15, %rdi
	je	.LBB1_40
.LBB1_24:                               #   Parent Loop BB1_19 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movdqu	(%r12,%r15,4), %xmm5
	movdqu	16(%r12,%r15,4), %xmm4
                                        # implicit-def: $xmm6
	testb	$1, %r10b
	je	.LBB1_25
# %bb.32:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm6
	testb	%r11b, %r11b
	jne	.LBB1_33
.LBB1_26:                               #   in Loop: Header=BB1_24 Depth=2
	testb	%bpl, %bpl
	je	.LBB1_27
.LBB1_34:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	shufps	$48, %xmm6, %xmm7               # xmm7 = xmm7[0,0],xmm6[3,0]
	shufps	$132, %xmm7, %xmm6              # xmm6 = xmm6[0,1],xmm7[0,2]
	testb	%r13b, %r13b
	je	.LBB1_28
	jmp	.LBB1_35
	.p2align	4, 0x90
.LBB1_25:                               #   in Loop: Header=BB1_24 Depth=2
	testb	%r11b, %r11b
	je	.LBB1_26
.LBB1_33:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	punpcklqdq	%xmm6, %xmm7            # xmm7 = xmm7[0],xmm6[0]
	shufps	$226, %xmm6, %xmm7              # xmm7 = xmm7[2,0],xmm6[2,3]
	movaps	%xmm7, %xmm6
	testb	%bpl, %bpl
	jne	.LBB1_34
.LBB1_27:                               #   in Loop: Header=BB1_24 Depth=2
	testb	%r13b, %r13b
	je	.LBB1_28
.LBB1_35:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	shufps	$228, %xmm6, %xmm7              # xmm7 = xmm7[0,1],xmm6[2,3]
	shufps	$36, %xmm7, %xmm6               # xmm6 = xmm6[0,1],xmm7[2,0]
.LBB1_28:                               #   in Loop: Header=BB1_24 Depth=2
                                        # implicit-def: $xmm7
	testb	$1, %r10b
	je	.LBB1_29
# %bb.36:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm7
	testb	%r11b, %r11b
	jne	.LBB1_37
.LBB1_30:                               #   in Loop: Header=BB1_24 Depth=2
	testb	%bpl, %bpl
	je	.LBB1_31
.LBB1_38:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm8
	shufps	$48, %xmm7, %xmm8               # xmm8 = xmm8[0,0],xmm7[3,0]
	shufps	$132, %xmm8, %xmm7              # xmm7 = xmm7[0,1],xmm8[0,2]
	testb	%r13b, %r13b
	je	.LBB1_23
	jmp	.LBB1_39
	.p2align	4, 0x90
.LBB1_29:                               #   in Loop: Header=BB1_24 Depth=2
	testb	%r11b, %r11b
	je	.LBB1_30
.LBB1_37:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm8
	punpcklqdq	%xmm7, %xmm8            # xmm8 = xmm8[0],xmm7[0]
	shufps	$226, %xmm7, %xmm8              # xmm8 = xmm8[2,0],xmm7[2,3]
	movaps	%xmm8, %xmm7
	testb	%bpl, %bpl
	jne	.LBB1_38
.LBB1_31:                               #   in Loop: Header=BB1_24 Depth=2
	testb	%r13b, %r13b
	je	.LBB1_23
.LBB1_39:                               #   in Loop: Header=BB1_24 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	movd	%eax, %xmm8
	shufps	$228, %xmm7, %xmm8              # xmm8 = xmm8[0,1],xmm7[2,3]
	shufps	$36, %xmm8, %xmm7               # xmm7 = xmm7[0,1],xmm8[2,0]
	jmp	.LBB1_23
	.p2align	4, 0x90
.LBB1_40:                               #   in Loop: Header=BB1_19 Depth=1
	paddd	%xmm1, %xmm3
	pshufd	$238, %xmm3, %xmm1              # xmm1 = xmm3[2,3,2,3]
	paddd	%xmm3, %xmm1
	pshufd	$85, %xmm1, %xmm2               # xmm2 = xmm1[1,1,1,1]
	paddd	%xmm1, %xmm2
	movd	%xmm2, %r10d
	movq	%rdi, %r11
	cmpq	%rcx, %rdi
	movq	(%rsp), %r13                    # 8-byte Reload
	jne	.LBB1_42
	jmp	.LBB1_18
	.p2align	4, 0x90
.LBB1_41:                               #   in Loop: Header=BB1_42 Depth=2
	addl	%ebp, %r10d
	incq	%r11
	cmpq	%r11, %rcx
	je	.LBB1_18
.LBB1_42:                               #   Parent Loop BB1_19 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	(%r12,%r11,4), %ebp
	testl	%r9d, %r9d
	je	.LBB1_41
# %bb.43:                               #   in Loop: Header=BB1_42 Depth=2
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r9d
	xorl	%eax, %ebp
	jmp	.LBB1_41
.LBB1_44:
	leaq	.L.str(%rip), %rdi
	xorl	%eax, %eax
	callq	printf@PLT
	movq	%r12, %rdi
	callq	free@PLT
	xorl	%eax, %eax
.LBB1_45:
	addq	$8, %rsp
	.cfi_def_cfa_offset 56
	popq	%rbx
	.cfi_def_cfa_offset 48
	popq	%r12
	.cfi_def_cfa_offset 40
	popq	%r13
	.cfi_def_cfa_offset 32
	popq	%r14
	.cfi_def_cfa_offset 24
	popq	%r15
	.cfi_def_cfa_offset 16
	popq	%rbp
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	main, .Lfunc_end1-main
	.cfi_endproc
                                        # -- End function
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"%u\n"
	.size	.L.str, 4

	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
