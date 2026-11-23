	.text
	.file	"arcode_model.c"
	.globl	SymbolCountToProbabilityRanges  # -- Begin function SymbolCountToProbabilityRanges
	.p2align	4, 0x90
	.type	SymbolCountToProbabilityRanges,@function
SymbolCountToProbabilityRanges:         # @SymbolCountToProbabilityRanges
	.cfi_startproc
# %bb.0:
	movw	$0, ranges(%rip)
	incw	cumulativeProb(%rip)
	movw	$1, ranges+514(%rip)
	xorl	%eax, %eax
	leaq	ranges(%rip), %rcx
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB0_1:                                # =>This Inner Loop Header: Depth=1
	addw	2(%rcx,%rax,2), %dx
	movw	%dx, 2(%rcx,%rax,2)
	cmpq	$256, %rax                      # imm = 0x100
	je	.LBB0_3
# %bb.2:                                #   in Loop: Header=BB0_1 Depth=1
	addw	4(%rcx,%rax,2), %dx
	movw	%dx, 4(%rcx,%rax,2)
	addw	6(%rcx,%rax,2), %dx
	movw	%dx, 6(%rcx,%rax,2)
	addw	8(%rcx,%rax,2), %dx
	movw	%dx, 8(%rcx,%rax,2)
	addq	$4, %rax
	jmp	.LBB0_1
.LBB0_3:
	retq
.Lfunc_end0:
	.size	SymbolCountToProbabilityRanges, .Lfunc_end0-SymbolCountToProbabilityRanges
	.cfi_endproc
                                        # -- End function
	.globl	BuildProbabilityRangeList       # -- Begin function BuildProbabilityRangeList
	.p2align	4, 0x90
	.type	BuildProbabilityRangeList,@function
BuildProbabilityRangeList:              # @BuildProbabilityRangeList
	.cfi_startproc
# %bb.0:
	pushq	%r14
	.cfi_def_cfa_offset 16
	pushq	%rbx
	.cfi_def_cfa_offset 24
	subq	$2056, %rsp                     # imm = 0x808
	.cfi_def_cfa_offset 2080
	.cfi_offset %rbx, -24
	.cfi_offset %r14, -16
	movl	%esi, %ebx
	movq	%rdi, %r14
	movq	%rsp, %rdi
	movl	$2048, %edx                     # imm = 0x800
	xorl	%esi, %esi
	callq	memset@PLT
	testl	%ebx, %ebx
	jle	.LBB1_17
# %bb.1:
	movl	%ebx, %esi
	movl	%esi, %eax
	andl	$3, %eax
	cmpl	$4, %ebx
	jae	.LBB1_3
# %bb.2:
	xorl	%ecx, %ecx
	jmp	.LBB1_5
.LBB1_3:
	movl	%esi, %edx
	andl	$2147483644, %edx               # imm = 0x7FFFFFFC
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB1_4:                                # =>This Inner Loop Header: Depth=1
	movzbl	(%r14,%rcx), %edi
	incq	(%rsp,%rdi,8)
	movzbl	1(%r14,%rcx), %edi
	incq	(%rsp,%rdi,8)
	movzbl	2(%r14,%rcx), %edi
	incq	(%rsp,%rdi,8)
	movzbl	3(%r14,%rcx), %edi
	incq	(%rsp,%rdi,8)
	addq	$4, %rcx
	cmpq	%rcx, %rdx
	jne	.LBB1_4
.LBB1_5:
	testq	%rax, %rax
	je	.LBB1_8
# %bb.6:
	addq	%rcx, %r14
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB1_7:                                # =>This Inner Loop Header: Depth=1
	movzbl	(%r14,%rcx), %edx
	incq	(%rsp,%rdx,8)
	incq	%rcx
	cmpq	%rcx, %rax
	jne	.LBB1_7
.LBB1_8:
	cmpl	$16384, %ebx                    # imm = 0x4000
	jb	.LBB1_17
# %bb.9:
	shrl	$14, %esi
	incq	%rsi
	xorl	%edi, %edi
	jmp	.LBB1_10
	.p2align	4, 0x90
.LBB1_11:                               #   in Loop: Header=BB1_10 Depth=1
	movq	%rcx, %rax
	shrq	$32, %rax
	je	.LBB1_12
# %bb.13:                               #   in Loop: Header=BB1_10 Depth=1
	movq	%rcx, %rax
	xorl	%edx, %edx
	divq	%rsi
.LBB1_15:                               #   in Loop: Header=BB1_10 Depth=1
	movq	%rax, (%rsp,%rdi,8)
.LBB1_16:                               #   in Loop: Header=BB1_10 Depth=1
	incq	%rdi
	cmpq	$256, %rdi                      # imm = 0x100
	je	.LBB1_17
.LBB1_10:                               # =>This Inner Loop Header: Depth=1
	movq	(%rsp,%rdi,8), %rcx
	cmpq	%rsi, %rcx
	ja	.LBB1_11
