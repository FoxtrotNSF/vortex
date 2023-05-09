#include <stdint.h>
#include "vx_uart.h"


void main() {

lab_1:
    while(! UART_STAT->rx_fifo_valid);
    if(UART_RX->data != 's') goto lab_1;
}