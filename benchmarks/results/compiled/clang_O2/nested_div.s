	.text
	.file	"nested_div.c"
	.globl	scan                            # -- Begin function scan
	.p2align	4, 0x90
	.type	scan,@function
scan:                                   # @scan
	.cfi_startproc
# %bb.0:
	movl	%edx, %ecx
	testl	%esi, %esi
	jle	.LBB0_26
# %bb.1:
	xorl	%r10d, %r10d
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%esi
	movl	%esi, %r8d
	cmpl	$8, %esi
	jae	.LBB0_3
# %bb.2:
	movl	%ecx, %r9d
	jmp	.LBB0_6
.LBB0_3:
	movl	%r8d, %r10d
	andl	$2147483640, %r10d              # imm = 0x7FFFFFF8
	movd	%ecx, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm1                # xmm1 = xmm1[0,0,0,0]
	movl	%r8d, %edx
	shrl	$3, %edx
	andl	$268435455, %edx                # imm = 0xFFFFFFF
	shlq	$5, %rdx
	pxor	%xmm2, %xmm2
	xorl	%r9d, %r9d
	.p2align	4, 0x90
.LBB0_4:                                # =>This Inner Loop Header: Depth=1
	movdqu	(%rdi,%r9), %xmm3
	movdqu	16(%rdi,%r9), %xmm4
	pxor	%xmm1, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm1, %xmm4
	paddd	%xmm4, %xmm2
	addq	$32, %r9
	cmpq	%r9, %rdx
	jne	.LBB0_4
# %bb.5:
	paddd	%xmm0, %xmm2
	pshufd	$238, %xmm2, %xmm0              # xmm0 = xmm2[2,3,2,3]
	paddd	%xmm2, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r9d
	cmpq	%r8, %r10
	je	.LBB0_7
	.p2align	4, 0x90
.LBB0_6:                                # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%r10,4), %edx
	xorl	%eax, %edx
	addl	%edx, %r9d
	incq	%r10
	cmpq	%r10, %r8
	jne	.LBB0_6
.LBB0_7:
	testl	%esi, %esi
	jle	.LBB0_27
# %bb.8:
	leal	1(%rcx), %eax
	xorl	%r10d, %r10d
	xorl	%edx, %edx
	divl	%esi
	cmpl	$8, %esi
	jb	.LBB0_12
# %bb.9:
	movl	%r8d, %r10d
	andl	$2147483640, %r10d              # imm = 0x7FFFFFF8
	movd	%r9d, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm1                # xmm1 = xmm1[0,0,0,0]
	movl	%r8d, %edx
	shrl	$3, %edx
	andl	$268435455, %edx                # imm = 0xFFFFFFF
	shlq	$5, %rdx
	pxor	%xmm2, %xmm2
	xorl	%r9d, %r9d
	.p2align	4, 0x90
.LBB0_10:                               # =>This Inner Loop Header: Depth=1
	movdqu	(%rdi,%r9), %xmm3
	movdqu	16(%rdi,%r9), %xmm4
	pxor	%xmm1, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm1, %xmm4
	paddd	%xmm4, %xmm2
	addq	$32, %r9
	cmpq	%r9, %rdx
	jne	.LBB0_10
# %bb.11:
	paddd	%xmm0, %xmm2
	pshufd	$238, %xmm2, %xmm0              # xmm0 = xmm2[2,3,2,3]
	paddd	%xmm2, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r9d
	cmpq	%r8, %r10
	je	.LBB0_13
	.p2align	4, 0x90
.LBB0_12:                               # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%r10,4), %edx
	xorl	%eax, %edx
	addl	%edx, %r9d
	incq	%r10
	cmpq	%r10, %r8
	jne	.LBB0_12
.LBB0_13:
	testl	%esi, %esi
	jle	.LBB0_27
# %bb.14:
	leal	2(%rcx), %eax
	xorl	%r10d, %r10d
	xorl	%edx, %edx
	divl	%esi
	cmpl	$8, %esi
	jb	.LBB0_18