# %bb.14:                               #   in Loop: Header=BB1_10 Depth=1
	movl	$1, %eax
	testq	%rcx, %rcx
	jne	.LBB1_15
	jmp	.LBB1_16
.LBB1_12:                               #   in Loop: Header=BB1_10 Depth=1
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%esi
                                        # kill: def $eax killed $eax def $rax
	jmp	.LBB1_15
.LBB1_17:
	pxor	%xmm0, %xmm0
	xorl	%ecx, %ecx
	leaq	ranges(%rip), %rax
	pxor	%xmm1, %xmm1
	.p2align	4, 0x90
.LBB1_18:                               # =>This Inner Loop Header: Depth=1
	pshufd	$232, (%rsp,%rcx,8), %xmm2      # xmm2 = mem[0,2,2,3]
	pshuflw	$232, %xmm2, %xmm2              # xmm2 = xmm2[0,2,2,3,4,5,6,7]
	pshufd	$232, 16(%rsp,%rcx,8), %xmm3    # xmm3 = mem[0,2,2,3]
	pshufd	$232, 32(%rsp,%rcx,8), %xmm4    # xmm4 = mem[0,2,2,3]
	pshuflw	$232, %xmm3, %xmm3              # xmm3 = xmm3[0,2,2,3,4,5,6,7]
	pshuflw	$232, %xmm4, %xmm4              # xmm4 = xmm4[0,2,2,3,4,5,6,7]
	pshufd	$232, 48(%rsp,%rcx,8), %xmm5    # xmm5 = mem[0,2,2,3]
	pshuflw	$232, %xmm5, %xmm5              # xmm5 = xmm5[0,2,2,3,4,5,6,7]
	paddw	%xmm2, %xmm0
	paddw	%xmm4, %xmm0
	punpckldq	%xmm5, %xmm4            # xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
	punpckldq	%xmm3, %xmm2            # xmm2 = xmm2[0],xmm3[0],xmm2[1],xmm3[1]
	punpcklqdq	%xmm4, %xmm2            # xmm2 = xmm2[0],xmm4[0]
	movdqu	%xmm2, 2(%rax,%rcx,2)
	paddw	%xmm3, %xmm1
	paddw	%xmm5, %xmm1
	addq	$8, %rcx
	cmpq	$256, %rcx                      # imm = 0x100
	jne	.LBB1_18
# %bb.19:
	paddw	%xmm0, %xmm1
	movdqa	%xmm1, %xmm0
	psrld	$16, %xmm0
	paddw	%xmm1, %xmm0
	movd	%xmm0, %ecx
	movw	$0, ranges(%rip)
	movw	$1, ranges+514(%rip)
	incl	%ecx
	movw	%cx, cumulativeProb(%rip)
	xorl	%ecx, %ecx
	xorl	%edx, %edx
	.p2align	4, 0x90
.LBB1_20:                               # =>This Inner Loop Header: Depth=1
	addw	2(%rax,%rcx,2), %dx
	movw	%dx, 2(%rax,%rcx,2)
	cmpq	$256, %rcx                      # imm = 0x100
	je	.LBB1_22
# %bb.21:                               #   in Loop: Header=BB1_20 Depth=1
	addw	4(%rax,%rcx,2), %dx
	movw	%dx, 4(%rax,%rcx,2)
	addw	6(%rax,%rcx,2), %dx
	movw	%dx, 6(%rax,%rcx,2)
	addw	8(%rax,%rcx,2), %dx
	movw	%dx, 8(%rax,%rcx,2)
	addq	$4, %rcx
	jmp	.LBB1_20
.LBB1_22:
	addq	$2056, %rsp                     # imm = 0x808
	.cfi_def_cfa_offset 24
	popq	%rbx
	.cfi_def_cfa_offset 16
	popq	%r14
	.cfi_def_cfa_offset 8
	retq
.Lfunc_end1:
	.size	BuildProbabilityRangeList, .Lfunc_end1-BuildProbabilityRangeList
	.cfi_endproc
                                        # -- End function
	.section	.rodata.cst16,"aM",@progbits,16
	.p2align	4, 0x0                          # -- Begin function main
.LCPI2_0:
	.long	12                              # 0xc
	.long	13                              # 0xd
	.long	14                              # 0xe
	.long	15                              # 0xf
.LCPI2_1:
	.long	8                               # 0x8
	.long	9                               # 0x9
	.long	10                              # 0xa
	.long	11                              # 0xb
.LCPI2_2:
	.long	4                               # 0x4
	.long	5                               # 0x5
	.long	6                               # 0x6
	.long	7                               # 0x7
.LCPI2_3:
	.long	0                               # 0x0
	.long	1                               # 0x1
	.long	2                               # 0x2
	.long	3                               # 0x3
.LCPI2_4:
	.quad	14                              # 0xe
	.quad	15                              # 0xf
.LCPI2_5:
	.quad	12                              # 0xc
	.quad	13                              # 0xd
.LCPI2_6:
	.quad	10                              # 0xa
	.quad	11                              # 0xb
