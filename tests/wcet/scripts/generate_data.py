import itertools
import random
import string
import argparse
from math import prod


class Coords:
    max_dims = 4
    dim_name = ['x', 'y', 'z', 'w']

    def __init__(self, *values):
        assert len(values) <= Coords.max_dims, "Invalid position dimension ("+str(dims)+")"
        self.dims = len(values)
        self.values = values
        list(map(lambda x, y: setattr(self, x, y), Coords.dim_name, values))


class Dot(Coords):
    def __init__(self, *init_args):
        super().__init__(*init_args)

    def dist(self):
        return sum(self.values)


class Dim(Coords):
    def __init__(self, *init_args):
        super().__init__(*init_args)

    def num_dots(self):
        return prod(self.values)

    def iter_dots(self):
        return map(lambda x: Dot(*x), itertools.product(*map(range, self.values)))


def random_ascii(_x: Dot, _size: Dim):
    return ord(random.choice(string.ascii_uppercase))


def decr(x: Dot, size: Dim):
    return size.num_dots() - x.dist()


def incr(x: Dot, _size: Dim):
    return x.dist()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument("-f", "--file",
                        required=True,
                        help="""output data file""")

    parser.add_argument("-d", "--dim",
                        required=True,
                        nargs='+',
                        type=int,
                        help="""dims of data""")

    args = parser.parse_args()
    dims = Dim(*args.dim)
    with open(args.file, 'wb') as arg_file:
        for p in dims.iter_dots():
            arg_file.write(random_ascii(p, dims).to_bytes(1, "little"))