# %bb.15:
	movl	%r8d, %r10d
	andl	$2147483640, %r10d              # imm = 0x7FFFFFF8
	movd	%r9d, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm1                # xmm1 = xmm1[0,0,0,0]
	movl	%r8d, %edx
	shrl	$3, %edx
	andl	$268435455, %edx                # imm = 0xFFFFFFF
	shlq	$5, %rdx
	pxor	%xmm2, %xmm2
	xorl	%r9d, %r9d
	.p2align	4, 0x90
.LBB0_16:                               # =>This Inner Loop Header: Depth=1
	movdqu	(%rdi,%r9), %xmm3
	movdqu	16(%rdi,%r9), %xmm4
	pxor	%xmm1, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm1, %xmm4
	paddd	%xmm4, %xmm2
	addq	$32, %r9
	cmpq	%r9, %rdx
	jne	.LBB0_16
# %bb.17:
	paddd	%xmm0, %xmm2
	pshufd	$238, %xmm2, %xmm0              # xmm0 = xmm2[2,3,2,3]
	paddd	%xmm2, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r9d
	cmpq	%r8, %r10
	je	.LBB0_19
	.p2align	4, 0x90
.LBB0_18:                               # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%r10,4), %edx
	xorl	%eax, %edx
	addl	%edx, %r9d
	incq	%r10
	cmpq	%r10, %r8
	jne	.LBB0_18
.LBB0_19:
	testl	%esi, %esi
	jle	.LBB0_27
# %bb.20:
	addl	$3, %ecx
	xorl	%r10d, %r10d
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%esi
	cmpl	$8, %esi
	jb	.LBB0_24
# %bb.21:
	movl	%r8d, %r10d
	andl	$2147483640, %r10d              # imm = 0x7FFFFFF8
	movd	%r9d, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm1                # xmm1 = xmm1[0,0,0,0]
	movl	%r8d, %ecx
	shrl	$3, %ecx
	andl	$268435455, %ecx                # imm = 0xFFFFFFF
	shlq	$5, %rcx
	pxor	%xmm2, %xmm2
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB0_22:                               # =>This Inner Loop Header: Depth=1
	movdqu	(%rdi,%rdx), %xmm3
	movdqu	16(%rdi,%rdx), %xmm4
	pxor	%xmm1, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm1, %xmm4
	paddd	%xmm4, %xmm2
	addq	$32, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB0_22
# %bb.23:
	paddd	%xmm0, %xmm2
	pshufd	$238, %xmm2, %xmm0              # xmm0 = xmm2[2,3,2,3]
	paddd	%xmm2, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r9d
	movl	%r9d, %ecx
	cmpq	%r8, %r10
	je	.LBB0_26
.LBB0_24:
	movl	%r9d, %ecx
	.p2align	4, 0x90
.LBB0_25:                               # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%r10,4), %edx
	xorl	%eax, %edx
	addl	%edx, %ecx
	incq	%r10
	cmpq	%r10, %r8
	jne	.LBB0_25
.LBB0_26:
	movl	%ecx, %eax
	retq
.LBB0_27:
	movl	%r9d, %ecx
	movl	%ecx, %eax
	retq
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
	movl	$1024, %r15d                    # imm = 0x400
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
	movq	%rax, %r15
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
	testq	%r15, %r15
	je	.LBB1_45
# %bb.6:
	cmpq	$1000000, %r15                  # imm = 0xF4240
	ja	.LBB1_45
# %bb.7:
	movl	%r14d, %r13d
	leaq	4(,%r13,4), %rdi
	callq	malloc@PLT
	testq	%rax, %rax
	je	.LBB1_8
# %bb.9:
	movq	%rax, %r12
	testl	%r14d, %r14d
	je	.LBB1_17
# %bb.10:
	cmpl	$8, %r14d
	jae	.LBB1_12
# %bb.11:
	xorl	%eax, %eax
	jmp	.LBB1_15