.LCPI2_7:
	.quad	8                               # 0x8
	.quad	9                               # 0x9
.LCPI2_8:
	.quad	6                               # 0x6
	.quad	7                               # 0x7
.LCPI2_9:
	.quad	4                               # 0x4
	.quad	5                               # 0x5
.LCPI2_10:
	.quad	2                               # 0x2
	.quad	3                               # 0x3
.LCPI2_11:
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	1                               # 0x1
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
.LCPI2_12:
	.quad	-9223372034707292160            # 0x8000000080000000
	.quad	-9223372034707292160            # 0x8000000080000000
.LCPI2_13:
	.long	2147483776                      # 0x80000080
	.long	2147483776                      # 0x80000080
	.long	2147483776                      # 0x80000080
	.long	2147483776                      # 0x80000080
.LCPI2_14:
	.zero	16,128
.LCPI2_15:
	.byte	255                             # 0xff
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	255                             # 0xff
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	255                             # 0xff
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	255                             # 0xff
	.byte	0                               # 0x0
	.byte	0                               # 0x0
	.byte	0                               # 0x0
.LCPI2_16:
	.quad	16                              # 0x10
	.quad	16                              # 0x10
.LCPI2_17:
	.long	16                              # 0x10
	.long	16                              # 0x10
	.long	16                              # 0x10
	.long	16                              # 0x10
.LCPI2_18:
	.short	255                             # 0xff
	.short	255                             # 0xff
	.short	255                             # 0xff
	.short	255                             # 0xff
	.short	255                             # 0xff
	.short	255                             # 0xff
	.short	255                             # 0xff
	.short	255                             # 0xff
.LCPI2_19:
	.quad	8                               # 0x8
	.quad	8                               # 0x8
.LCPI2_20:
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
	subq	$2168, %rsp                     # imm = 0x878
	.cfi_def_cfa_offset 2224
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
	jl	.LBB2_4
# %bb.1:
	movq	%rsi, %r12
	movl	%edi, %ebp
	movq	8(%rsi), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtol@PLT
	movq	%rax, %r14
	cmpl	$2, %ebp
	je	.LBB2_4
# %bb.2:
	movq	16(%r12), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %r15
	cmpl	$4, %ebp
	jb	.LBB2_4
# %bb.3:
	movq	24(%r12), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %rbx
.LBB2_4:
	movl	$2, %eax
	cmpl	$1048576, %r14d                 # imm = 0x100000
	ja	.LBB2_48
# %bb.5:
	testq	%r15, %r15
	je	.LBB2_48
# %bb.6:
	cmpq	$1000000, %r15                  # imm = 0xF4240
	ja	.LBB2_48
# %bb.7:
	movl	%r14d, %eax
	movq	%rax, %r13
	leaq	1(%rax), %rdi
	callq	malloc@PLT
	testq	%rax, %rax
	je	.LBB2_8
# %bb.9:
	movq	%rax, %r12
	testl	%r14d, %r14d
	movq	%r13, %rdx
	je	.LBB2_22
# %bb.10:
	xorl	%eax, %eax
	cmpl	$8, %r14d
	jb	.LBB2_20
# %bb.11:
	movd	%ebx, %xmm7
	cmpl	$16, %r14d
	jae	.LBB2_13
# %bb.12:
	xorl	%eax, %eax
.LBB2_17:
	movq	%rax, %rcx
	movq	%rdx, %rax
	xorl	%edx, %edx
	testb	$1, %bl
	sete	%dl
                                        # kill: def $eax killed $eax killed $rax def $rax
	movq	%rcx, %xmm0
	pshufd	$68, %xmm0, %xmm0               # xmm0 = xmm0[0,1,0,1]
	movdqa	.LCPI2_8(%rip), %xmm1           # xmm1 = [6,7]
	por	%xmm0, %xmm1
	movdqa	.LCPI2_9(%rip), %xmm2           # xmm2 = [4,5]
	por	%xmm0, %xmm2
	movdqa	.LCPI2_10(%rip), %xmm3          # xmm3 = [2,3]
	por	%xmm0, %xmm3
	por	.LCPI2_11(%rip), %xmm0
	movd	%ecx, %xmm4
	pshufd	$0, %xmm4, %xmm4                # xmm4 = xmm4[0,0,0,0]
	movdqa	.LCPI2_2(%rip), %xmm5           # xmm5 = [4,5,6,7]
	por	%xmm4, %xmm5
	por	.LCPI2_3(%rip), %xmm4
	andl	$2147483640, %eax               # imm = 0x7FFFFFF8
	movd	%edx, %xmm6
	pshuflw	$0, %xmm6, %xmm6                # xmm6 = xmm6[0,0,0,0,4,5,6,7]
	pshufd	$0, %xmm6, %xmm6                # xmm6 = xmm6[0,0,0,0]
	movdqa	%xmm6, (%rsp)                   # 16-byte Spill
	pshufd	$0, %xmm7, %xmm7                # xmm7 = xmm7[0,0,0,0]
	movdqa	.LCPI2_12(%rip), %xmm8          # xmm8 = [9223372039002259456,9223372039002259456]
	movdqa	.LCPI2_13(%rip), %xmm12         # xmm12 = [2147483776,2147483776,2147483776,2147483776]
	movdqa	.LCPI2_19(%rip), %xmm13         # xmm13 = [8,8]
	movdqa	.LCPI2_20(%rip), %xmm14         # xmm14 = [8,8,8,8]
	.p2align	4, 0x90
