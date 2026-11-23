	.text
	.file	"store_mul.c"
	.globl	scan                            # -- Begin function scan
	.p2align	4, 0x90
	.type	scan,@function
scan:                                   # @scan
	.cfi_startproc
# %bb.0:
	movl	%ecx, %eax
	testl	%edx, %edx
	jle	.LBB0_10
# %bb.1:
	movl	%eax, %ecx
	imull	%edx, %ecx
	movl	%edx, %r8d
	xorl	%r9d, %r9d
	cmpl	$8, %edx
	jb	.LBB0_6
# %bb.2:
	movq	%rsi, %rdx
	subq	%rdi, %rdx
	cmpq	$32, %rdx
	jb	.LBB0_6
# %bb.3:
	movl	%r8d, %r9d
	andl	$2147483640, %r9d               # imm = 0x7FFFFFF8
	movd	%eax, %xmm0
	movd	%ecx, %xmm1
	pshufd	$0, %xmm1, %xmm1                # xmm1 = xmm1[0,0,0,0]
	movl	%r8d, %eax
	shrl	$3, %eax
	andl	$268435455, %eax                # imm = 0xFFFFFFF
	shlq	$5, %rax
	pxor	%xmm2, %xmm2
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB0_4:                                # =>This Inner Loop Header: Depth=1
	movdqu	(%rdi,%rdx), %xmm3
	movdqu	16(%rdi,%rdx), %xmm4
	pxor	%xmm1, %xmm3
	pxor	%xmm1, %xmm4
	movdqu	%xmm3, (%rsi,%rdx)
	movdqu	%xmm4, 16(%rsi,%rdx)
	paddd	%xmm3, %xmm0
	paddd	%xmm4, %xmm2
	addq	$32, %rdx
	cmpq	%rdx, %rax
	jne	.LBB0_4
# %bb.5:
	paddd	%xmm0, %xmm2
	pshufd	$238, %xmm2, %xmm0              # xmm0 = xmm2[2,3,2,3]
	paddd	%xmm2, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %eax
	cmpq	%r8, %r9
	je	.LBB0_10
.LBB0_6:
	movq	%r8, %r10
	movq	%r9, %rdx
	andq	$3, %r10
	je	.LBB0_8
	.p2align	4, 0x90
.LBB0_7:                                # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%rdx,4), %r11d
	xorl	%ecx, %r11d
	movl	%r11d, (%rsi,%rdx,4)
	addl	%r11d, %eax
	incq	%rdx
	decq	%r10
	jne	.LBB0_7
.LBB0_8:
	subq	%r8, %r9
	cmpq	$-4, %r9
	ja	.LBB0_10
	.p2align	4, 0x90
.LBB0_9:                                # =>This Inner Loop Header: Depth=1
	movl	(%rdi,%rdx,4), %r9d
	xorl	%ecx, %r9d
	movl	%r9d, (%rsi,%rdx,4)
	addl	%eax, %r9d
	movl	4(%rdi,%rdx,4), %eax
	xorl	%ecx, %eax
	movl	%eax, 4(%rsi,%rdx,4)
	movl	8(%rdi,%rdx,4), %r10d
	xorl	%ecx, %r10d
	movl	%r10d, 8(%rsi,%rdx,4)
	addl	%eax, %r10d
	addl	%r9d, %r10d
	movl	12(%rdi,%rdx,4), %eax
	xorl	%ecx, %eax
	movl	%eax, 12(%rsi,%rdx,4)
	addl	%r10d, %eax
	addq	$4, %rdx
	cmpq	%rdx, %r8
	jne	.LBB0_9
.LBB0_10:
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
	movl	$2048, %r12d                    # imm = 0x800
	movl	$65536, %r15d                   # imm = 0x10000
	movl	$4096, %ecx                     # imm = 0x1000
	cmpl	$2, %edi
	jl	.LBB1_5
# %bb.1:
	movq	%rsi, %rbx
	movl	%edi, %ebp
	movq	8(%rsi), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtol@PLT
	movq	%rax, %r15
	cmpl	$2, %ebp
	jne	.LBB1_3
# %bb.2:
	movl	$4096, %ecx                     # imm = 0x1000
	jmp	.LBB1_5
.LBB1_3:
	movq	16(%rbx), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %rcx
	cmpl	$4, %ebp
	jb	.LBB1_5
