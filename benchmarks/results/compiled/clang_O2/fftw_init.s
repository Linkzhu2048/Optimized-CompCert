	.text
	.file	"fftw_init.c"
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function init_input
.LCPI0_0:
	.long	0                               # 0x0
	.long	1                               # 0x1
	.zero	4
	.zero	4
.LCPI0_1:
	.long	2                               # 0x2
	.long	2                               # 0x2
	.zero	4
	.zero	4
.LCPI0_2:
	.long	4                               # 0x4
	.long	4                               # 0x4
	.zero	4
	.zero	4
.LCPI0_3:
	.long	6                               # 0x6
	.long	6                               # 0x6
	.zero	4
	.zero	4
.LCPI0_4:
	.long	8                               # 0x8
	.long	8                               # 0x8
	.zero	4
	.zero	4
	.text
	.globl	init_input
	.p2align	4, 0x90
	.type	init_input,@function
init_input:                             # @init_input
	.cfi_startproc
# %bb.0:
	movd	%edi, %xmm0
	pshufd	$80, %xmm0, %xmm0               # xmm0 = xmm0[0,0,1,1]
	movdqa	.LCPI0_0(%rip), %xmm1           # xmm1 = [0,1,u,u]
	xorl	%eax, %eax
	movdqa	.LCPI0_1(%rip), %xmm2           # xmm2 = [2,2,u,u]
	leaq	input(%rip), %rcx
	movdqa	.LCPI0_2(%rip), %xmm3           # xmm3 = [4,4,u,u]
	movdqa	.LCPI0_3(%rip), %xmm4           # xmm4 = [6,6,u,u]
	movdqa	.LCPI0_4(%rip), %xmm5           # xmm5 = [8,8,u,u]
	.p2align	4, 0x90
.LBB0_1:                                # =>This Inner Loop Header: Depth=1
	movdqa	%xmm1, %xmm6
	paddd	%xmm0, %xmm6
	movdqa	%xmm6, %xmm7
	paddd	%xmm2, %xmm7
	cvtdq2pd	%xmm6, %xmm8
	cvtdq2pd	%xmm7, %xmm7
	movaps	%xmm8, (%rcx,%rax,8)
	movaps	%xmm7, 16(%rcx,%rax,8)
	movdqa	%xmm6, %xmm7
	paddd	%xmm3, %xmm7
	cvtdq2pd	%xmm7, %xmm7
	paddd	%xmm4, %xmm6
	cvtdq2pd	%xmm6, %xmm6
	movaps	%xmm7, 32(%rcx,%rax,8)
	movaps	%xmm6, 48(%rcx,%rax,8)
	addq	$8, %rax
	paddd	%xmm5, %xmm1
	cmpq	$1024, %rax                     # imm = 0x400
	jne	.LBB0_1
# %bb.2:
	retq
.Lfunc_end0:
	.size	init_input, .Lfunc_end0-init_input
	.cfi_endproc
                                        # -- End function
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function main
.LCPI1_0:
	.long	0                               # 0x0
	.long	1                               # 0x1
	.zero	4
	.zero	4
.LCPI1_1:
	.long	2                               # 0x2
	.long	2                               # 0x2
	.zero	4
	.zero	4
.LCPI1_2:
	.long	4                               # 0x4
	.long	4                               # 0x4
	.zero	4
	.zero	4
.LCPI1_3:
	.long	6                               # 0x6
	.long	6                               # 0x6
	.zero	4
	.zero	4
.LCPI1_4:
	.long	8                               # 0x8
	.long	8                               # 0x8
	.zero	4
	.zero	4
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
	pushq	%r12
	.cfi_def_cfa_offset 40
	pushq	%rbx
	.cfi_def_cfa_offset 48
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movl	$2048, %r15d                    # imm = 0x800
	movl	$65536, %ebx                    # imm = 0x10000
	movl	$4, %r14d
	cmpl	$2, %edi
	jl	.LBB1_4
# %bb.1:
	movq	%rsi, %r12
	movl	%edi, %ebp
	movq	8(%rsi), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtol@PLT
	movq	%rax, %rbx
	cmpl	$2, %ebp
	je	.LBB1_4
