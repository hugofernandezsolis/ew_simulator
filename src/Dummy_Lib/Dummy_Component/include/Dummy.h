/**
 * @file Dummy.h
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date 24/10/2026
 *
 * @brief Declaration of Dummy, a minimal struct that serves as an example of the struct layout of the project
 *
 * @copyright Copyright (c) 2026
 */

#pragma once


// C includes
// C++ includes
#include <ostream>
#include <string>
// External includes
// Project includes


// Dummy
namespace dummy {

/**
 * @struct Dummy
 *
 * @brief Minimal aggregate with a single boolean attribute, used as an example of the struct layout of the project
 */
struct Dummy {
  bool dummy{}; ///< Dummy flag (example attribute)

  /**
   * @brief Converts the object into the string "[Dummy: dummy]"
   *
   * @return Text representation of the struct
   */
  [[nodiscard]] std::string to_string() const;

  /**
   * @brief Equal comparison operator
   *
   * @param iLhs Left operand
   * @param iRhs Right operand
   *
   * @return true if all the attributes are equal
   */
  friend bool operator==(const Dummy& iLhs, const Dummy& iRhs) noexcept = default;

  /**
   * @brief Ostream operator
   *
   * @param ioOs Output stream
   * @param iOther Object to write
   *
   * @return ioOs
   */
  friend std::ostream& operator<<(std::ostream& ioOs, const Dummy& iOther) {
    ioOs << iOther.to_string();
    return ioOs;
  }
};

} // namespace dummy
