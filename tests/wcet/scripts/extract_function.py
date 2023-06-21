from collections.abc import Iterable
from intelhex import IntelHex
from elftools.elf.elffile import ELFFile
from array import array
from pyriscv_disas import Inst, rv_disas
from pyriscv_disas.riscv_disas import *

func_name = "test_wcet"

elf_file = ELFFile(open("../test_wcet_kernel.elf", "rb"))
# elf_file = ELFFile(open("../../../hw/syn/vivado/bootrom/bootrom.elf", "rb"))
hex_data = IntelHex()
for s in elf_file.iter_segments():
    if s['p_type'] == 'PT_LOAD':
        hex_data.frombytes(s.data(), s['p_paddr'])

bin_data = hex_data.tobinarray()
addr = hex_data.minaddr()

symbols = elf_file.get_section_by_name('.symtab')
fn = symbols.get_symbol_by_name(func_name)
assert fn is not None, "Symbol "+func_name+" is not found in the file"
fn = fn[0]
fn_start = fn["st_value"]
f_start = fn_start - addr
f_end = f_start + fn["st_size"]

function_data = array('I', bin_data[f_start: f_end].tobytes())
assert function_data.itemsize == 4, "Wrong type on this machine"

machine = rv_disas(PC=fn_start, arch=rv32)
costs = {
    rv_op_nop: 1
}

for ins in function_data:
    decd_inst = machine.disassemble(ins)
    if decd_inst.op == rv_op_nop:
        print("nop")


def create_gtorr_sched(l_hit):
    def process_block(remaining, n_i, rate_in):
        rate_out = rate_in * l_hit
        end_warp, nb_inst = min([(i, v) for i, v in enumerate(remaining[:l_hit])], key=lambda x: x[1])
        inst_scheduled = nb_inst + n_i
        rem_out  = [v - nb_inst for v in remaining[:min(l_hit, end_warp)]]  # done warps + 1 inst
        rem_out += [0]                                                      # end_warp
        rem_out += [v - nb_inst + 1 for v in remaining[min(end_warp+1, l_hit):l_hit]]     # done warps
        rem_out += [v + n_i for v in remaining[l_hit:]]                    # warps not scheduled
        time = (inst_scheduled - 1) * l_hit + 1
        return rate_out, rem_out, time
    return process_block


sched = create_gtorr_sched(5)


def schedule_instrs(warp_instrs, scheduler):
    num_warps = len(warp_instrs)
    time = 0
    while num_warps:
        print("step:", time, "\tworkload:", ','.join(map(str, warp_instrs)))
        _, warp_instrs, new_time = scheduler(warp_instrs, 0, 1)
        for w in range(num_warps, 0, -1):
            if warp_instrs[w-1] == 0:
                del warp_instrs[w-1]
        time += new_time
        num_warps = len(warp_instrs)
    print(time)


schedule_instrs([10]*3+[9]+[11]*3, sched)
