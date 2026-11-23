	.text
	.file	"sha1_expand.c"
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function expand
.LCPI0_0:
	.long	2654435761                      # 0x9e3779b1
	.long	1013904226                      # 0x3c6ef362
	.long	3668339987                      # 0xdaa66d13
	.long	2027808452                      # 0x78dde6c4
.LCPI0_1:
	.long	387276917                       # 0x17156075
	.long	3041712678                      # 0xb54cda26
	.long	1401181143                      # 0x538453d7
	.long	4055616904                      # 0xf1bbcd88
.LCPI0_2:
	.long	2415085369                      # 0x8ff34739
	.long	774553834                       # 0x2e2ac0ea
	.long	3428989595                      # 0xcc623a9b
	.long	1788458060                      # 0x6a99b44c
	.text
	.globl	expand
	.p2align	4, 0x90
	.type	expand,@function
expand:                                 # @expand
	.cfi_startproc
# %bb.0:
	subq	$200, %rsp
	.cfi_def_cfa_offset 208
                                        # kill: def $edi killed $edi def $rdi
	movl	%edi, -128(%rsp)
	movd	%edi, %xmm0
	pshufd	$0, %xmm0, %xmm0                # xmm0 = xmm0[0,0,0,0]
	movdqa	.LCPI0_0(%rip), %xmm1           # xmm1 = [2654435761,1013904226,3668339987,2027808452]
	paddd	%xmm0, %xmm1
	movdqu	%xmm1, -124(%rsp)
	movdqa	.LCPI0_1(%rip), %xmm1           # xmm1 = [387276917,3041712678,1401181143,4055616904]
	paddd	%xmm0, %xmm1
	movdqu	%xmm1, -108(%rsp)
	paddd	.LCPI0_2(%rip), %xmm0
	movdqu	%xmm0, -92(%rsp)
	leal	147926525(%rdi), %eax
	movl	%eax, -76(%rsp)
	leal	-1492605010(%rdi), %eax
	movl	%eax, -72(%rsp)
	addl	$1161830751, %edi               # imm = 0x4540215F
	movl	%edi, -68(%rsp)
	movl	$16, %eax
	.p2align	4, 0x90
.LBB0_1:                                # =>This Inner Loop Header: Depth=1
	movl	-160(%rsp,%rax,4), %ecx
	xorl	-140(%rsp,%rax,4), %ecx
	xorl	-184(%rsp,%rax,4), %ecx
	xorl	-192(%rsp,%rax,4), %ecx
	roll	%ecx
	movl	%ecx, -128(%rsp,%rax,4)
	incq	%rax
	cmpq	$80, %rax
	jne	.LBB0_1
# %bb.2:
	movl	188(%rsp), %eax
	xorl	-64(%rsp), %eax
	addq	$200, %rsp
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end0:
	.size	expand, .Lfunc_end0-expand
	.cfi_endproc
                                        # -- End function
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function main
.LCPI1_0:
	.long	2654435761                      # 0x9e3779b1
	.long	1013904226                      # 0x3c6ef362
	.long	3668339987                      # 0xdaa66d13
	.long	2027808452                      # 0x78dde6c4
.LCPI1_1:
	.long	387276917                       # 0x17156075
	.long	3041712678                      # 0xb54cda26
	.long	1401181143                      # 0x538453d7
	.long	4055616904                      # 0xf1bbcd88
.LCPI1_2:
	.long	2415085369                      # 0x8ff34739
	.long	774553834                       # 0x2e2ac0ea
	.long	3428989595                      # 0xcc623a9b
	.long	1788458060                      # 0x6a99b44c
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
	subq	$320, %rsp                      # imm = 0x140
	.cfi_def_cfa_offset 368
	.cfi_offset %rbx, -48
	.cfi_offset %r12, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movl	$2048, %r15d                    # imm = 0x800
	movl	$4096, %ebx                     # imm = 0x1000
	movl	$256, %r14d                     # imm = 0x100
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
	movdqa	.LCPI1_0(%rip), %xmm0           # xmm0 = [2654435761,1013904226,3668339987,2027808452]
	movdqa	.LCPI1_1(%rip), %xmm1           # xmm1 = [387276917,3041712678,1401181143,4055616904]
	movdqa	.LCPI1_2(%rip), %xmm2           # xmm2 = [2415085369,774553834,3428989595,1788458060]
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
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB1_10:                               #   Parent Loop BB1_8 Depth=1
                                        # =>  This Loop Header: Depth=2
                                        #       Child Loop BB1_11 Depth 3
	movl	%r15d, (%rsp)
	movd	%r15d, %xmm3
	pshufd	$0, %xmm3, %xmm3                # xmm3 = xmm3[0,0,0,0]
	movdqa	%xmm3, %xmm4
	paddd	%xmm0, %xmm4
	movdqu	%xmm4, 4(%rsp)
	movdqa	%xmm3, %xmm4
	paddd	%xmm1, %xmm4
	movdqu	%xmm4, 20(%rsp)
	paddd	%xmm2, %xmm3
	movdqu	%xmm3, 36(%rsp)
	leal	147926525(%r15), %edx
	movl	%edx, 52(%rsp)
	leal	-1492605010(%r15), %edx
	movl	%edx, 56(%rsp)
	leal	1161830751(%r15), %edx
	movl	%edx, 60(%rsp)
	movl	$16, %edx
	.p2align	4, 0x90
.LBB1_11:                               #   Parent Loop BB1_8 Depth=1
                                        #     Parent Loop BB1_10 Depth=2
                                        # =>    This Inner Loop Header: Depth=3
	movl	-32(%rsp,%rdx,4), %edi
	xorl	-12(%rsp,%rdx,4), %edi
	xorl	-56(%rsp,%rdx,4), %edi
	xorl	-64(%rsp,%rdx,4), %edi
	roll	%edi
	movl	%edi, (%rsp,%rdx,4)
	incq	%rdx
	cmpq	$80, %rdx
	jne	.LBB1_11
# %bb.12:                               #   in Loop: Header=BB1_10 Depth=2
	movl	316(%rsp), %edx
	xorl	64(%rsp), %edx
	addl	%edx, %esi
	imull	$1664525, %r15d, %edx           # imm = 0x19660D
	leal	(%rdx,%rsi), %r15d
	addl	$1013904223, %r15d              # imm = 0x3C6EF35F
	incl	%ecx
	cmpl	%ebx, %ecx
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
	addq	$320, %rsp                      # imm = 0x140
	.cfi_def_cfa_offset 48
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
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"%u\n"
	.size	.L.str, 4

	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
