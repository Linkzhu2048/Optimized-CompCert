	.text
	.file	"perlin_init.c"
	.globl	init                            # -- Begin function init
	.p2align	4, 0x90
	.type	init,@function
init:                                   # @init
	.cfi_startproc
# %bb.0:
	pushq	%rbx
	.cfi_def_cfa_offset 16
	.cfi_offset %rbx, -16
	leaq	p(%rip), %rdi
	leaq	permutation(%rip), %rbx
	movl	$1024, %edx                     # imm = 0x400
	movq	%rbx, %rsi
	callq	memcpy@PLT
	leaq	p+1024(%rip), %rdi
	movl	$1024, %edx                     # imm = 0x400
	movq	%rbx, %rsi
	popq	%rbx
	.cfi_def_cfa_offset 8
	jmp	memcpy@PLT                      # TAILCALL
.Lfunc_end0:
	.size	init, .Lfunc_end0-init
	.cfi_endproc
                                        # -- End function
	.globl	main                            # -- Begin function main
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
	subq	$24, %rsp
	.cfi_def_cfa_offset 80
	.cfi_offset %rbx, -56
	.cfi_offset %r12, -48
	.cfi_offset %r13, -40
	.cfi_offset %r14, -32
	.cfi_offset %r15, -24
	.cfi_offset %rbp, -16
	movl	$2048, %ebx                     # imm = 0x800
	movl	$65536, %r15d                   # imm = 0x10000
	movl	$16, %r12d
	cmpl	$2, %edi
	jl	.LBB1_4
# %bb.1:
	movq	%rsi, %r14
	movl	%edi, %ebp
	movq	8(%rsi), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtol@PLT
	movq	%rax, %r15
	cmpl	$2, %ebp
	je	.LBB1_4
# %bb.2:
	movq	16(%r14), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %r12
	cmpl	$4, %ebp
	jb	.LBB1_4
# %bb.3:
	movq	24(%r14), %rdi
	xorl	%esi, %esi
	movl	$10, %edx
	callq	strtoul@PLT
	movq	%rax, %rbx
.LBB1_4:
	movl	$2, %ebp
	cmpl	$1048576, %r15d                 # imm = 0x100000
	ja	.LBB1_13
# %bb.5:
	testq	%r12, %r12
	je	.LBB1_13
# %bb.6:
	cmpq	$1000000, %r12                  # imm = 0xF4240
	ja	.LBB1_13
# %bb.7:
	movq	%r12, (%rsp)                    # 8-byte Spill
	xorl	%r12d, %r12d
	leaq	permutation(%rip), %r13
	leaq	p(%rip), %rbp
	leaq	p+1024(%rip), %r14
	xorl	%eax, %eax
	movq	%r15, 8(%rsp)                   # 8-byte Spill
	jmp	.LBB1_8
	.p2align	4, 0x90
.LBB1_11:                               #   in Loop: Header=BB1_8 Depth=1
	movq	16(%rsp), %rax                  # 8-byte Reload
	incq	%rax
	cmpq	(%rsp), %rax                    # 8-byte Folded Reload
	movq	8(%rsp), %r15                   # 8-byte Reload
	je	.LBB1_12
.LBB1_8:                                # =>This Loop Header: Depth=1
                                        #     Child Loop BB1_10 Depth 2
	movq	%rax, 16(%rsp)                  # 8-byte Spill
	testl	%r15d, %r15d
	je	.LBB1_11
# %bb.9:                                #   in Loop: Header=BB1_8 Depth=1
                                        # kill: def $r15d killed $r15d killed $r15
	.p2align	4, 0x90
.LBB1_10:                               #   Parent Loop BB1_8 Depth=1
                                        # =>  This Inner Loop Header: Depth=2
	movzbl	%bl, %eax
	movl	(%r13,%rax,4), %ecx
	movzbl	%bh, %edx
	movl	(%r13,%rdx,4), %esi
	movl	%esi, (%r13,%rax,4)
	movl	%ecx, (%r13,%rdx,4)
	movl	$1024, %edx                     # imm = 0x400
	movq	%rbp, %rdi
	movq	%r13, %rsi
	callq	memcpy@PLT
	movl	$1024, %edx                     # imm = 0x400
	movq	%r14, %rdi
	movq	%r13, %rsi
	callq	memcpy@PLT
	imull	$1664525, %ebx, %eax            # imm = 0x19660D
	andl	$511, %ebx                      # imm = 0x1FF
	addl	(%rbp,%rbx,4), %r12d
	leal	(%rax,%r12), %ebx
	addl	$1013904223, %ebx               # imm = 0x3C6EF35F
	decl	%r15d
	jne	.LBB1_10
	jmp	.LBB1_11
