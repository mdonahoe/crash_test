#pragma once
#include <string>
#include "crash.h"

class CrashTest {
  CrashTest();  // must have a constructor

  std::string first_;  // must be a string declared before Crash object
  Crash crash_;  // must be a value, not pointer
};