.LBB2_18:                               # =>This Inner Loop Header: Depth=1
	movdqa	%xmm0, %xmm15
	pxor	%xmm8, %xmm15
	pshufd	$160, %xmm15, %xmm10            # xmm10 = xmm15[0,0,2,2]
	movdqa	%xmm12, %xmm9
	pcmpgtd	%xmm10, %xmm9
	pshufd	$245, %xmm15, %xmm15            # xmm15 = xmm15[1,1,3,3]
	pcmpeqd	%xmm8, %xmm15
	pand	%xmm9, %xmm15
	movdqa	%xmm3, %xmm9
	pxor	%xmm8, %xmm9
	pshufd	$160, %xmm9, %xmm10             # xmm10 = xmm9[0,0,2,2]
	movdqa	%xmm12, %xmm11
	pcmpgtd	%xmm10, %xmm11
	pshufd	$245, %xmm9, %xmm9              # xmm9 = xmm9[1,1,3,3]
	pcmpeqd	%xmm8, %xmm9
	pand	%xmm11, %xmm9
	packssdw	%xmm9, %xmm15
	movdqa	%xmm2, %xmm9
	pxor	%xmm8, %xmm9
	pshufd	$160, %xmm9, %xmm10             # xmm10 = xmm9[0,0,2,2]
	movdqa	%xmm12, %xmm11
	pcmpgtd	%xmm10, %xmm11
	pshufd	$245, %xmm9, %xmm9              # xmm9 = xmm9[1,1,3,3]
	pcmpeqd	%xmm8, %xmm9
	pand	%xmm11, %xmm9
	movdqa	%xmm1, %xmm10
	pxor	%xmm8, %xmm10
	pshufd	$160, %xmm10, %xmm11            # xmm11 = xmm10[0,0,2,2]
	movdqa	%xmm12, %xmm6
	pcmpgtd	%xmm11, %xmm6
	pshufd	$245, %xmm10, %xmm10            # xmm10 = xmm10[1,1,3,3]
	pcmpeqd	%xmm8, %xmm10
	pand	%xmm6, %xmm10
	packssdw	%xmm10, %xmm9
	packssdw	%xmm9, %xmm15
	por	(%rsp), %xmm15                  # 16-byte Folded Reload
	pand	.LCPI2_18(%rip), %xmm15
	packuswb	%xmm15, %xmm15
	psllw	$7, %xmm15
	pand	.LCPI2_14(%rip), %xmm15
	pxor	%xmm6, %xmm6
	pcmpgtb	%xmm15, %xmm6
	movdqa	%xmm7, %xmm9
	paddd	%xmm5, %xmm9
	movdqa	%xmm7, %xmm10
	paddd	%xmm4, %xmm10
	movdqa	.LCPI2_15(%rip), %xmm11         # xmm11 = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0]
	pand	%xmm11, %xmm10
	pand	%xmm11, %xmm9
	packuswb	%xmm9, %xmm10
	packuswb	%xmm10, %xmm10
	pand	%xmm6, %xmm10
	movq	%xmm10, (%r12,%rcx)
	addq	$8, %rcx
	paddq	%xmm13, %xmm0
	paddq	%xmm13, %xmm3
	paddq	%xmm13, %xmm2
	paddq	%xmm13, %xmm1
	paddd	%xmm14, %xmm4
	paddd	%xmm14, %xmm5
	cmpq	%rcx, %rax
	jne	.LBB2_18
# %bb.19:
	movq	%r13, %rdx
	cmpq	%r13, %rax
	jne	.LBB2_20
	jmp	.LBB2_22
.LBB2_8:
	movl	$1, %eax
	jmp	.LBB2_48