# %bb.4:
	movq	24(%rbx), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	movq	%rcx, %rbx
	callq	strtoul@PLT
	movq	%rbx, %rcx
	movq	%rax, %r12
.LBB1_5:
	movl	$2, %r13d
	cmpl	$1048576, %r15d                 # imm = 0x100000
	ja	.LBB1_38
# %bb.6:
	testq	%rcx, %rcx
	je	.LBB1_38
# %bb.7:
	cmpq	$1000000, %rcx                  # imm = 0xF4240
	ja	.LBB1_38
# %bb.8:
	movq	%rcx, %rbp
	movl	%r15d, %r13d
	leaq	4(,%r13,4), %r14
	movq	%r14, %rdi
	callq	malloc@PLT
	movq	%rax, %rbx
	movq	%r14, %rdi
	callq	malloc@PLT
	movq	%rax, %r14
	testq	%rbx, %rbx
	je	.LBB1_39
# %bb.9:
	testq	%r14, %r14
	je	.LBB1_39
# %bb.10:
	testl	%r15d, %r15d
	movq	%rbp, %r9
	je	.LBB1_11
# %bb.15:
	cmpl	$8, %r15d
	jae	.LBB1_17
# %bb.16:
	xorl	%eax, %eax
	jmp	.LBB1_20
.LBB1_39:
	movq	%rbx, %rdi
	callq	free@PLT
	movl	$1, %r13d
	movq	%r14, %rbx
	jmp	.LBB1_37
.LBB1_17:
	movl	%r13d, %eax
	andl	$2147483640, %eax               # imm = 0x7FFFFFF8
	movd	%r12d, %xmm0
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
.LBB1_18:                               # =>This Inner Loop Header: Depth=1
	movdqa	%xmm1, %xmm5
	pmuludq	%xmm2, %xmm5
	pshufd	$232, %xmm5, %xmm5              # xmm5 = xmm5[0,2,2,3]
	pshufd	$245, %xmm1, %xmm6              # xmm6 = xmm1[1,1,3,3]
	pmuludq	%xmm2, %xmm6
	pshufd	$232, %xmm6, %xmm6              # xmm6 = xmm6[0,2,2,3]
	punpckldq	%xmm6, %xmm5            # xmm5 = xmm5[0],xmm6[0],xmm5[1],xmm6[1]
	paddd	%xmm0, %xmm5
	movdqu	%xmm5, (%rbx,%rdx)
	paddd	%xmm3, %xmm5
	movdqu	%xmm5, 16(%rbx,%rdx)
	paddd	%xmm4, %xmm1
	addq	$32, %rdx
	cmpq	%rdx, %rcx
	jne	.LBB1_18
# %bb.19:
	cmpq	%r13, %rax
	je	.LBB1_11
.LBB1_20:
	imull	$1640531535, %eax, %edx         # imm = 0x61C8864F
	movl	%r12d, %ecx
	subl	%edx, %ecx
	.p2align	4, 0x90
.LBB1_21:                               # =>This Inner Loop Header: Depth=1
	movl	%ecx, (%rbx,%rax,4)
	incq	%rax
	addl	$-1640531535, %ecx              # imm = 0x9E3779B1
	cmpq	%rax, %r13
	jne	.LBB1_21
.LBB1_11:
	movl	%r13d, %eax
	andl	$2147483640, %eax               # imm = 0x7FFFFFF8
	xorl	%ecx, %ecx
	xorl	%ebp, %ebp
	jmp	.LBB1_12
	.p2align	4, 0x90
.LBB1_30:                               #   in Loop: Header=BB1_12 Depth=1
	addl	%r12d, %ebp
	imull	$1664525, %r12d, %r12d          # imm = 0x19660D
	addl	$1013904223, %r12d              # imm = 0x3C6EF35F
	movl	%r12d, (%rbx)
	incq	%rcx
	cmpq	%r9, %rcx
	je	.LBB1_36
.LBB1_12:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_26 Depth 2
                                        #     Child Loop BB1_28 Depth 2
	testl	%r15d, %r15d
	je	.LBB1_30
# %bb.13:                               #   in Loop: Header=BB1_12 Depth=1
	movl	%r12d, %edx
	imull	%r15d, %edx
	cmpl	$8, %r15d
	jae	.LBB1_25
# %bb.14:                               #   in Loop: Header=BB1_12 Depth=1
	xorl	%edi, %edi
	movl	%r12d, %esi
	jmp	.LBB1_28
	.p2align	4, 0x90
