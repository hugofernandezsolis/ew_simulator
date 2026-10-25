/**
 * @file AngleOfArrival.cpp
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date 24/10/2026
 *
 * @brief Definition of AngleOfArrival, the direction (azimuth and elevation) from which a pulse is received
 *
 * @copyright Copyright (c) 2026
 */


// C includes
// C++ includes
#include <cmath>
#include <format>
#include <string>
// External includes
// Project includes
#include <AngleOfArrival.h>


// Signals Intelligence
namespace sigint {

namespace {
// Angular constants (degrees) used to normalize the azimuth and the elevation
constexpr float fullTurnDeg{360.0f};
constexpr float halfTurnDeg{180.0f};
constexpr float poleElevationDeg{90.0f};
} // namespace

//// PUBLIC //////////////////////////////////      CLASS METHODS      ///////////////////////////////////////////////
std::string AngleOfArrival::to_string() const {
  return std::format("[Azimuth: {}, Elevation: {}]", this->azimuthDeg_, this->elevationDeg_);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//// PUBLIC //////////////////////////////////    SETTERS & GETTERS    ///////////////////////////////////////////////
void AngleOfArrival::set_azimuthDeg(float iNewAzimuthDeg) {
  this->azimuthDeg_ = iNewAzimuthDeg;
  this->normalize();
}

void AngleOfArrival::set_elevationDeg(float iNewElevationDeg) {
  this->elevationDeg_ = iNewElevationDeg;
  this->normalize();
}

float AngleOfArrival::get_azimuthDeg() const {
  return this->azimuthDeg_;
}

float AngleOfArrival::get_elevationDeg() const {
  return this->elevationDeg_;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//// PUBLIC //////////////////////////////////      CONSTRUCTORS       ///////////////////////////////////////////////
AngleOfArrival::AngleOfArrival(float iAzimuthDeg, float iElevationDeg)
    : azimuthDeg_{iAzimuthDeg}, elevationDeg_{iElevationDeg} {
  this->normalize();
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


//// PRIVATE /////////////////////////////////      CLASS METHODS      ///////////////////////////////////////////////
float AngleOfArrival::wrap_angle(float iValue, float iMin, float iPeriod) {
  // std::fmod keeps the sign of the dividend, so negative results must be shifted one period up
  float offset{std::fmod(iValue - iMin, iPeriod)};
  if (offset < 0.0f) offset += iPeriod;
  // Rounding can turn a tiny negative offset into exactly iPeriod (e.g. -1e-7f + 360.0f == 360.0f)
  if (offset >= iPeriod) offset = 0.0f;
  return iMin + offset;
}

void AngleOfArrival::normalize() {
  // The elevation goes first: folding it over the pole turns the azimuth 180 degrees
  this->elevationDeg_ = wrap_angle(this->elevationDeg_, -halfTurnDeg, fullTurnDeg);
  if (this->elevationDeg_ > poleElevationDeg) {
    this->elevationDeg_ = halfTurnDeg - this->elevationDeg_;
    this->azimuthDeg_ += halfTurnDeg;
  } else if (this->elevationDeg_ < -poleElevationDeg) {
    this->elevationDeg_ = -halfTurnDeg - this->elevationDeg_;
    this->azimuthDeg_ += halfTurnDeg;
  }
  this->azimuthDeg_ = wrap_angle(this->azimuthDeg_, 0.0f, fullTurnDeg);
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


} // namespace sigint
