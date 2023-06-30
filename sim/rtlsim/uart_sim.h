#pragma once
#include <cstdint>
#include <array>
#include <cstring>
#include <tuple>
#include <iostream>
#include <limits>

#define UART_ADDR 0xFF000000
#define DATA_BITS   8
#define UART_RX_ADDR     (UART_ADDR + 0x00)
#define UART_TX_ADDR     (UART_ADDR + 0x04)
#define UART_STAT_ADDR   (UART_ADDR + 0x08)
#define UART_CTRL_ADDR   (UART_ADDR + 0x0C)

typedef struct __attribute__((packed)) {
    unsigned reset_rx_fifo : 1;
    unsigned reset_tx_fifo : 1;
    unsigned reserved_1 : 2;
    unsigned enable_intr : 1;
    unsigned reserved_2 : 27;
} uart_ctrl_t;

typedef struct __attribute__((packed)) {
    unsigned rx_fifo_valid : 1;
    unsigned rx_fifo_full : 1;
    unsigned tx_fifo_empty : 1;
    unsigned tx_fifo_full : 1;
    unsigned intr_enabled : 1;
    unsigned overrun_error : 1;
    unsigned frame_error : 1;
    unsigned parity_error : 1;
    unsigned reserved : 24;
} uart_status_t;

typedef struct __attribute__((packed)) {
    char data;
    unsigned reserved : 24;
} uart_fifo_t;

bool intr_enabled = false;

uint32_t get_reg_from(uint8_t* data, std::tuple<bool, uint32_t, uint32_t> extracted){
    auto size          = std::get<1>(extracted);
    auto ofs           = std::get<2>(extracted);
    uint32_t val = (*(uint32_t*)(&data[ofs & (~0b11)]));
    uint32_t bits = (size == 4) ? 0xFFFFFFFF : ((1<<(size*8))-1);
    uint32_t mask = bits << (ofs & 0b11);
    return  val & mask;
}

template<unsigned MEM_BLOCK_SIZE, typename T>
void set_reg_to(uint8_t* data, std::tuple<bool, uint32_t, uint32_t> extracted, T reg){
    auto size = std::get<1>(extracted);
    auto ofs           = std::get<2>(extracted);
    memset(data, 0, MEM_BLOCK_SIZE);
    memcpy(data + ofs, ((uint8_t*) &reg) + (ofs & 0b11), size);
}

template<unsigned N, unsigned MEM_BLOCK_SIZE>
std::array<std::tuple<bool, uint32_t, uint32_t>,N> regs_access(uint32_t base_addr, uint32_t access_size, std::array<uint32_t,N> regs, uint8_t* data) {
    uint32_t access_addr = base_addr % MEM_BLOCK_SIZE;
    uint32_t access_reg_min = base_addr & (~0b11);
    uint32_t access_reg_max = (base_addr + access_size);
    std::array<std::tuple<bool, uint32_t, uint32_t>,N> out;
    for(unsigned int req = 0; req < N; req++){
        bool hit = (regs[req] >= access_reg_min && regs[req] < access_reg_max);
        uint32_t size = std::max(access_size, 0x4U);
        out[req] = std::make_tuple(hit, size, access_addr);
    }
    return out;
}

template<unsigned MEM_BLOCK_SIZE>
bool process_uart_write(uint32_t base_addr, uint32_t access_size, uint8_t* data){
    bool bypass_ram_access = false;
    auto regs_w = regs_access<4, MEM_BLOCK_SIZE>(base_addr, access_size, {UART_RX_ADDR, UART_TX_ADDR, UART_CTRL_ADDR, UART_STAT_ADDR}, data);
    if(std::get<0>(regs_w[0])) {
        std::cout << "Unsupported write to UART RX register" << std::endl;
        bypass_ram_access = true;
    }
    if(std::get<0>(regs_w[1])){
        uint32_t reg_data = get_reg_from(data, regs_w[1]);
//            std::cout << "UART TX : " << reg_data << " " << std::get<1>(regs_w[2]) << " " << std::get<2>(regs_w[2]) << std::endl;
//            for(int c = 0; c < MEM_BLOCK_SIZE; c++)
//                std::cout << std::hex <<  int(data[c]) << " ";
//            std::cout << std::endl;
        uart_fifo_t* uart_tx = (uart_fifo_t*) &reg_data;
        std::cout << uart_tx->data;
        std::cout.flush();
        bypass_ram_access = true;
    }
    if(std::get<0>(regs_w[2])) {
        uint32_t reg_data = get_reg_from(data, regs_w[2]);
        uart_ctrl_t* uart_ctrl_data = (uart_ctrl_t*) &reg_data;
        if(uart_ctrl_data->enable_intr)   intr_enabled=true;
//            if(uart_ctrl_data->reset_tx_fifo) {
//                std::cout << "UART TX flush" << std::endl;
//                std::cout.flush();
//            }
//            if(uart_ctrl_data->reset_rx_fifo) {
//                std::cout << "UART RX flush" << std::endl;
//                std::cin.clear();
//                std::cin.ignore(std::numeric_limits<std::streamsize>::max());
//            }
//            if(uart_ctrl_data->enable_intr)   std::cout << "UART enable intr" << std::endl;
        bypass_ram_access = true;
    }
    if(std::get<0>(regs_w[3])) {
        std::cout << "Unsupported write to UART STAT register: " << std::hex << base_addr << " +: " << access_size
                  << std::endl;
        bypass_ram_access = true;
    }
    return bypass_ram_access;
}

template<unsigned MEM_BLOCK_SIZE>
bool process_uart_read(uint32_t base_addr, uint32_t access_size, uint8_t* data){
    bool bypass_ram_access = false;
    auto regs_r = regs_access<4, MEM_BLOCK_SIZE>(base_addr, access_size, {UART_RX_ADDR, UART_TX_ADDR, UART_CTRL_ADDR, UART_STAT_ADDR}, nullptr);
    if(std::get<0>(regs_r[0])){
        //std::cout << "UART RX read" << std::endl;
        uart_fifo_t uart_rx;
        uart_rx.data = (std::cin.rdbuf()->in_avail() != -1) ? std::cin.rdbuf()->sbumpc() : 0 ;
        set_reg_to<MEM_BLOCK_SIZE>(data, regs_r[0], uart_rx);
        bypass_ram_access = true;
    }
    if(std::get<0>(regs_r[1])) std::cout << "Unsupported read to UART TX register" << std::endl;
    if(std::get<0>(regs_r[2])){
        //std::cout << "UART CTRL READ" << std::endl;
        set_reg_to<MEM_BLOCK_SIZE>(data, regs_r[2], 0x00U);
        bypass_ram_access = true;
    }
    if(std::get<0>(regs_r[3])){
        //std::cout << "UART STAT READ" << std::endl;
        uart_status_t uart_stat;
        uart_stat.intr_enabled = intr_enabled;
        uart_stat.rx_fifo_valid = (std::cin.rdbuf()->in_avail() != -1);
        uart_stat.tx_fifo_full = 0;
        uart_stat.tx_fifo_empty = 1;
        //std::cout << uart_stat.tx_fifo_full << std::endl;
        set_reg_to<MEM_BLOCK_SIZE>(data, regs_r[3], uart_stat);
        bypass_ram_access = true;
    }
    return bypass_ram_access;
}
