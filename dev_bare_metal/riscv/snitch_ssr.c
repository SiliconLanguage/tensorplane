#include "snrt.h"

void stream_dot_product(double *a, double *b, uint32_t n) {
    snrt_ssr_loop_1d(SNRT_SSR_DM0, n, sizeof(double));
    snrt_ssr_repeat(SNRT_SSR_DM0, 1);
    snrt_ssr_read(SNRT_SSR_DM0, SNRT_SSR_DIM_1D, a);
    snrt_ssr_enable();

    asm volatile (
        "loop_start: \n"
        "fmadd.d ft2, ft0, ft1, ft2 \n"
        "addi %0, %0, -1 \n"
        "bnez %0, loop_start"
        : : "r"(n) : "ft0", "ft1", "ft2"
    );
}
