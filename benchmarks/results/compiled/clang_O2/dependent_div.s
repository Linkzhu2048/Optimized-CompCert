	.text
	.file	"dependent_div.c"
	.globl	scan                            # -- Begin function scan
	.p2align	4, 0x90
	.type	scan,@function
scan:                                   # @scan
	.cfi_startproc
# %bb.0:
	movl	%edx, %ecx
                                        # kill: def $esi killed $esi def $rsi
	testl	%esi, %esi
	jle	.LBB0_7
# %bb.1:
	xorl	%r9d, %r9d
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%esi
	movl	%eax, %r8d
	leal	1(%rsi), %r10d
	xorl	%edx, %edx
	divl	%r10d
	movl	%esi, %r10d
	movl	%r10d, %edx
	andl	$3, %edx
	cmpl	$4, %esi
	jb	.LBB0_4
# %bb.2:
	andl	$2147483644, %r10d              # imm = 0x7FFFFFFC
	xorl	%r9d, %r9d
	.p2align	4, 0x90
.LBB0_3:                                # =>This Inner Loop Header: Depth=1
	addl	(%rdi,%r9,4), %ecx
	xorl	%r8d, %ecx
	addl	%eax, %ecx
	addl	4(%rdi,%r9,4), %ecx
	xorl	%r8d, %ecx
	addl	%eax, %ecx
	addl	8(%rdi,%r9,4), %ecx
	xorl	%r8d, %ecx
	addl	%eax, %ecx
	addl	12(%rdi,%r9,4), %ecx
	xorl	%r8d, %ecx
	addl	%eax, %ecx
	addq	$4, %r9
	cmpq	%r9, %r10
	jne	.LBB0_3
.LBB0_4:
	testq	%rdx, %rdx
	je	.LBB0_7
# %bb.5:
	leaq	(%rdi,%r9,4), %rsi
	xorl	%edi, %edi
	.p2align	4, 0x90
.LBB0_6:                                # =>This Inner Loop Header: Depth=1
	addl	(%rsi,%rdi,4), %ecx
	xorl	%r8d, %ecx
	addl	%eax, %ecx
	incq	%rdi
	cmpq	%rdi, %rdx
	jne	.LBB0_6
.LBB0_7:
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
	movl	$4096, %r15d                    # imm = 0x1000
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
	ja	.LBB1_26
# %bb.5:
	testq	%r15, %r15
	je	.LBB1_26
# %bb.6:
	cmpq	$1000000, %r15                  # imm = 0xF4240
	ja	.LBB1_26
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
	jmp	.LBB1_26
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
	leal	1(%r14), %edi
	movl	%r13d, %r8d
	andl	$3, %r8d
	andl	$2147483644, %r13d              # imm = 0x7FFFFFFC
	xorl	%r9d, %r9d
	xorl	%esi, %esi
	jmp	.LBB1_18
	.p2align	4, 0x90
.LBB1_24:                               #   in Loop: Header=BB1_18 Depth=1
	addl	%edx, %esi
	imull	$1664525, %ebx, %ebx            # imm = 0x19660D
	addl	$1013904223, %ebx               # imm = 0x3C6EF35F
	movl	%ebx, (%r12)
	incq	%r9
	cmpq	%r15, %r9
	je	.LBB1_25
.LBB1_18:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_20 Depth 2
                                        #     Child Loop BB1_23 Depth 2
	movl	%ebx, %edx
	testl	%r14d, %r14d
	je	.LBB1_24
# %bb.19:                               #   in Loop: Header=BB1_18 Depth=1
	movl	%ebx, %eax
	xorl	%edx, %edx
	divl	%r14d
	movl	%eax, %ecx
	xorl	%edx, %edx
	divl	%edi
	xorl	%r10d, %r10d
	movl	%ebx, %edx
	cmpl	$4, %r14d
	jb	.LBB1_21
	.p2align	4, 0x90
.LBB1_20:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	addl	(%r12,%r10,4), %edx
	xorl	%ecx, %edx
	addl	%eax, %edx
	addl	4(%r12,%r10,4), %edx
	xorl	%ecx, %edx
	addl	%eax, %edx
	addl	8(%r12,%r10,4), %edx
	xorl	%ecx, %edx
	addl	%eax, %edx
	addl	12(%r12,%r10,4), %edx
	xorl	%ecx, %edx
	addl	%eax, %edx
	addq	$4, %r10
	cmpq	%r10, %r13
	jne	.LBB1_20
.LBB1_21:                               #   in Loop: Header=BB1_18 Depth=1
	testq	%r8, %r8
	je	.LBB1_24
# %bb.22:                               #   in Loop: Header=BB1_18 Depth=1
	leaq	(%r12,%r10,4), %r10
	xorl	%r11d, %r11d
	.p2align	4, 0x90
.LBB1_23:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	addl	(%r10,%r11,4), %edx
	xorl	%ecx, %edx
	addl	%eax, %edx
	incq	%r11
	cmpq	%r11, %r8
	jne	.LBB1_23
	jmp	.LBB1_24
.LBB1_25:
	leaq	.L.str(%rip), %rdi
	xorl	%eax, %eax
	callq	printf@PLT
	movq	%r12, %rdi
	callq	free@PLT
	xorl	%eax, %eax
.LBB1_26:
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