.LBB2_13:
	xorl	%ecx, %ecx
	testb	$1, %bl
	sete	%cl
	movl	%edx, %eax
	andl	$2147483632, %eax               # imm = 0x7FFFFFF0
	movd	%ecx, %xmm0
	punpcklbw	%xmm0, %xmm0            # xmm0 = xmm0[0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7]
	pshuflw	$0, %xmm0, %xmm0                # xmm0 = xmm0[0,0,0,0,4,5,6,7]
	pshufd	$0, %xmm0, %xmm0                # xmm0 = xmm0[0,0,0,0]
	movdqa	%xmm0, 96(%rsp)                 # 16-byte Spill
	movdqa	%xmm7, 64(%rsp)                 # 16-byte Spill
	pshufd	$0, %xmm7, %xmm0                # xmm0 = xmm7[0,0,0,0]
	movdqa	%xmm0, 80(%rsp)                 # 16-byte Spill
	movaps	.LCPI2_0(%rip), %xmm0           # xmm0 = [12,13,14,15]
	movaps	%xmm0, 16(%rsp)                 # 16-byte Spill
	movdqa	.LCPI2_1(%rip), %xmm4           # xmm4 = [8,9,10,11]
	movdqa	.LCPI2_2(%rip), %xmm5           # xmm5 = [4,5,6,7]
	movdqa	.LCPI2_3(%rip), %xmm7           # xmm7 = [0,1,2,3]
	movdqa	.LCPI2_4(%rip), %xmm8           # xmm8 = [14,15]
	movdqa	.LCPI2_5(%rip), %xmm9           # xmm9 = [12,13]
	movdqa	.LCPI2_6(%rip), %xmm10          # xmm10 = [10,11]
	movdqa	.LCPI2_7(%rip), %xmm11          # xmm11 = [8,9]
	movdqa	.LCPI2_8(%rip), %xmm12          # xmm12 = [6,7]
	movdqa	.LCPI2_9(%rip), %xmm13          # xmm13 = [4,5]
	movdqa	.LCPI2_10(%rip), %xmm3          # xmm3 = [2,3]
	movdqa	.LCPI2_11(%rip), %xmm0          # xmm0 = [0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0]
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB2_14:                               # =>This Inner Loop Header: Depth=1
	movdqa	%xmm0, (%rsp)                   # 16-byte Spill
	movdqa	%xmm3, 32(%rsp)                 # 16-byte Spill
	movdqa	%xmm4, 48(%rsp)                 # 16-byte Spill
	movdqa	(%rsp), %xmm0                   # 16-byte Reload
	movdqa	.LCPI2_12(%rip), %xmm6          # xmm6 = [9223372039002259456,9223372039002259456]
	pxor	%xmm6, %xmm0
	pshufd	$160, %xmm0, %xmm2              # xmm2 = xmm0[0,0,2,2]
	movdqa	.LCPI2_13(%rip), %xmm15         # xmm15 = [2147483776,2147483776,2147483776,2147483776]
	movdqa	%xmm15, %xmm1
	pcmpgtd	%xmm2, %xmm1
	pshufd	$245, %xmm0, %xmm2              # xmm2 = xmm0[1,1,3,3]
	pcmpeqd	%xmm6, %xmm2
	pand	%xmm1, %xmm2
	movdqa	%xmm3, %xmm0
	pxor	%xmm6, %xmm0
	pshufd	$160, %xmm0, %xmm1              # xmm1 = xmm0[0,0,2,2]
	movdqa	%xmm15, %xmm3
	pcmpgtd	%xmm1, %xmm3
	pshufd	$245, %xmm0, %xmm0              # xmm0 = xmm0[1,1,3,3]
	pcmpeqd	%xmm6, %xmm0
	pand	%xmm3, %xmm0
	packssdw	%xmm0, %xmm2
	movdqa	%xmm13, %xmm0
	pxor	%xmm6, %xmm0
	pshufd	$160, %xmm0, %xmm1              # xmm1 = xmm0[0,0,2,2]
	movdqa	%xmm15, %xmm3
	pcmpgtd	%xmm1, %xmm3
	pshufd	$245, %xmm0, %xmm0              # xmm0 = xmm0[1,1,3,3]
	pcmpeqd	%xmm6, %xmm0
	pand	%xmm3, %xmm0
	movdqa	%xmm12, %xmm1
	pxor	%xmm6, %xmm1
	pshufd	$160, %xmm1, %xmm3              # xmm3 = xmm1[0,0,2,2]
	movdqa	%xmm15, %xmm4
	pcmpgtd	%xmm3, %xmm4
	pshufd	$245, %xmm1, %xmm1              # xmm1 = xmm1[1,1,3,3]
	pcmpeqd	%xmm6, %xmm1
	pand	%xmm4, %xmm1
	packssdw	%xmm1, %xmm0
	packssdw	%xmm0, %xmm2
	movdqa	%xmm11, %xmm0
	pxor	%xmm6, %xmm0
	pshufd	$160, %xmm0, %xmm1              # xmm1 = xmm0[0,0,2,2]
	movdqa	%xmm15, %xmm3
	pcmpgtd	%xmm1, %xmm3
	pshufd	$245, %xmm0, %xmm0              # xmm0 = xmm0[1,1,3,3]
	pcmpeqd	%xmm6, %xmm0
	pand	%xmm3, %xmm0
	movdqa	%xmm10, %xmm1
	pxor	%xmm6, %xmm1
	pshufd	$160, %xmm1, %xmm3              # xmm3 = xmm1[0,0,2,2]
	movdqa	%xmm15, %xmm4
	pcmpgtd	%xmm3, %xmm4
	pshufd	$245, %xmm1, %xmm1              # xmm1 = xmm1[1,1,3,3]
	pcmpeqd	%xmm6, %xmm1
	pand	%xmm4, %xmm1
	packssdw	%xmm1, %xmm0
	movdqa	%xmm9, %xmm1
	pxor	%xmm6, %xmm1
	pshufd	$160, %xmm1, %xmm3              # xmm3 = xmm1[0,0,2,2]
	movdqa	%xmm15, %xmm4
	pcmpgtd	%xmm3, %xmm4
	pshufd	$245, %xmm1, %xmm1              # xmm1 = xmm1[1,1,3,3]
	pcmpeqd	%xmm6, %xmm1
	pand	%xmm4, %xmm1
	movdqa	%xmm8, %xmm3
	pxor	%xmm6, %xmm3
	pshufd	$160, %xmm3, %xmm4              # xmm4 = xmm3[0,0,2,2]
	movdqa	%xmm13, %xmm15
	movdqa	%xmm12, %xmm14
	movdqa	%xmm11, %xmm13
	movdqa	%xmm10, %xmm12
	movdqa	%xmm9, %xmm11
	movdqa	%xmm8, %xmm10
	movdqa	%xmm7, %xmm9
	movdqa	%xmm5, %xmm8
	movdqa	.LCPI2_13(%rip), %xmm5          # xmm5 = [2147483776,2147483776,2147483776,2147483776]
	pcmpgtd	%xmm4, %xmm5
	pshufd	$245, %xmm3, %xmm3              # xmm3 = xmm3[1,1,3,3]
	pcmpeqd	%xmm6, %xmm3
	pand	%xmm5, %xmm3
	movdqa	16(%rsp), %xmm6                 # 16-byte Reload
	movdqa	%xmm8, %xmm5
	movdqa	%xmm10, %xmm8
	movdqa	%xmm11, %xmm9
	movdqa	%xmm12, %xmm10
	movdqa	%xmm13, %xmm11
	movdqa	%xmm14, %xmm12
	movdqa	%xmm15, %xmm13
	packssdw	%xmm3, %xmm1
	packssdw	%xmm1, %xmm0
	packsswb	%xmm0, %xmm2
	por	96(%rsp), %xmm2                 # 16-byte Folded Reload
	psllw	$7, %xmm2
	pand	.LCPI2_14(%rip), %xmm2
	pxor	%xmm0, %xmm0
	pcmpgtb	%xmm2, %xmm0
	movdqa	80(%rsp), %xmm4                 # 16-byte Reload
	movdqa	%xmm4, %xmm1
	paddd	%xmm6, %xmm1
	movdqa	%xmm4, %xmm2
	paddd	%xmm5, %xmm2
	movdqa	%xmm4, %xmm3
	paddd	%xmm7, %xmm3
	movdqa	.LCPI2_15(%rip), %xmm14         # xmm14 = [255,0,0,0,255,0,0,0,255,0,0,0,255,0,0,0]
	pand	%xmm14, %xmm3
	pand	%xmm14, %xmm2
	packuswb	%xmm2, %xmm3
	movdqa	%xmm4, %xmm2
	movdqa	48(%rsp), %xmm4                 # 16-byte Reload
	paddd	%xmm4, %xmm2
	pand	%xmm14, %xmm2
	pand	%xmm14, %xmm1
	packuswb	%xmm1, %xmm2
	packuswb	%xmm2, %xmm3
	pand	%xmm0, %xmm3
	movdqa	(%rsp), %xmm0                   # 16-byte Reload
	movdqu	%xmm3, (%r12,%rcx)
	movdqa	32(%rsp), %xmm3                 # 16-byte Reload
	addq	$16, %rcx
	movdqa	.LCPI2_16(%rip), %xmm1          # xmm1 = [16,16]
	paddq	%xmm1, %xmm0
	paddq	%xmm1, %xmm3
	paddq	%xmm1, %xmm13
	paddq	%xmm1, %xmm12
	paddq	%xmm1, %xmm11
	paddq	%xmm1, %xmm10
	paddq	%xmm1, %xmm9
	paddq	%xmm1, %xmm8
	movdqa	.LCPI2_17(%rip), %xmm1          # xmm1 = [16,16,16,16]
	paddd	%xmm1, %xmm7
	paddd	%xmm1, %xmm5
	paddd	%xmm1, %xmm4
	paddd	%xmm1, %xmm6
	movdqa	%xmm6, 16(%rsp)                 # 16-byte Spill
	cmpq	%rcx, %rax
	jne	.LBB2_14
