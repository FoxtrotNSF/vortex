from intelhex import IntelHex
from elftools.elf.elffile import ELFFile
import argparse
import sys
from math import prod


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
    sys.stdout.buffer.write(addr.to_bytes(4, 'little'))
    sys.stdout.buffer.write(bin_data)
    return size


def recv_bin(addr, size):
    sys.stdout.buffer.write(b'd')
    sys.stdout.buffer.write(size.to_bytes(4, 'little'))
    sys.stdout.buffer.write(addr.to_bytes(4, 'little'))


def run_kernel(addr, start, end, dim, arg, is_opencl):
    sys.stdout.buffer.write(b'r')
    sys.stdout.buffer.write(addr.to_bytes(4, 'little'))
    sys.stdout.buffer.write(is_opencl.to_bytes(1, 'little'))
    sys.stdout.buffer.write(start.to_bytes(4, 'little'))
    sys.stdout.buffer.write(end.to_bytes(4, 'little'))
    if is_opencl:
        sys.stdout.buffer.write(arg.to_bytes(4, 'little'))
        sys.stdout.buffer.write(dim[0].to_bytes(1, 'little'))
        sys.stdout.buffer.write(dim[1].to_bytes(1, 'little'))
        sys.stdout.buffer.write(dim[2].to_bytes(1, 'little'))
    else:
        sys.stdout.buffer.write(prod(dim).to_bytes(1, 'little'))


def align(addr, size=4):
    if not (addr % size):
        return addr
    return ((addr // size) + 1) * size


args_data = b''
args_idx = []
output_args = []


class SetAlign(argparse.Action):
    def __call__(self, _, namespace, values, option_string=None):
        global args_data
        a = 4
        if not hasattr(namespace, self.dest):
            setattr(namespace, self.dest, a)
        else:
            old_attr = getattr(namespace, self.dest)
            if old_attr is not None:
                a = old_attr * 2
            setattr(namespace, self.dest, a)
        args_data += bytes(align(len(args_data), a))


class SetArg(argparse.Action):
    def __call__(self, _, namespace, values, option_string=None):
        global args_data, args_idx, output_args
        setattr(namespace, "align", None)
        for arg in values:
            args_idx.append(len(args_data))
            if self.dest == "file_arg":
                with open(arg, 'rb') as arg_file:
                    args_data += arg_file.read()
            elif self.dest == "integer_arg":
                args_data += int(arg).to_bytes(4, "little")
            elif self.dest == "string_arg":
                args_data += bytes(arg, 'ascii')
            elif self.dest == "output_arg":
                arg_size = int(arg)
                output_args.append((len(args_data), arg_size))
                args_data += bytes(arg_size)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-k", "--kernel", required=True, help="""Input .ELF file to process""")

    parser.add_argument("--opencl", action='store_true', help="""This is an OpenCL kernel""")

    parser.add_argument("-d", "--dim", required=True, help="""Set the dimensions of the kernel to run""",
                        nargs='+', type=int)

    parser.add_argument("-a", "--align", help="""Align the next argument, -a = 4B, -aa = 8B, -aaa = 16""",
                        action=SetAlign, nargs="?")

    parser.add_argument("-f", "--file_arg", help="""Load a file and place it in memory""",
                        action=SetArg, nargs="+")

    parser.add_argument("-i", "--integer_arg", help="""Send an argument in form of a signed integer (4B)""",
                        action=SetArg, nargs="+")

    parser.add_argument("-s", "--string_arg", help="""Places a string in memory""",
                        action=SetArg, nargs="+")

    parser.add_argument("-o", "--output_arg", help="""Reserves space in the device memory and reads it after \
                                                        the execution""",
                        action=SetArg, nargs="+")

    args = parser.parse_args()
    with ELFFile(open(args.kernel, 'rb')) as elf_file:
        mem_addr_k, addr_k, start_k, end_k, data_k = extract_elf(elf_file)
    args_addr = align(mem_addr_k + send_bin(mem_addr_k, data_k), size=32)   # send kernel
    args_idx_addr = align(args_addr + send_bin(args_addr, args_data), size=4)   # send args
    arg_table = b''.join(map(lambda x: (x + args_addr).to_bytes(4, 'little'), args_idx))  # build arg table
    free_dt = send_bin(args_idx_addr, arg_table)  # send arg table
    kernel_dims = args.dim + [1] * (3 - len(args.dim))
    run_kernel(addr_k, start_k, end_k, kernel_dims, args_idx_addr, args.opencl)
    for ar, sz in output_args:
        recv_bin(ar + args_addr, sz)
