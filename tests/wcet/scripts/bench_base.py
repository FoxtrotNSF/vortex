import os
import re
import subprocess

VORTEX_BASE = os.getcwd() + "/../../.."
TEST_WCET_DIR = os.getcwd() + "/.."


def extract_durations(func):
    def inner(dictionary, _):
        durations = [item[1] for sublist in dictionary.values() for item in sublist]
        return func(durations)
    return inner


d = extract_durations


def avg(l):
    return sum(l) // len(l)


def amplitude(dictionary, times):
    starts, ends = zip(* [(item[0], sum(item)) for sublist in dictionary.values() for item in sublist])
    return sum(times[min(starts): max(ends)])


num_active_warps = [4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 26, 28, 30, 32]
num_available_warps = [8]
cache_latencies = [2, 3, 4]
cache_settings = {2: (0, 0), 3: (2, 0), 4: (2, 2)}
functions_settings = {"minimum": d(min), "maximum": d(max), "average": d(avg), "amplitude": amplitude}
results = {}


def main():
    for n in num_available_warps:
        results[n] = {}
        for l in cache_latencies:
            results[n][l] = {}
            os.chdir(VORTEX_BASE+"/sim/rtlsim")
            cache_param = cache_settings[l]
            os.system(
                'make clean && AXI_BUS=1 CONFIGS="-DNUM_WARPS={0} -DICACHE_CRSQ_SIZE={1} -DICACHE_CREQ_SIZE={2}" make'
                .format(n, cache_param[0], cache_param[1]))
            for j in num_active_warps:
                os.chdir(TEST_WCET_DIR)
                os.system('make clean-all && CONFIGS="-DSIZE={0}" make'.format(j*4))
                results[n][l][j] = {k: 0 for k in functions_settings}
                try:
                    a = subprocess.run(["./rtlsim", TEST_WCET_DIR+"/test_wcet_kernel.bin", "-b", "0x80000368", "-b", "0x8000036c"], cwd=VORTEX_BASE+"/sim/rtlsim", timeout=10, capture_output=True)
                    if a.returncode:
                        raise subprocess.TimeoutExpired(cmd=' '.join(a.args), timeout=10)
                except subprocess.TimeoutExpired:
                    continue
                output = a.stdout.decode("ascii")
                warps = {}
                times = []
                warps_time = {}
                for line in output.split("\n"):
                    print(line)
                    match = re.search(r'Execute : warp (\d+) \(\d+\) : break at [0-9a-fA-F]+ after (\d+) clocks', line)
                    if match:
                        warp_nbr = int(match.group(1))
                        times.append(int(match.group(2)))
                        if warp_nbr not in warps.keys():
                            warps[warp_nbr] = len(times)
                        else:
                            if warp_nbr not in warps_time.keys():
                                warps_time[warp_nbr] = []
                            a = warps.pop(warp_nbr)
                            warps_time[warp_nbr].append((a, sum(times[a:])))  # (start, duration)
                for k, f in functions_settings.items():
                    results[n][l][j][k] = f(warps_time, times)


if __name__ == "__main__":
    main()
    print("")
    print(results)


"""
"""