# %bb.15:
	cmpq	%rdx, %rax
	movdqa	64(%rsp), %xmm7                 # 16-byte Reload
	je	.LBB2_22
# %bb.16:
	testb	$8, %dl
	jne	.LBB2_17
.LBB2_20:
	movl	%ebx, %ecx
	.p2align	4, 0x90
.LBB2_21:                               # =>This Inner Loop Header: Depth=1
	leal	(%rcx,%rax), %edx
	testb	$1, %bl
	movl	$0, %esi
	cmovel	%edx, %esi
	cmpq	$128, %rax
	cmovbl	%edx, %esi
	movq	%r13, %rdx
	movb	%sil, (%r12,%rax)
	incq	%rax
	cmpq	%rax, %r13
	jne	.LBB2_21
.LBB2_22:
	movq	%r15, 48(%rsp)                  # 8-byte Spill
	movq	%rbx, (%rsp)                    # 8-byte Spill
	movl	%edx, %r15d
	shrl	$14, %r15d
	incq	%r15
	movl	%edx, %r13d
	andl	$3, %r13d
	andl	$2147483644, %edx               # imm = 0x7FFFFFFC
	movq	%rdx, 32(%rsp)                  # 8-byte Spill
	xorl	%eax, %eax
	leaq	ranges(%rip), %rbx
	xorl	%ebp, %ebp
	.p2align	4, 0x90
