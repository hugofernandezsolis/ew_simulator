/**
 * @file Dummy.cpp
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date 24/10/2026
 *
 * @brief Definition of Dummy, a minimal struct that serves as an example of the struct layout of the project
 *
 * @copyright Copyright (c) 2026
 */


// C includes
// C++ includes
#include <format>
#include <string>
// External includes
// Project includes
#include <Dummy.h>


// Dummy
namespace dummy {

std::string Dummy::to_string() const {
  return std::format("[Dummy: {}]", this->dummy);
}

} // namespace dummy
