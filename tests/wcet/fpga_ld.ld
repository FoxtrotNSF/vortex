
MEMORY
{
   RAM (rwx)   : ORIGIN = 0x00A00000, LENGTH = (2048M - 10M)
}

__code_start = ORIGIN(RAM);
__stack_top = ORIGIN(RAM) + LENGTH(RAM);

INCLUDE vx_link32.ld