/**
 * @file AngleOfArrival.h
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date 25/10/2026
 *
 * @brief Declaration of AngleOfArrival, the direction (azimuth and elevation) from which a pulse is received
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


// Signals Intelligence
namespace sigint {

/**
 * @class AngleOfArrival
 *
 * @brief Direction from which a pulse is received, as an azimuth in [0, 360) and an elevation in [-90, 90] (degrees).
 *
 */
class AngleOfArrival {
public:
  //// PUBLIC //////////////////////////////////      CLASS METHODS      ///////////////////////////////////////////////
  /**
   * @brief Converts the object into the string "[Azimuth: azimuth, Elevation: elevation]"
   *
   * @return Text representation of the angle of arrival
   */
  [[nodiscard]] std::string to_string() const;
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //// PUBLIC //////////////////////////////////    SETTERS & GETTERS    ///////////////////////////////////////////////
  /**
   * @brief Sets the azimuth, wrapped into [0, 360)
   *
   * @param iNewAzimuthDeg Azimuth (deg), any value
   */
  void set_azimuthDeg(float iNewAzimuthDeg);

  /**
   * @brief Sets the elevation, folded over the pole into [-90, 90] (folding turns the azimuth 180 degrees)
   *
   * @param iNewElevationDeg Elevation (deg), any value
   */
  void set_elevationDeg(float iNewElevationDeg);

  /**
   * @brief Getter of the azimuth
   *
   * @return Azimuth (deg), in [0, 360)
   */
  [[nodiscard]] float get_azimuthDeg() const;

  /**
   * @brief Getter of the elevation
   *
   * @return Elevation (deg), in [-90, 90]
   */
  [[nodiscard]] float get_elevationDeg() const;
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //// PUBLIC //////////////////////////////////      CONSTRUCTORS       ///////////////////////////////////////////////
  /**
   * @brief Default constructor
   */
  AngleOfArrival() = default;

  /**
   * @brief Constructor from azimuth and elevation, normalized as in the setters
   *
   * @param iAzimuthDeg Azimuth (deg), any value
   * @param iElevationDeg Elevation (deg), any value
   */
  AngleOfArrival(float iAzimuthDeg, float iElevationDeg);
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //// PUBLIC //////////////////////////////////    FRIEND FUNCTIONS     ///////////////////////////////////////////////
  /**
   * @brief Equal comparison operator
   *
   * @param iLhs Left operand
   * @param iRhs Right operand
   *
   * @return true if all the attributes are equal
   */
  friend bool operator==(const AngleOfArrival& iLhs, const AngleOfArrival& iRhs) noexcept = default;

  /**
   * @brief Ostream operator
   *
   * @param ioOs Output stream
   * @param iOther Object to write
   *
   * @return ioOs
   */
  friend std::ostream& operator<<(std::ostream& ioOs, const AngleOfArrival& iOther) {
    ioOs << iOther.to_string();
    return ioOs;
  }
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

private:
  //// PRIVATE /////////////////////////////////      CLASS METHODS      ///////////////////////////////////////////////
  /**
   * @brief Wraps a value into the interval [iMin, iMin + iPeriod)
   *
   * @param iValue Value to wrap
   * @param iMin Lower bound of the interval (included)
   * @param iPeriod Length of the interval
   *
   * @return iValue shifted by a whole number of periods into [iMin, iMin + iPeriod)
   */
  [[nodiscard]] static float wrap_angle(float iValue, float iMin, float iPeriod);

  /**
   * @brief Folds the elevation over the pole into [-90, 90] and wraps the azimuth into [0, 360)
   */
  void normalize();
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  //// PRIVATE /////////////////////////////////    CLASS ATTRIBUTES     ///////////////////////////////////////////////
  float azimuthDeg_{};   ///< Azimuth (deg, normalized to [0, 360))
  float elevationDeg_{}; ///< Elevation (deg, folded over the pole into [-90, 90])
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
};

} // namespace sigint
