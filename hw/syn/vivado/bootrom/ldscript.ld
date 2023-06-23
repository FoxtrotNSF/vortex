
/* The bootrom needs to know the hardware memory layout
*/

MEMORY
{
   ROM (rxi)   : ORIGIN = 0x80000000, LENGTH = 64K
   RAM (rw!i)  : ORIGIN = 0x00000000, LENGTH = 10M
}

UART_MODULE_ADDR = 0xFF000000;

__code_start = ORIGIN(ROM);
__stack_top = ORIGIN(RAM) + LENGTH(RAM);

INCLUDE vx_link32.ld