.LBB2_23:                               # =>This Loop Header: Depth=1
                                        #     Child Loop BB2_26 Depth 2
                                        #     Child Loop BB2_29 Depth 2
                                        #     Child Loop BB2_32 Depth 2
                                        #     Child Loop BB2_40 Depth 2
                                        #     Child Loop BB2_42 Depth 2
                                        #     Child Loop BB2_45 Depth 2
	movq	%rax, 16(%rsp)                  # 8-byte Spill
	movl	$2048, %edx                     # imm = 0x800
	leaq	112(%rsp), %rdi
	xorl	%esi, %esi
	callq	memset@PLT
	testl	%r14d, %r14d
	je	.LBB2_39
# %bb.24:                               #   in Loop: Header=BB2_23 Depth=1
	xorl	%eax, %eax
	cmpl	$4, %r14d
	jb	.LBB2_27
# %bb.25:                               #   in Loop: Header=BB2_23 Depth=1
	movq	32(%rsp), %rdx                  # 8-byte Reload
	.p2align	4, 0x90
.LBB2_26:                               #   Parent Loop BB2_23 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movzbl	(%r12,%rax), %ecx
	incq	112(%rsp,%rcx,8)
	movzbl	1(%r12,%rax), %ecx
	incq	112(%rsp,%rcx,8)
	movzbl	2(%r12,%rax), %ecx
	incq	112(%rsp,%rcx,8)
	movzbl	3(%r12,%rax), %ecx
	incq	112(%rsp,%rcx,8)
	addq	$4, %rax
	cmpq	%rax, %rdx
	jne	.LBB2_26
.LBB2_27:                               #   in Loop: Header=BB2_23 Depth=1
	testq	%r13, %r13
	je	.LBB2_30
# %bb.28:                               #   in Loop: Header=BB2_23 Depth=1
	addq	%r12, %rax
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB2_29:                               #   Parent Loop BB2_23 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movzbl	(%rax,%rcx), %edx
	incq	112(%rsp,%rdx,8)
	incq	%rcx
	cmpq	%rcx, %r13
	jne	.LBB2_29
.LBB2_30:                               #   in Loop: Header=BB2_23 Depth=1
	cmpl	$16384, %r14d                   # imm = 0x4000
	jb	.LBB2_39
# %bb.31:                               #   in Loop: Header=BB2_23 Depth=1
	xorl	%esi, %esi
	jmp	.LBB2_32
	.p2align	4, 0x90
.LBB2_33:                               #   in Loop: Header=BB2_32 Depth=2
	movq	%rcx, %rax
	shrq	$32, %rax
	je	.LBB2_34
# %bb.35:                               #   in Loop: Header=BB2_32 Depth=2
	movq	%rcx, %rax
	xorl	%edx, %edx
	divq	%r15
.LBB2_37:                               #   in Loop: Header=BB2_32 Depth=2
	movq	%rax, 112(%rsp,%rsi,8)
.LBB2_38:                               #   in Loop: Header=BB2_32 Depth=2
	incq	%rsi
	cmpq	$256, %rsi                      # imm = 0x100
	je	.LBB2_39
.LBB2_32:                               #   Parent Loop BB2_23 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movq	112(%rsp,%rsi,8), %rcx
	cmpq	%r15, %rcx
	ja	.LBB2_33
# %bb.36:                               #   in Loop: Header=BB2_32 Depth=2
	movl	$1, %eax
	testq	%rcx, %rcx
	jne	.LBB2_37
	jmp	.LBB2_38
.LBB2_34:                               #   in Loop: Header=BB2_32 Depth=2
	movl	%ecx, %eax
	xorl	%edx, %edx
	divl	%r15d
                                        # kill: def $eax killed $eax def $rax
	jmp	.LBB2_37
	.p2align	4, 0x90
.LBB2_39:                               #   in Loop: Header=BB2_23 Depth=1
	pxor	%xmm0, %xmm0
	xorl	%eax, %eax
	pxor	%xmm1, %xmm1
	.p2align	4, 0x90
