	.text
	.file	"changing_div.c"
	.globl	scan                            # -- Begin function scan
	.p2align	4, 0x90
	.type	scan,@function
scan:                                   # @scan
	.cfi_startproc
# %bb.0:
	movl	%edx, %ecx
	testl	%esi, %esi
	jle	.LBB0_5
# %bb.1:
	movl	%esi, %r11d
	cmpl	$1, %esi
	jne	.LBB0_6
# %bb.2:
	xorl	%r10d, %r10d
	movl	%ecx, %r8d
	testb	$1, %r11b
	jne	.LBB0_4
	jmp	.LBB0_5
.LBB0_6:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	movl	%r11d, %ebx
	andl	$2147483646, %ebx               # imm = 0x7FFFFFFE
	xorl	%r10d, %r10d
	movl	%ecx, %r8d
	.p2align	4, 0x90
.LBB0_7:                                # =>This Inner Loop Header: Depth=1
	imull	$1664525, %r8d, %r8d            # imm = 0x19660D
	addl	$1013904223, %r8d               # imm = 0x3C6EF35F
	movl	%r8d, %eax
	xorl	%edx, %edx
	divl	%esi
	movl	%eax, %r9d
	xorl	(%rdi,%r10,4), %r9d
	addl	%ecx, %r9d
	imull	$1664525, %r8d, %r8d            # imm = 0x19660D
	addl	$1013904223, %r8d               # imm = 0x3C6EF35F
	movl	%r8d, %eax
	xorl	%edx, %edx
	divl	%esi
	movl	%eax, %ecx
	xorl	4(%rdi,%r10,4), %ecx
	addl	%r9d, %ecx
	addq	$2, %r10
	cmpq	%r10, %rbx
	jne	.LBB0_7
# %bb.8:
	popq	%rbx
	.cfi_def_cfa_offset 8
	.cfi_restore %rbx
	testb	$1, %r11b
	je	.LBB0_5
.LBB0_4:
	imull	$1664525, %r8d, %eax            # imm = 0x19660D
	addl	$1013904223, %eax               # imm = 0x3C6EF35F
	xorl	%edx, %edx
	divl	%esi
	xorl	(%rdi,%r10,4), %eax
	addl	%eax, %ecx
.LBB0_5:
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
	ja	.LBB1_25
# %bb.5:
	testq	%r15, %r15
	je	.LBB1_25
# %bb.6:
	cmpq	$1000000, %r15                  # imm = 0xF4240
	ja	.LBB1_25
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
	jmp	.LBB1_25
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
	movl	%r13d, %r9d
	andl	$2147483646, %r9d               # imm = 0x7FFFFFFE
	xorl	%r10d, %r10d
	xorl	%esi, %esi
	jmp	.LBB1_18
	.p2align	4, 0x90
.LBB1_23:                               #   in Loop: Header=BB1_18 Depth=1
	addl	%ecx, %esi
	imull	$1664525, %ebx, %ebx            # imm = 0x19660D
	addl	$1013904223, %ebx               # imm = 0x3C6EF35F
	movl	%ebx, (%r12)
	incq	%r10
	cmpq	%r15, %r10
	je	.LBB1_24
.LBB1_18:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_20 Depth 2
	movl	%ebx, %ecx
	testl	%r14d, %r14d
	je	.LBB1_23
# %bb.19:                               #   in Loop: Header=BB1_18 Depth=1
	xorl	%r11d, %r11d
	movl	%ebx, %ecx
	movl	%ebx, %edi
	cmpl	$1, %r14d
	je	.LBB1_21
	.p2align	4, 0x90
.LBB1_20:                               #   Parent Loop BB1_18 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	imull	$1664525, %edi, %edi            # imm = 0x19660D
	addl	$1013904223, %edi               # imm = 0x3C6EF35F
	movl	%edi, %eax
	xorl	%edx, %edx
	divl	%r14d
	movl	%eax, %r8d
	xorl	(%r12,%r11,4), %r8d
	addl	%ecx, %r8d
	imull	$1664525, %edi, %edi            # imm = 0x19660D
	addl	$1013904223, %edi               # imm = 0x3C6EF35F
	movl	%edi, %eax
	xorl	%edx, %edx
	divl	%r14d
	movl	%eax, %ecx
	xorl	4(%r12,%r11,4), %ecx
	addl	%r8d, %ecx
	addq	$2, %r11
	cmpq	%r11, %r9
	jne	.LBB1_20
.LBB1_21:                               #   in Loop: Header=BB1_18 Depth=1
	testb	$1, %r13b
	je	.LBB1_23
# %bb.22:                               #   in Loop: Header=BB1_18 Depth=1
	imull	$1664525, %edi, %eax            # imm = 0x19660D
	addl	$1013904223, %eax               # imm = 0x3C6EF35F
	xorl	%edx, %edx
	divl	%r14d
	xorl	(%r12,%r11,4), %eax
	addl	%eax, %ecx
	jmp	.LBB1_23
.LBB1_24:
	leaq	.L.str(%rip), %rdi
	xorl	%eax, %eax
	callq	printf@PLT
	movq	%r12, %rdi
	callq	free@PLT
	xorl	%eax, %eax
.LBB1_25:
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
