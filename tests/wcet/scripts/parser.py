import re
import argparse

from intelhex import IntelHex
from elftools.elf.elffile import ELFFile
from pyriscv_disas.riscv_disas import *
from functools import reduce

# Définition de la regex pour extraire les informations d'une instruction
instr_regex = re.compile(r'(\d+):\s+(\S+):\s+wid=(\d+),\s+PC=([0-9a-fA-F]+)(?:,\s+ex=(\w+))?')

LOG = "Info"
FE = "Fetch"
IS = "Issue"
EX = "Execute"
C = "Commit"
func_units = {"ALU": 4, "FPU": 1, "GPU": 1, "CSR": 1, "LSU": 2}

func_units.pop("FPU")  # we don't care for now

tracked_stages = [FE, IS] + list(func_units.keys()) + [C]


pipeline_conf = {FE: 1, IS: 7, C: 2} | func_units
i_size = 11


def rename_stage(stage) -> str:
    ren = {"fetch": FE, "decode": IS, "issue": EX, "commit": C, "info": LOG}
    return reduce(lambda res, x: ren[x] if stage.endswith(x) else res, ren.keys(), "Unknown")


def rename_ex(stage) -> str:
    return ''


def to_size(final_size, input: str) -> tuple[str, int]:
    if final_size < len(input):
        return input[:final_size], 0
    sz, pair = divmod((final_size - len(input)), 2)
    return (" " * sz + input + " " * (sz + pair))[:final_size], sz


def inv_intersection(lst1, lst2):  # returns all lst1 that are not in lst2
    temp = set(lst2)
    lst3 = [v for v in lst1 if v not in temp]
    return lst3


def colour(text, style=0, fg=37, bg=40):
    fmt = ';'.join([str(style), str(fg), str(bg)])
    return '\x1b[%sm%s\x1b[0m' % (fmt, text)


def extract_instrs(elf_files: list[str]):
    hex_data = IntelHex()
    for filename in elf_files:
        with ELFFile(open(filename, "rb")) as f:
            for s in f.iter_segments():
                if s['p_type'] == 'PT_LOAD':
                    hex_data.frombytes(s.data(), s['p_paddr'])
    return hex_data


def get_instr_at(addr: int, hex_data: IntelHex, buffer_size: int) -> str:
    instr = int.from_bytes(hex_data.gets(addr, 4), "little")
    dec = rv_decode()
    dec.pc = addr
    dec.inst = instr
    decode_inst_opcode(dec, rv32)
    decode_inst_operands(dec)
    decompress_inst_rv32(dec)
    decode_inst_lift_pseudo(dec)
    return to_size(buffer_size, get_opcode_data(dec.op).name)[0]


def get_instr_bg(pc):
    bg_colors = list(range(40, 48))[1:]  # not black
    return bg_colors[pc % len(bg_colors)]


def get_instr_fg(wid):
    fg_colors = list(range(30, 38))  # with black
    return fg_colors[wid % len(fg_colors)]


def print_instr(instrs, isize):
    def process(i):
        pc, wid = i
        curr_instr_print = ''
        instr_bg = get_instr_bg(pc)
        instr_fg = get_instr_fg(wid)
        name = str(wid) + ' ' + get_instr_at(pc, instrs, isize)
        name, offset = to_size(isize, name)
        curr_instr_print += colour(name[:offset], bg=instr_bg)  # spaces
        curr_instr_print += colour(name[offset: offset + len(str(wid))], bg=instr_bg, fg=instr_fg, style=1)  # wid
        curr_instr_print += colour(name[offset + len(str(wid)):], bg=instr_bg)  # instr name
        return curr_instr_print

    return process


def print_addr(slot_size):
    def process(i):
        pc, _ = i
        instr_bg = get_instr_bg(pc)
        return colour(to_size(slot_size, '%#010x' % pc)[0], bg=instr_bg)

    return process


def format_stage(stage_occ, nb_inst_max, instr_size, process_func, empty_str='', start_chr=''):
    nb_instrs = min(len(stage_occ), nb_inst_max)
    inst_rem = nb_inst_max - nb_instrs
    curr_stage_print = ''.join(map(process_func, stage_occ[-nb_inst_max:][::-1]))
    return start_chr + curr_stage_print + colour(to_size(inst_rem * instr_size, empty_str)[0])


def print_pipeline(curr_time, stage_occupancy, last_fe, instrs: IntelHex):
    s1 = ''
    header_size = 10
    new_fetchs = inv_intersection(stage_occupancy[FE], last_fe)
    header = format_stage(new_fetchs, 1, header_size, print_addr(header_size), str(curr_time)) + ' '
    process_stage = lambda s: format_stage(stage_occupancy[s], pipeline_conf[s], i_size,
                                           print_instr(instrs, i_size),
                                           start_chr=s + ('+'
                                           if len(stage_occupancy[s]) > pipeline_conf[s] else " "))
    print(header + ' '.join(map(process_stage, tracked_stages)))


def analyze(filename, instrs: IntelHex):
    # Initialisation de la liste des états du pipeline
    pipeline_states = {s: [] for s in tracked_stages}
    cst_time_ofs = 16
    last_time = None
    last_fe = []
    started = False
    with open(filename, 'r') as f:
        for line in f:
            if not started:
                started = line.startswith("Running")
                continue
            instr_match = instr_regex.search(line)
            if instr_match:
                matches = instr_match.groups()
                nb_matches = instr_match.lastindex
                if nb_matches < 4:
                    continue
                instr_time = int(matches[0]) // 2 - cst_time_ofs
                instr_stage = rename_stage(matches[1])
                instr_wid = int(matches[2])
                instr_pc = int(matches[3], 16)
                if instr_stage == "Unknown":
                    continue
                if instr_stage == EX:
                    assert nb_matches == 5
                    instr_stage = matches[4]
                if last_time is None:
                    last_time = instr_time
                for i in range(last_time, instr_time):
                    print_pipeline(i, pipeline_states, last_fe, instrs)
                    last_fe = [a for a in pipeline_states[FE]]
                    pipeline_states[C].clear()
                    pipeline_states[FE].clear()
                last_time = instr_time
                if instr_stage in tracked_stages[1:]:
                    if instr_stage in func_units.keys():
                        prev_stage = [IS]
                    elif instr_stage == C:
                        prev_stage = func_units.keys()
                    elif instr_stage == IS:
                        prev_stage = [FE]
                    else:
                        print("wat?")
                        exit(1)
                    for s in prev_stage:
                        try:
                            pipeline_states[s].remove((instr_pc, instr_wid))
                        except ValueError:
                            if instr_stage in func_units.keys():
                                print("Failed to track an instruction", hex(instr_pc))
                if instr_stage == LOG:
                    if LOG not in pipeline_states.keys():
                        pipeline_states[LOG] = []
                    pipeline_states[LOG].append(line)
                if instr_stage in tracked_stages:
                    pipeline_states[instr_stage].append((instr_pc, instr_wid))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-f", "--file",
                        action='append',
                        required=True,
                        help=""".elf files of the current executed code (to name instructions)""")

    args = parser.parse_args()
    extracted_instrs = extract_instrs(args.file)
    analyze(0, extracted_instrs)