.LBB1_8:
	movl	$1, %eax
	jmp	.LBB1_45
.LBB1_12:
	movl	%r13d, %eax
	andl	$2147483640, %eax               # imm = 0x7FFFFFF8
	movd	%ebx, %xmm0
	pshufd	$0, %xmm0, %xmm0                # xmm0 = xmm0[0,0,0,0]
	movl	%r13d, %ecx
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
	cmpq	%r13, %rax
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
	cmpq	%rax, %r13
	jne	.LBB1_16
.LBB1_17:
	movl	%r13d, %ecx
	andl	$2147483640, %ecx               # imm = 0x7FFFFFF8
	xorl	%edi, %edi
	xorl	%esi, %esi
	jmp	.LBB1_18
	.p2align	4, 0x90
.LBB1_43:                               #   in Loop: Header=BB1_18 Depth=1
	addl	%r8d, %esi
	imull	$1664525, %ebx, %ebx            # imm = 0x19660D
	addl	$1013904223, %ebx               # imm = 0x3C6EF35F
	movl	%ebx, (%r12)
	incq	%rdi
	cmpq	%r15, %rdi
	je	.LBB1_44
.LBB1_18:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_22 Depth 2
                                        #     Child Loop BB1_24 Depth 2
                                        #     Child Loop BB1_28 Depth 2
                                        #     Child Loop BB1_30 Depth 2
                                        #     Child Loop BB1_34 Depth 2
                                        #     Child Loop BB1_36 Depth 2
                                        #     Child Loop BB1_40 Depth 2
                                        #     Child Loop BB1_42 Depth 2
	movl	%ebx, %r8d
	testl	%r14d, %r14d
	je	.LBB1_43
# %bb.19:                               #   in Loop: Header=BB1_18 Depth=1
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r14d
	cmpl	$8, %r14d
	jae	.LBB1_21
# %bb.20:                               #   in Loop: Header=BB1_18 Depth=1
	xorl	%edx, %edx
	movl	%ebx, %r8d
	jmp	.LBB1_24
	.p2align	4, 0x90
.LBB1_21:                               #   in Loop: Header=BB1_18 Depth=1
	movd	%ebx, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm2                # xmm2 = xmm1[0,0,0,0]
	pxor	%xmm1, %xmm1
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB1_22:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movdqu	(%r12,%rdx,4), %xmm3
	movdqu	16(%r12,%rdx,4), %xmm4
	pxor	%xmm2, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm2, %xmm4
	paddd	%xmm4, %xmm1
	addq	$8, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB1_22
# %bb.23:                               #   in Loop: Header=BB1_18 Depth=1
	paddd	%xmm0, %xmm1
	pshufd	$238, %xmm1, %xmm0              # xmm0 = xmm1[2,3,2,3]
	paddd	%xmm1, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r8d
	movq	%rcx, %rdx
	cmpq	%r13, %rcx
	je	.LBB1_25
	.p2align	4, 0x90
.LBB1_24:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	(%r12,%rdx,4), %r9d
	xorl	%eax, %r9d
	addl	%r9d, %r8d
	incq	%rdx
	cmpq	%rdx, %r13
	jne	.LBB1_24
.LBB1_25:                               #   in Loop: Header=BB1_18 Depth=1
	leal	1(%rbx), %eax
	xorl	%edx, %edx
	divl	%r14d
	cmpl	$8, %r14d
	jae	.LBB1_27
# %bb.26:                               #   in Loop: Header=BB1_18 Depth=1
	xorl	%edx, %edx
	jmp	.LBB1_30
	.p2align	4, 0x90
.LBB1_27:                               #   in Loop: Header=BB1_18 Depth=1
	movd	%r8d, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm2                # xmm2 = xmm1[0,0,0,0]
	pxor	%xmm1, %xmm1
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB1_28:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movdqu	(%r12,%rdx,4), %xmm3
	movdqu	16(%r12,%rdx,4), %xmm4
	pxor	%xmm2, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm2, %xmm4
	paddd	%xmm4, %xmm1
	addq	$8, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB1_28