.LBB2_40:                               #   Parent Loop BB2_23 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	pshufd	$232, 112(%rsp,%rax,8), %xmm2   # xmm2 = mem[0,2,2,3]
	pshuflw	$232, %xmm2, %xmm2              # xmm2 = xmm2[0,2,2,3,4,5,6,7]
	pshufd	$232, 128(%rsp,%rax,8), %xmm3   # xmm3 = mem[0,2,2,3]
	pshufd	$232, 144(%rsp,%rax,8), %xmm4   # xmm4 = mem[0,2,2,3]
	pshuflw	$232, %xmm3, %xmm3              # xmm3 = xmm3[0,2,2,3,4,5,6,7]
	pshuflw	$232, %xmm4, %xmm4              # xmm4 = xmm4[0,2,2,3,4,5,6,7]
	pshufd	$232, 160(%rsp,%rax,8), %xmm5   # xmm5 = mem[0,2,2,3]
	pshuflw	$232, %xmm5, %xmm5              # xmm5 = xmm5[0,2,2,3,4,5,6,7]
	paddw	%xmm2, %xmm0
	paddw	%xmm4, %xmm0
	punpckldq	%xmm5, %xmm4            # xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
	punpckldq	%xmm3, %xmm2            # xmm2 = xmm2[0],xmm3[0],xmm2[1],xmm3[1]
	punpcklqdq	%xmm4, %xmm2            # xmm2 = xmm2[0],xmm4[0]
	movdqu	%xmm2, 2(%rbx,%rax,2)
	paddw	%xmm3, %xmm1
	paddw	%xmm5, %xmm1
	addq	$8, %rax
	cmpq	$256, %rax                      # imm = 0x100
	jne	.LBB2_40
# %bb.41:                               #   in Loop: Header=BB2_23 Depth=1
	movw	$0, ranges(%rip)
	movw	$1, ranges+514(%rip)
	xorl	%eax, %eax
	xorl	%ecx, %ecx
	.p2align	4, 0x90
.LBB2_42:                               #   Parent Loop BB2_23 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	addw	2(%rbx,%rax,2), %cx
	movw	%cx, 2(%rbx,%rax,2)
	cmpq	$256, %rax                      # imm = 0x100
	je	.LBB2_44
# %bb.43:                               #   in Loop: Header=BB2_42 Depth=2
	addw	4(%rbx,%rax,2), %cx
	movw	%cx, 4(%rbx,%rax,2)
	addw	6(%rbx,%rax,2), %cx
	movw	%cx, 6(%rbx,%rax,2)
	addw	8(%rbx,%rax,2), %cx
	movw	%cx, 8(%rbx,%rax,2)
	addq	$4, %rax
	jmp	.LBB2_42
	.p2align	4, 0x90
.LBB2_44:                               #   in Loop: Header=BB2_23 Depth=1
	movl	$2, %eax
	.p2align	4, 0x90
.LBB2_45:                               #   Parent Loop BB2_23 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movl	%ebp, %ecx
	shll	$5, %ecx
	addl	%ebp, %ecx
	movzwl	-4(%rbx,%rax,2), %edx
	addl	%ecx, %edx
	movzwl	-2(%rbx,%rax,2), %ecx
	addl	%edx, %ecx
	shll	$5, %edx
	addl	%edx, %ecx
	movzwl	(%rbx,%rax,2), %ebp
	addl	%ecx, %ebp
	shll	$5, %ecx
	addl	%ecx, %ebp
	addq	$3, %rax
	cmpq	$260, %rax                      # imm = 0x104
	jne	.LBB2_45
# %bb.46:                               #   in Loop: Header=BB2_23 Depth=1
	movq	(%rsp), %rax                    # 8-byte Reload
	imull	$1664525, %eax, %eax            # imm = 0x19660D
	addl	$1013904223, %eax               # imm = 0x3C6EF35F
	movq	%rax, (%rsp)                    # 8-byte Spill
	movb	%al, (%r12)
	movq	16(%rsp), %rax                  # 8-byte Reload
	incq	%rax
	cmpq	48(%rsp), %rax                  # 8-byte Folded Reload
	jne	.LBB2_23
# %bb.47:
	paddw	%xmm0, %xmm1
	movdqa	%xmm1, %xmm0
	psrld	$16, %xmm0
	paddw	%xmm1, %xmm0
	movd	%xmm0, %eax
	incl	%eax
	movw	%ax, cumulativeProb(%rip)
	leaq	.L.str(%rip), %rdi
	movl	%ebp, %esi
	xorl	%eax, %eax
	callq	printf@PLT
	movq	%r12, %rdi
	callq	free@PLT
	xorl	%eax, %eax
.LBB2_48:
	addq	$2168, %rsp                     # imm = 0x878
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
.Lfunc_end2:
	.size	main, .Lfunc_end2-main
	.cfi_endproc
                                        # -- End function
	.type	ranges,@object                  # @ranges
	.bss
	.globl	ranges
	.p2align	4, 0x0
ranges:
	.zero	516
	.size	ranges, 516

	.type	cumulativeProb,@object          # @cumulativeProb
	.globl	cumulativeProb
	.p2align	1, 0x0
cumulativeProb:
	.short	0                               # 0x0
	.size	cumulativeProb, 2

	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"%u\n"
	.size	.L.str, 4

	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
