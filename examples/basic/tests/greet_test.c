#include "greet.h"

#include <stdio.h>

int main(void) {
    /* greet() writes to stdout and returns nothing, so the test asserts only
       that calling it is well-formed and the program reaches the end. */
    greet("test");
    printf("ok\n");
    return 0;
}