# %bb.2:
	movq	16(%r12), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %r14
	cmpl	$4, %ebp
	jb	.LBB1_4
# %bb.3:
	movq	24(%r12), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %r15
.LBB1_4:
	movl	$2, %ebp
	cmpl	$1048576, %ebx                  # imm = 0x100000
	ja	.LBB1_15
# %bb.5:
	testq	%r14, %r14
	je	.LBB1_15
# %bb.6:
	cmpq	$1000000, %r14                  # imm = 0xF4240
	ja	.LBB1_15
# %bb.7:
	xorl	%eax, %eax
	movdqa	.LCPI1_0(%rip), %xmm0           # xmm0 = [0,1,u,u]
	movdqa	.LCPI1_1(%rip), %xmm1           # xmm1 = [2,2,u,u]
	leaq	input(%rip), %rcx
	movdqa	.LCPI1_2(%rip), %xmm2           # xmm2 = [4,4,u,u]
	movdqa	.LCPI1_3(%rip), %xmm3           # xmm3 = [6,6,u,u]
	movdqa	.LCPI1_4(%rip), %xmm4           # xmm4 = [8,8,u,u]
	xorl	%esi, %esi
	jmp	.LBB1_8
	.p2align	4, 0x90
.LBB1_13:                               #   in Loop: Header=BB1_8 Depth=1
	incq	%rax
	cmpq	%r14, %rax
	je	.LBB1_14
.LBB1_8:                                # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_10 Depth 2
                                        #       Child Loop BB1_11 Depth 3
	testl	%ebx, %ebx
	je	.LBB1_13
# %bb.9:                                #   in Loop: Header=BB1_8 Depth=1
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB1_10:                               #   Parent Loop BB1_8 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB1_11 Depth 3
	movzwl	%r15w, %edi
	movd	%edi, %xmm5
	pshufd	$80, %xmm5, %xmm5               # xmm5 = xmm5[0,0,1,1]
	xorl	%edi, %edi
	movdqa	%xmm0, %xmm6
	.p2align	4, 0x90
.LBB1_11:                               #   Parent Loop BB1_8 Depth=1
                                        #     Parent Loop BB1_10 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	movdqa	%xmm5, %xmm7
	paddd	%xmm6, %xmm7
	movdqa	%xmm7, %xmm8
	paddd	%xmm1, %xmm8
	cvtdq2pd	%xmm7, %xmm9
	cvtdq2pd	%xmm8, %xmm8
	movaps	%xmm9, (%rcx,%rdi,8)
	movaps	%xmm8, 16(%rcx,%rdi,8)
	movdqa	%xmm7, %xmm8
	paddd	%xmm2, %xmm8
	cvtdq2pd	%xmm8, %xmm8
	paddd	%xmm3, %xmm7
	cvtdq2pd	%xmm7, %xmm7
	movaps	%xmm8, 32(%rcx,%rdi,8)
	movaps	%xmm7, 48(%rcx,%rdi,8)
	addq	$8, %rdi
	paddd	%xmm4, %xmm6
	cmpq	$1024, %rdi                     # imm = 0x400
	jne	.LBB1_11
# %bb.12:                               #   in Loop: Header=BB1_10 Depth=2
	imull	$1664525, %r15d, %edi           # imm = 0x19660D
	andl	$1023, %r15d                    # imm = 0x3FF
	cvttsd2si	(%rcx,%r15,8), %r8
	addl	%r8d, %esi
	leal	(%rdi,%rsi), %r15d
	addl	$1013904223, %r15d              # imm = 0x3C6EF35F
	incl	%edx
	cmpl	%ebx, %edx
	jne	.LBB1_10
	jmp	.LBB1_13
.LBB1_14:
	leaq	.L.str(%rip), %rdi
	xorl	%ebp, %ebp
                                        # kill: def $esi killed $esi killed $rsi
	xorl	%eax, %eax
	callq	printf@PLT
.LBB1_15:
	movl	%ebp, %eax
	popq	%rbx
	.cfi_def_cfa_offset 40
	popq	%r12
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
	.type	input,@object                   # @input
	.local	input
	.comm	input,8192,16
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"%u\n"
	.size	.L.str, 4

	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
