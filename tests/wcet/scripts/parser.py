import re
import sys
import argparse

instr_print_sz = 10
max_instr_per_blk = 100

# Définition de la regex pour extraire les informations d'une instruction
instr_regex = re.compile(r'(\d+):\s+(\S+):\s+wid=(\d+),\s+PC=([0-9a-fA-F]+)(?:,\s+ex=(\w+))?')
asm_regex = re.compile(r'([0-9a-fA-F]+):(?:\s+[0-9a-fA-F]+){4}\s+(\w+)')

LOG = "Info"
FE = "Fetch"
IS = "Issue"
EX = "Execute"
C = "Commit"
func_units = ["ALU", "FPU", "GPU", "CSR", "LSU"]
execute_stages = [' '.join(i) for i in zip([EX] * len(func_units), func_units)]

tracked_stages = [FE, IS] + execute_stages + [C]

num_tracked_stages = len(tracked_stages)


def rename_stage(stage):
    if(stage.endswith("fetch")): return FE
    if(stage.endswith("decode")): return IS
    if(stage.endswith("issue")): return EX
    if(stage.endswith("commit")): return C
    if(stage.endswith("info")): return LOG
    return None


# Lecture du fichier contenant la sortie à parser
def get_stages(filename):
    # Initialisation de la liste des états du pipeline
    pipeline_states = {0: dict(zip(tracked_stages, [[]] * num_tracked_stages))}
    last_time = 0
    max_instrs = {s: 0 for s in tracked_stages}
    with open(filename, 'r') as f:
        # Boucle de traitement des lignes du fichier
        for line in f:
            # Extraction des informations de l'instruction de la ligne courante
            instr_match = instr_regex.search(line)
            if instr_match:
                matches = instr_match.groups()
                nb_matches = instr_match.lastindex
                instr_time = int(matches[0])
                instr_stage = rename_stage(matches[1])
                instr_wid = int(matches[2])
                instr_pc = int(matches[3], 16)
                if instr_stage is None or nb_matches < 4:
                    continue
                if instr_stage == EX:
                    assert nb_matches == 5
                    ex_stage = matches[4]
                    if ex_stage in func_units:
                        instr_stage = execute_stages[func_units.index(matches[4])]
                # Ajout de l'instruction à la liste des instructions en attente de traitement
                if instr_time not in pipeline_states.keys():
                    pipeline_states[instr_time] = {k: v.copy() for k, v in pipeline_states[last_time].items()}
                    max_instrs = {k: max(v, len(pipeline_states[last_time][k])) for k, v in max_instrs.items()}
                    pipeline_states[instr_time][C].clear()
                    pipeline_states[instr_time][FE].clear()
                    last_time = instr_time
                if instr_stage in tracked_stages[1:]:
                    if instr_stage.startswith(EX):
                        prev_stage = [IS]
                    elif instr_stage == C:
                        prev_stage = execute_stages
                    elif instr_stage == IS:
                        prev_stage = [FE]
                    else:
                        print("wat?")
                        exit(1)
                    for i in prev_stage:
                        try:
                            pipeline_states[instr_time][i].remove((instr_pc, instr_wid))
                        except ValueError:
                            if instr_stage in execute_stages:
                                print("Failed to track an instruction", hex(instr_pc))
                if instr_stage == LOG:
                    if LOG not in pipeline_states[instr_time].keys():
                        pipeline_states[instr_time][LOG] = []
                    pipeline_states[instr_time][LOG].append(line)
                pipeline_states[instr_time][instr_stage].append((instr_pc, instr_wid))
    pipeline_states.pop(0)
    return pipeline_states, max_instrs


def parse_dump(filename):
    instrs_per_addr = {}
    with open(filename, 'r') as f:
        for line in f:
            asm_match = asm_regex.search(line)
            if asm_match:
                instrs_per_addr[int(asm_match.group(1), 16)] = asm_match.group(2)
    return instrs_per_addr


def to_size(final_size, input):
    sz, pair = divmod((final_size - len(input)), 2)
    return (" " * (sz) + input + " " * (sz + pair))[:final_size], sz


def multicolour(texts, arglist, **args):
    assert len(texts) == len(arglist)
    return ''.join([colour(t, **a, **args) for t, a in zip(texts, arglist)])


def colour(text, style=0, fg=37, bg=40):
    format = ';'.join([str(style), str(fg), str(bg)])
    return '\x1b[%sm%s\x1b[0m' % (format, text)


def print_tab(stage_occupancy, max_instrs, asm_names):
    size_max = {k: instr_print_sz * min(v, max_instr_per_blk) for k, v in max_instrs.items()}
    instrs_color = {}
    colors = list(range(40, 48))[1:]  # not black
    nbcolors = len(colors)
    last_color = -1
    last_time = None
    s1 = ''
    addr_slot_size = 11
    last_fe = None
    header = to_size(addr_slot_size, "time")[0]
    header += ' '.join([to_size(size_max[s], s)[0] for s in tracked_stages])
    print(header)
    for k, v in stage_occupancy.items():
        curr_time = k // 2
        if last_time is None:
            last_time = curr_time - 1
        for i in range(last_time, curr_time)[1:]:
            print(to_size(addr_slot_size, str(i))[0] + s1)
        last_time = curr_time
        s1 = ''
        next_print = to_size(addr_slot_size, str(curr_time))[0]
        for s in tracked_stages:
            if v[s]:
                curr_instr_size, spare_spaces = divmod(size_max[s], len(v[s][:max_instr_per_blk]))
                i = 0
                for pc, wid in v[s][-max_instr_per_blk:][::-1]:
                    if pc not in instrs_color.keys():
                        last_color = (last_color + 1) % nbcolors
                        instrs_color[pc] = last_color
                    if s == FE and ((last_fe is None) or ((pc, wid) not in last_fe)):
                        next_print = colour(to_size(addr_slot_size, hex(pc))[0], bg=colors[instrs_color[pc]])
                    name = str(wid) + ' ' + str(asm_names[pc] if (pc in asm_names.keys()) else "NOTFOUND")
                    isize = curr_instr_size if not spare_spaces or i % (max_instr_per_blk // (spare_spaces)) else (curr_instr_size + 1)
                    name, ofs = to_size(isize, name)
                    multi = [name[:ofs], name[ofs], name[ofs+1:]]
                    args = [{}, {"fg": 30+wid, "style": 1}, {}]
                    s1 += multicolour(multi, args, bg=colors[instrs_color[pc]])
                    i += 1
                last_fe = v[FE]
            else:
                s1 += colour(to_size(size_max[s], 'Empty')[0])
            s1 += " "
        print(next_print + s1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--dump",
                        action='append',
                        required=True,
                        help=""".dump files of the current executed code (to name instructions)""")

    parser.add_argument("-t", "--trace",
                        required=False,
                        help="""trace file to analyze, if not provided the default is stdin""")

    args = parser.parse_args()

    trace_file = 0 if args.trace is None else args.trace
    asm_names = {}
    for dump_file in args.dump:
        asm_names |= parse_dump(dump_file)
    stages, max_instrs = get_stages(trace_file)
    for k,m in max_instrs.items():
        if m == 0:
            tracked_stages.remove(k)
    print_tab(stages, max_instrs, asm_names)
