#include "Vvx_decoder_wrapper.h"
#include <pybind11/pybind11.h>

#define EX_NOP 0
#define EX_ALU 1
#define EX_LSU 2
#define EX_CSR 3
#define EX_FPU 4
#define EX_GPU 5

void eval_data_in(Vvx_decoder_wrapper &a, uint32_t value){
    a.in_data = value;
    a.eval();
}

PYBIND11_MODULE(vx_decoder_py, m) {
    m.doc() = "system_verilog as py module";
    m.attr("EX_NOP") = pybind11::int_(EX_NOP);
    m.attr("EX_ALU") = pybind11::int_(EX_ALU);
    m.attr("EX_LSU") = pybind11::int_(EX_LSU);
    m.attr("EX_CSR") = pybind11::int_(EX_CSR);
    m.attr("EX_FPU") = pybind11::int_(EX_FPU);
    m.attr("EX_GPU") = pybind11::int_(EX_GPU);
    pybind11::class_<Vvx_decoder_wrapper>(m, "Decoder")
        .def(pybind11::init())
        .def_property_readonly("ex_type", [](const Vvx_decoder_wrapper &a){return a.ex_type;})
        .def_property_readonly("op_type", [](const Vvx_decoder_wrapper &a){return a.op_type;})
        .def_property_readonly("op_mod", [](const Vvx_decoder_wrapper &a){return a.op_mod;})
        .def_property_readonly("wb", [](const Vvx_decoder_wrapper &a){return a.wb;})
        .def_property_readonly("use_PC", [](const Vvx_decoder_wrapper &a){return a.use_PC;})
        .def_property_readonly("use_imm", [](const Vvx_decoder_wrapper &a){return a.use_imm;})
        .def_property_readonly("imm", [](const Vvx_decoder_wrapper &a){return a.imm;})
        .def_property_readonly("rd", [](const Vvx_decoder_wrapper &a){return a.rd;})
        .def_property_readonly("rs1", [](const Vvx_decoder_wrapper &a){return a.rs1;})
        .def_property_readonly("rs2", [](const Vvx_decoder_wrapper &a){return a.rs2;})
        .def_property_readonly("rs3", [](const Vvx_decoder_wrapper &a){return a.rs3;})
        .def("eval", &eval_data_in, pybind11::arg("data_in") = 0);
}

