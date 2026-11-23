	.text
	.file	"spass_stamp.c"
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function term_StampOverflow
.LCPI0_0:
	.long	1                               # 0x1
	.long	1                               # 0x1
	.long	1                               # 0x1
	.long	1                               # 0x1
	.text
	.globl	term_StampOverflow
	.p2align	4, 0x90
	.type	term_StampOverflow,@function
term_StampOverflow:                     # @term_StampOverflow
	.cfi_startproc
# %bb.0:
	cmpl	$-1, term_STAMP(%rip)
	je	.LBB0_1
# %bb.2:
	movl	%edi, %eax
	leaq	term_STAMPOVERFLOW(%rip), %rcx
	cmpl	$0, (%rcx,%rax,4)
	je	.LBB0_6
# %bb.3:
	leaq	(%rcx,%rax,4), %rax
	jmp	.LBB0_4
.LBB0_1:
	movl	$0, term_STAMP(%rip)
	movaps	.LCPI0_0(%rip), %xmm0           # xmm0 = [1,1,1,1]
	movaps	%xmm0, term_STAMPOVERFLOW(%rip)
	leaq	term_STAMPOVERFLOW(%rip), %rax
	movaps	%xmm0, term_STAMPOVERFLOW+16(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+32(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+48(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+64(%rip)
	movl	%edi, %ecx
	leaq	(%rax,%rcx,4), %rax
.LBB0_4:
	movl	$0, (%rax)
	movl	$1, %eax
	retq
.LBB0_6:
	xorl	%eax, %eax
	retq
.Lfunc_end0:
	.size	term_StampOverflow, .Lfunc_end0-term_StampOverflow
	.cfi_endproc
                                        # -- End function
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function main
.LCPI1_0:
	.long	1                               # 0x1
	.long	1                               # 0x1
	.long	1                               # 0x1
	.long	1                               # 0x1
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
	movl	$2048, %ebx                     # imm = 0x800
	movl	$65536, %r14d                   # imm = 0x10000
	movl	$256, %r15d                     # imm = 0x100
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
	movl	$2, %ebp
	cmpl	$1048576, %r14d                 # imm = 0x100000
	ja	.LBB1_18
# %bb.5:
	testq	%r15, %r15
	je	.LBB1_18
# %bb.6:
	cmpq	$1000000, %r15                  # imm = 0xF4240
	ja	.LBB1_18
# %bb.7:
	xorl	%eax, %eax
	movl	$3435973837, %ecx               # imm = 0xCCCCCCCD
	movaps	.LCPI1_0(%rip), %xmm0           # xmm0 = [1,1,1,1]
	leaq	term_STAMPOVERFLOW(%rip), %rdx
	xorl	%esi, %esi
	jmp	.LBB1_8
	.p2align	4, 0x90
.LBB1_15:                               #   in Loop: Header=BB1_8 Depth=1
	movl	$0, term_STAMP(%rip)
.LBB1_16:                               #   in Loop: Header=BB1_8 Depth=1
	incq	%rax
	cmpq	%r15, %rax
	je	.LBB1_17
.LBB1_8:                                # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_10 Depth 2
	testl	%r14d, %r14d
	je	.LBB1_16
# %bb.9:                                #   in Loop: Header=BB1_8 Depth=1
	movl	%r14d, %edi
	jmp	.LBB1_10
	.p2align	4, 0x90
.LBB1_11:                               #   in Loop: Header=BB1_10 Depth=2
	movaps	%xmm0, term_STAMPOVERFLOW(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+16(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+32(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+48(%rip)
	movaps	%xmm0, term_STAMPOVERFLOW+64(%rip)
.LBB1_13:                               #   in Loop: Header=BB1_10 Depth=2
	leaq	(%rdx,%r8,4), %r8
	movl	$0, (%r8)
	movl	$1, %r8d
.LBB1_14:                               #   in Loop: Header=BB1_10 Depth=2
	addl	%r8d, %esi
	imull	$1664525, %ebx, %ebx            # imm = 0x19660D
	addl	$1013904223, %ebx               # imm = 0x3C6EF35F
	decl	%edi
	je	.LBB1_15
.LBB1_10:                               #   Parent Loop BB1_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	%ebx, %r8d
	imulq	%rcx, %r8
	shrq	$36, %r8
	shll	$2, %r8d
	leal	(%r8,%r8,4), %r8d
	movl	%ebx, %r9d
	subl	%r8d, %r9d
	movl	%r9d, %r8d
	testb	$3, %bl
	je	.LBB1_11
# %bb.12:                               #   in Loop: Header=BB1_10 Depth=2
	cmpl	$0, (%rdx,%r8,4)
	jne	.LBB1_13
# %bb.19:                               #   in Loop: Header=BB1_10 Depth=2
	xorl	%r8d, %r8d
	jmp	.LBB1_14
.LBB1_17:
	leaq	.L.str(%rip), %rdi
	xorl	%ebp, %ebp
	xorl	%eax, %eax
	callq	printf@PLT
.LBB1_18:
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
	.type	term_STAMP,@object              # @term_STAMP
	.bss
	.globl	term_STAMP
	.p2align	2, 0x0
term_STAMP:
	.long	0                               # 0x0
	.size	term_STAMP, 4

	.type	term_STAMPOVERFLOW,@object      # @term_STAMPOVERFLOW
	.local	term_STAMPOVERFLOW
	.comm	term_STAMPOVERFLOW,80,16
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"%u\n"
	.size	.L.str, 4

	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
