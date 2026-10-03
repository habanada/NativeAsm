.intel_syntax noprefix
.text
.global _start
_start:
vpaddd ymm8,ymm9,ymm10
vpshufb ymm15,ymm14,ymm13
vpermd ymm12,ymm11,ymm10
vpsllvd ymm9,ymm8,ymm15
vpmulld ymm13,ymm14,ymm15
vpmaxud ymm15,ymm8,ymm9
vpmovzxbw ymm12,xmm13
vpbroadcastd ymm14,DWORD PTR [r13+127]
vpaddd ymm0,ymm1,YMMWORD PTR [r13]
vpaddd ymm0,ymm1,YMMWORD PTR [rbp+0]
vpaddd ymm0,ymm1,YMMWORD PTR [rsp+128]
vpaddd ymm0,ymm1,YMMWORD PTR [r12-129]
vpmaskmovd ymm8,ymm9,YMMWORD PTR [r12+32]
vpmaskmovq YMMWORD PTR [r13+64],ymm10,ymm11
vpgatherdd ymm8,DWORD PTR [r12+ymm9*4+32],ymm10
vpgatherdq ymm11,QWORD PTR [r13+xmm12*8+64],ymm14
vpgatherqd xmm8,DWORD PTR [r12+xmm9*4+32],xmm10
vpgatherqq ymm11,QWORD PTR [r13+ymm12*8+64],ymm14