.LBB1_12:
	leaq	.L.str(%rip), %rdi
	xorl	%ebp, %ebp
	movl	%r12d, %esi
	xorl	%eax, %eax
	callq	printf@PLT
.LBB1_13:
	movl	%ebp, %eax
	addq	$24, %rsp
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
	.type	permutation,@object             # @permutation
	.data
	.p2align	4, 0x0
permutation:
	.long	151                             # 0x97
	.long	160                             # 0xa0
	.long	137                             # 0x89
	.long	91                              # 0x5b
	.long	90                              # 0x5a
	.long	15                              # 0xf
	.long	131                             # 0x83
	.long	13                              # 0xd
	.long	201                             # 0xc9
	.long	95                              # 0x5f
	.long	96                              # 0x60
	.long	53                              # 0x35
	.long	194                             # 0xc2
	.long	233                             # 0xe9
	.long	7                               # 0x7
	.long	225                             # 0xe1
	.long	140                             # 0x8c
	.long	36                              # 0x24
	.long	103                             # 0x67
	.long	30                              # 0x1e
	.long	69                              # 0x45
	.long	142                             # 0x8e
	.long	8                               # 0x8
	.long	99                              # 0x63
	.long	37                              # 0x25
	.long	240                             # 0xf0
	.long	21                              # 0x15
	.long	10                              # 0xa
	.long	23                              # 0x17
	.long	190                             # 0xbe
	.long	6                               # 0x6
	.long	148                             # 0x94
	.long	247                             # 0xf7
	.long	120                             # 0x78
	.long	234                             # 0xea
	.long	75                              # 0x4b
	.long	0                               # 0x0
	.long	26                              # 0x1a
	.long	197                             # 0xc5
	.long	62                              # 0x3e
	.long	94                              # 0x5e
	.long	252                             # 0xfc
	.long	219                             # 0xdb
	.long	203                             # 0xcb
	.long	117                             # 0x75
	.long	35                              # 0x23
	.long	11                              # 0xb
	.long	32                              # 0x20
	.long	57                              # 0x39
	.long	177                             # 0xb1
	.long	33                              # 0x21
	.long	88                              # 0x58
	.long	237                             # 0xed
	.long	149                             # 0x95
	.long	56                              # 0x38
	.long	87                              # 0x57
	.long	174                             # 0xae
	.long	20                              # 0x14
	.long	125                             # 0x7d
	.long	136                             # 0x88
	.long	171                             # 0xab
	.long	168                             # 0xa8
	.long	68                              # 0x44
	.long	175                             # 0xaf
	.long	74                              # 0x4a
	.long	165                             # 0xa5
	.long	71                              # 0x47
	.long	134                             # 0x86
	.long	139                             # 0x8b
	.long	48                              # 0x30
	.long	27                              # 0x1b
	.long	166                             # 0xa6
	.long	77                              # 0x4d
	.long	146                             # 0x92
	.long	158                             # 0x9e
	.long	231                             # 0xe7
	.long	83                              # 0x53
	.long	111                             # 0x6f
	.long	229                             # 0xe5
	.long	122                             # 0x7a
	.long	60                              # 0x3c
	.long	211                             # 0xd3
	.long	133                             # 0x85
	.long	230                             # 0xe6
	.long	220                             # 0xdc
	.long	105                             # 0x69
	.long	92                              # 0x5c
	.long	41                              # 0x29
	.long	55                              # 0x37
	.long	46                              # 0x2e
	.long	245                             # 0xf5
	.long	40                              # 0x28
	.long	244                             # 0xf4
	.long	102                             # 0x66
	.long	143                             # 0x8f
	.long	54                              # 0x36
	.long	65                              # 0x41
	.long	25                              # 0x19
	.long	63                              # 0x3f
	.long	161                             # 0xa1
	.long	1                               # 0x1
	.long	216                             # 0xd8
	.long	80                              # 0x50
	.long	73                              # 0x49
	.long	209                             # 0xd1
	.long	76                              # 0x4c
	.long	132                             # 0x84
	.long	187                             # 0xbb
	.long	208                             # 0xd0
	.long	89                              # 0x59
	.long	18                              # 0x12
	.long	169                             # 0xa9
	.long	200                             # 0xc8
	.long	196                             # 0xc4
	.long	135                             # 0x87
	.long	130                             # 0x82
	.long	116                             # 0x74
	.long	188                             # 0xbc
	.long	159                             # 0x9f
	.long	86                              # 0x56
	.long	164                             # 0xa4
	.long	100                             # 0x64
	.long	109                             # 0x6d
	.long	198                             # 0xc6
	.long	173                             # 0xad
	.long	186                             # 0xba
	.long	3                               # 0x3
	.long	64                              # 0x40
	.long	52                              # 0x34
	.long	217                             # 0xd9
	.long	226                             # 0xe2
	.long	250                             # 0xfa
	.long	124                             # 0x7c
	.long	123                             # 0x7b
	.long	5                               # 0x5
	.long	202                             # 0xca
	.long	38                              # 0x26
	.long	147                             # 0x93
	.long	118                             # 0x76
	.long	126                             # 0x7e
	.long	255                             # 0xff
	.long	82                              # 0x52
	.long	85                              # 0x55
	.long	212                             # 0xd4
	.long	207                             # 0xcf
	.long	206                             # 0xce
	.long	59                              # 0x3b
	.long	227                             # 0xe3
	.long	47                              # 0x2f
	.long	16                              # 0x10
	.long	58                              # 0x3a
	.long	17                              # 0x11
	.long	182                             # 0xb6
	.long	189                             # 0xbd
	.long	28                              # 0x1c
	.long	42                              # 0x2a
	.long	223                             # 0xdf
	.long	183                             # 0xb7
	.long	170                             # 0xaa
	.long	213                             # 0xd5
	.long	119                             # 0x77
	.long	248                             # 0xf8
	.long	152                             # 0x98
	.long	2                               # 0x2
	.long	44                              # 0x2c
	.long	154                             # 0x9a
	.long	163                             # 0xa3
	.long	70                              # 0x46
	.long	221                             # 0xdd
	.long	153                             # 0x99
	.long	101                             # 0x65
	.long	155                             # 0x9b
	.long	167                             # 0xa7
	.long	43                              # 0x2b
	.long	172                             # 0xac
	.long	9                               # 0x9
	.long	129                             # 0x81
	.long	22                              # 0x16
	.long	39                              # 0x27
	.long	253                             # 0xfd
	.long	19                              # 0x13
	.long	98                              # 0x62
	.long	108                             # 0x6c
	.long	110                             # 0x6e
	.long	79                              # 0x4f
	.long	113                             # 0x71
	.long	224                             # 0xe0
	.long	232                             # 0xe8
	.long	178                             # 0xb2
	.long	185                             # 0xb9
	.long	112                             # 0x70
	.long	104                             # 0x68
	.long	218                             # 0xda
	.long	246                             # 0xf6
	.long	97                              # 0x61
	.long	228                             # 0xe4
	.long	251                             # 0xfb
	.long	34                              # 0x22
	.long	242                             # 0xf2
	.long	193                             # 0xc1
	.long	238                             # 0xee
	.long	210                             # 0xd2
	.long	144                             # 0x90
	.long	12                              # 0xc
	.long	191                             # 0xbf
	.long	179                             # 0xb3
	.long	162                             # 0xa2
	.long	241                             # 0xf1
	.long	81                              # 0x51
	.long	51                              # 0x33
	.long	145                             # 0x91
	.long	235                             # 0xeb
	.long	249                             # 0xf9
	.long	14                              # 0xe
	.long	239                             # 0xef
	.long	107                             # 0x6b
	.long	49                              # 0x31
	.long	192                             # 0xc0
	.long	214                             # 0xd6
	.long	31                              # 0x1f
	.long	181                             # 0xb5
	.long	199                             # 0xc7
	.long	106                             # 0x6a
	.long	157                             # 0x9d
	.long	184                             # 0xb8
	.long	84                              # 0x54
	.long	204                             # 0xcc
	.long	176                             # 0xb0
	.long	115                             # 0x73
	.long	121                             # 0x79
	.long	50                              # 0x32
	.long	45                              # 0x2d
	.long	127                             # 0x7f
	.long	4                               # 0x4
	.long	150                             # 0x96
	.long	254                             # 0xfe
	.long	138                             # 0x8a
	.long	236                             # 0xec
	.long	205                             # 0xcd
	.long	93                              # 0x5d
	.long	222                             # 0xde
	.long	114                             # 0x72
	.long	67                              # 0x43
	.long	29                              # 0x1d
	.long	24                              # 0x18
	.long	72                              # 0x48
	.long	243                             # 0xf3
	.long	141                             # 0x8d
	.long	128                             # 0x80
	.long	195                             # 0xc3
	.long	78                              # 0x4e
	.long	66                              # 0x42
	.long	215                             # 0xd7
	.long	61                              # 0x3d
	.long	156                             # 0x9c
	.long	180                             # 0xb4
	.size	permutation, 1024

	.type	p,@object                       # @p
	.local	p
	.comm	p,2048,16
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"%u\n"
	.size	.L.str, 4

	.ident	"Ubuntu clang version 18.1.3 (1ubuntu1)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
