/* ObjectStublessClient3-32 stubs */
    .data
    .balign 8
    .globl fn_ptrs
fn_ptrs:
    .quad 0, 0, 0   /* [0],[1],[2] unused */
    .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  /* [3]-[12] */
    .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  /* [13]-[22] */
    .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0  /* [23]-[32] */

    .text

.macro STUB N
    .globl ObjectStublessClient\N
    .def ObjectStublessClient\N; .scl 2; .type 32; .endef
ObjectStublessClient\N:
    movq fn_ptrs + (\N * 8)(%rip), %rax
    testq %rax, %rax
    je .Lfail\N
    jmp *%rax
.Lfail\N:
    movl $0x80004001, %eax
    ret
.endm

STUB 3
STUB 4
STUB 5
STUB 6
STUB 7
STUB 8
STUB 9
STUB 10
STUB 11
STUB 12
STUB 13
STUB 14
STUB 15
STUB 16
STUB 17
STUB 18
STUB 19
STUB 20
STUB 21
STUB 22
STUB 23
STUB 24
STUB 25
STUB 26
STUB 27
STUB 28
STUB 29
STUB 30
STUB 31
STUB 32