.LBB1_25:                               #   in Loop: Header=BB1_12 Depth=1
	movd	%r12d, %xmm0
	movd	%edx, %xmm1
	pshufd	$0, %xmm1, %xmm2                # xmm2 = xmm1[0,0,0,0]
	pxor	%xmm1, %xmm1
	xorl	%esi, %esi
	.p2align	4, 0x90
.LBB1_26:                               #   Parent Loop BB1_12 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movdqu	(%rbx,%rsi,4), %xmm3
	movdqu	16(%rbx,%rsi,4), %xmm4
	pxor	%xmm2, %xmm3
	pxor	%xmm2, %xmm4
	movdqu	%xmm3, (%r14,%rsi,4)
	movdqu	%xmm4, 16(%r14,%rsi,4)
	paddd	%xmm3, %xmm0
	paddd	%xmm4, %xmm1
	addq	$8, %rsi
	cmpq	%rsi, %rax
	jne	.LBB1_26
# %bb.27:                               #   in Loop: Header=BB1_12 Depth=1
	paddd	%xmm0, %xmm1
	pshufd	$238, %xmm1, %xmm0              # xmm0 = xmm1[2,3,2,3]
	paddd	%xmm1, %xmm0
	pshufd	$85, %xmm0, %xmm1               # xmm1 = xmm0[1,1,1,1]
	paddd	%xmm0, %xmm1
	movd	%xmm1, %esi
	movq	%rax, %rdi
	cmpq	%r13, %rax
	je	.LBB1_29
	.p2align	4, 0x90
.LBB1_28:                               #   Parent Loop BB1_12 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	(%rbx,%rdi,4), %r8d
	xorl	%edx, %r8d
	movl	%r8d, (%r14,%rdi,4)
	addl	%r8d, %esi
	incq	%rdi
	cmpq	%rdi, %r13
	jne	.LBB1_28
.LBB1_29:                               #   in Loop: Header=BB1_12 Depth=1
	addl	%esi, %ebp
	imull	$1664525, %r12d, %r12d          # imm = 0x19660D
	addl	$1013904223, %r12d              # imm = 0x3C6EF35F
	movl	%r12d, (%rbx)
	incq	%rcx
	cmpq	%r9, %rcx
	jne	.LBB1_12
# %bb.22:
	testl	%r15d, %r15d
	je	.LBB1_36
# %bb.23:
	movl	%r13d, %eax
	andl	$3, %eax
	cmpl	$4, %r15d
	jae	.LBB1_31
# %bb.24:
	xorl	%ecx, %ecx
	jmp	.LBB1_33
.LBB1_31:
	andl	$2147483644, %r13d              # imm = 0x7FFFFFFC
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB1_32:                               # =>This Inner Loop Header: Depth=1
	movl	%ebp, %edx
	shll	$5, %edx
	addl	%ebp, %edx
	addl	(%r14,%rcx,4), %edx
	movl	%edx, %esi
	shll	$5, %esi
	addl	%edx, %esi
	addl	4(%r14,%rcx,4), %esi
	movl	%esi, %edx
	shll	$5, %edx
	addl	%esi, %edx
	addl	8(%r14,%rcx,4), %edx
	movl	%edx, %ebp
	shll	$5, %ebp
	addl	%edx, %ebp
	addl	12(%r14,%rcx,4), %ebp
	addq	$4, %rcx
	cmpq	%rcx, %r13
	jne	.LBB1_32
.LBB1_33:
	testq	%rax, %rax
	je	.LBB1_36
# %bb.34:
	leaq	(%r14,%rcx,4), %rcx
	xorl	%edx, %edx
	movl	%ebp, %esi
	.p2align	4, 0x90
.LBB1_35:                               # =>This Inner Loop Header: Depth=1
	shll	$5, %ebp
	addl	%esi, %ebp
	addl	(%rcx,%rdx,4), %ebp
	incq	%rdx
	movl	%ebp, %esi
	cmpq	%rdx, %rax
	jne	.LBB1_35
.LBB1_36:
	movq	%r14, %rdi
	callq	free@PLT
	leaq	.L.str(%rip), %rdi
	xorl	%r13d, %r13d
	movl	%ebp, %esi
	xorl	%eax, %eax
	callq	printf@PLT
.LBB1_37:
	movq	%rbx, %rdi
	callq	free@PLT
.LBB1_38:
	movl	%r13d, %eax
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
