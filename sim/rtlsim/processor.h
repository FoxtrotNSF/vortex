#pragma once

#include <vector>
#include <cstdint>
namespace vortex {

class RAM;

class Processor {
public:
  
  Processor();
  ~Processor();

  void attach_ram(RAM* ram);

  int run(std::vector<uint32_t> brp_addrs = {});

private:

  class Impl;
  Impl* impl_;
};

}