# %bb.29:                               #   in Loop: Header=BB1_18 Depth=1
	paddd	%xmm0, %xmm1
	pshufd	$238, %xmm1, %xmm0              # xmm0 = xmm1[2,3,2,3]
	paddd	%xmm1, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r8d
	movq	%rcx, %rdx
	cmpq	%r13, %rcx
	je	.LBB1_31
	.p2align	4, 0x90
.LBB1_30:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	(%r12,%rdx,4), %r9d
	xorl	%eax, %r9d
	addl	%r9d, %r8d
	incq	%rdx
	cmpq	%rdx, %r13
	jne	.LBB1_30
.LBB1_31:                               #   in Loop: Header=BB1_18 Depth=1
	leal	2(%rbx), %eax
	xorl	%edx, %edx
	divl	%r14d
	cmpl	$8, %r14d
	jae	.LBB1_33
# %bb.32:                               #   in Loop: Header=BB1_18 Depth=1
	xorl	%edx, %edx
	jmp	.LBB1_36
	.p2align	4, 0x90
.LBB1_33:                               #   in Loop: Header=BB1_18 Depth=1
	movd	%r8d, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm2                # xmm2 = xmm1[0,0,0,0]
	pxor	%xmm1, %xmm1
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB1_34:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movdqu	(%r12,%rdx,4), %xmm3
	movdqu	16(%r12,%rdx,4), %xmm4
	pxor	%xmm2, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm2, %xmm4
	paddd	%xmm4, %xmm1
	addq	$8, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB1_34
# %bb.35:                               #   in Loop: Header=BB1_18 Depth=1
	paddd	%xmm0, %xmm1
	pshufd	$238, %xmm1, %xmm0              # xmm0 = xmm1[2,3,2,3]
	paddd	%xmm1, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r8d
	movq	%rcx, %rdx
	cmpq	%r13, %rcx
	je	.LBB1_37
	.p2align	4, 0x90
.LBB1_36:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	(%r12,%rdx,4), %r9d
	xorl	%eax, %r9d
	addl	%r9d, %r8d
	incq	%rdx
	cmpq	%rdx, %r13
	jne	.LBB1_36
.LBB1_37:                               #   in Loop: Header=BB1_18 Depth=1
	leal	3(%rbx), %eax
	xorl	%edx, %edx
	divl	%r14d
	cmpl	$8, %r14d
	jae	.LBB1_39
# %bb.38:                               #   in Loop: Header=BB1_18 Depth=1
	xorl	%edx, %edx
	jmp	.LBB1_42
	.p2align	4, 0x90
.LBB1_39:                               #   in Loop: Header=BB1_18 Depth=1
	movd	%r8d, %xmm0
	movd	%eax, %xmm1
	pshufd	$0, %xmm1, %xmm2                # xmm2 = xmm1[0,0,0,0]
	pxor	%xmm1, %xmm1
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB1_40:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movdqu	(%r12,%rdx,4), %xmm3
	movdqu	16(%r12,%rdx,4), %xmm4
	pxor	%xmm2, %xmm3
	paddd	%xmm3, %xmm0
	pxor	%xmm2, %xmm4
	paddd	%xmm4, %xmm1
	addq	$8, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB1_40
# %bb.41:                               #   in Loop: Header=BB1_18 Depth=1
	paddd	%xmm0, %xmm1
	pshufd	$238, %xmm1, %xmm0              # xmm0 = xmm1[2,3,2,3]
	paddd	%xmm1, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %r8d
	movq	%rcx, %rdx
	cmpq	%r13, %rcx
	je	.LBB1_43
	.p2align	4, 0x90
.LBB1_42:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	(%r12,%rdx,4), %r9d
	xorl	%eax, %r9d
	addl	%r9d, %r8d
	incq	%rdx
	cmpq	%rdx, %r13
	jne	.LBB1_42
	jmp	.LBB1_43
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
