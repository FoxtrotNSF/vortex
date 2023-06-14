from intelhex import IntelHex
from elftools.elf.elffile import ELFFile
import argparse
import sys

RUN_ADDR_OFS = 0x1000


def extract_elf(elf_object):
    hex_data = IntelHex()
    start, end = 0, 0
    # convert elf to raw binary data
    for s in elf_object.iter_segments():
        if s['p_type'] == 'PT_LOAD':
            hex_data.frombytes(s.data(), s['p_paddr'])
    symbol_tab = elf_object.get_section_by_name('.symtab')
    assert symbol_tab is not None, "No symbol table available"
    kernel_entry = symbol_tab.get_symbol_by_name('_kernel_entry')
    assert kernel_entry is not None, "No symbol \"_kernel_entry\" in the file"
    k_addr = kernel_entry[0]['st_value']
    kernel_starts = symbol_tab.get_symbol_by_name('kernel_start')
    if kernel_starts is not None:
        start = kernel_starts[0]['st_value']
    kernel_ends = symbol_tab.get_symbol_by_name('kernel_end')
    if kernel_ends is not None:
        end = kernel_ends[0]['st_value']
    bin_data = hex_data.tobinarray()
    addr = hex_data.minaddr()
    size = hex_data.maxaddr() + 1 - hex_data.minaddr()
    assert (size == len(bin_data)), "size mismatch"
    return addr, k_addr, start, end, bin_data


def send_bin(addr, bin_data):
    size = len(bin_data)
    sys.stdout.buffer.write(b'u')
    sys.stdout.buffer.write(size.to_bytes(4, 'little'))
    sys.stdout.buffer.write((addr + RUN_ADDR_OFS).to_bytes(4, 'little'))
    sys.stdout.buffer.write(bin_data)
    return size


def recv_bin(addr, size):
    sys.stdout.buffer.write(b'd')
    sys.stdout.buffer.write(size.to_bytes(4, 'little'))
    sys.stdout.buffer.write((addr + RUN_ADDR_OFS).to_bytes(4, 'little'))


def run_kernel(addr, start, end, dim, arg, is_kernel):
    sys.stdout.buffer.write(b'r')
    sys.stdout.buffer.write((addr + RUN_ADDR_OFS).to_bytes(4, 'little'))
    sys.stdout.buffer.write(is_kernel.to_bytes(1, 'little'))
    sys.stdout.buffer.write((start + RUN_ADDR_OFS).to_bytes(4, 'little'))
    sys.stdout.buffer.write((end + RUN_ADDR_OFS).to_bytes(4, 'little'))
    if is_kernel:
        sys.stdout.buffer.write(arg.to_bytes(4, 'little'))
        sys.stdout.buffer.write(dim[0].to_bytes(1, 'little'))
        sys.stdout.buffer.write(dim[1].to_bytes(1, 'little'))
        sys.stdout.buffer.write(dim[2].to_bytes(1, 'little'))
    else:
        sys.stdout.buffer.write(int(dim).to_bytes(1, 'little'))


def align(addr, size=4):
    if not (addr % size):
        return addr
    return ((addr // size) + 1) * size


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-f", "--file",
                        required=True,
                        help="""Input .ELF file to process""")

    parser.add_argument("-m", "--mode",
                        required=True,
                        help="""is this a task run or an openCL kernel""")

    parser.add_argument("-d", "--dim",
                        required=True,
                        help="""dimensions of the kernel to run""")

    parser.add_argument("-a", "--args",
                        action='append',
                        required=False,
                        help="""argument""")

    args = parser.parse_args()
    with ELFFile(open(args.file, 'rb')) as elf_file:
        mem_addr_k, addr_k, start_k, end_k, data_k = extract_elf(elf_file)
    pos_free = align(mem_addr_k + send_bin(mem_addr_k, data_k))
    args_addrs = []
    if args.args is not None :
        for arg in args.args:
            with open(arg, 'rb') as arg_file:
                arg_data = arg_file.read()
                arg_size = send_bin(pos_free, arg_data)
                args_addrs.append((pos_free, arg_size))
                pos_free = align(pos_free + arg_size)
    args_sz = send_bin(pos_free, b''.join(map(lambda x: x[0].to_bytes(4, 'little'), args_addrs)))
    is_kernel = args.mode == "kernel"
    run_kernel(addr_k, start_k, end_k, eval(args.dim), pos_free, is_kernel)
    for addrs, sz in args_addrs:
        recv_bin(addrs, sz)


