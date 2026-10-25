/**
 * @file ut_AngleOfArrival.cpp
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date 24/10/2026
 *
 * @brief Unit tests of AngleOfArrival, one test case per function
 *
 * @copyright Copyright (c) 2026
 */


// C includes
// C++ includes
#include <sstream>
#include <type_traits>
#include <utility>
// External includes
#include <gtest/gtest.h>
// Project includes
#include <AngleOfArrival.h>


// Signals Intelligence
namespace sigint {

// Compile-time checks of the class properties
static_assert(std::is_trivially_copyable_v<AngleOfArrival>);
static_assert(std::is_nothrow_move_constructible_v<AngleOfArrival>);
static_assert(std::is_nothrow_move_assignable_v<AngleOfArrival>);
static_assert(noexcept(std::declval<const AngleOfArrival&>() == std::declval<const AngleOfArrival&>()));

/**
 * @class AngleOfArrivalTest
 *
 * @brief Fixture that provides a default-constructed AngleOfArrival to every test
 */
class AngleOfArrivalTest : public ::testing::Test {
protected:
  AngleOfArrival angleofarrival{};
};

// Test to_string returns "[Azimuth: azimuth, Elevation: elevation]"
TEST_F(AngleOfArrivalTest, ToStringReturnsAzimuthAndElevation) {
  const AngleOfArrival aoa{45.5f, -30.25f};
  EXPECT_EQ(aoa.to_string(), "[Azimuth: 45.5, Elevation: -30.25]");
}

// Test azimuth setter stores an in-range value unchanged
TEST_F(AngleOfArrivalTest, AzimuthSetterStoresValue) {
  angleofarrival.set_azimuthDeg(45.5f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 45.5f);
  angleofarrival.set_azimuthDeg(0.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 0.0f);
}

// Test azimuth setter wraps the value into [0, 360)
TEST_F(AngleOfArrivalTest, AzimuthSetterWrapsIntoRange) {
  angleofarrival.set_azimuthDeg(370.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 10.0f);
  angleofarrival.set_azimuthDeg(-10.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 350.0f);
  angleofarrival.set_azimuthDeg(360.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 0.0f);
  // Rounding must not leave the azimuth at exactly 360
  angleofarrival.set_azimuthDeg(-0.0000001f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 0.0f);
}

// Test azimuth setter does not change a valid elevation
TEST_F(AngleOfArrivalTest, AzimuthSetterKeepsElevation) {
  angleofarrival.set_elevationDeg(30.25f);
  angleofarrival.set_azimuthDeg(370.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), 30.25f);
}

// Test elevation setter stores an in-range value unchanged
TEST_F(AngleOfArrivalTest, ElevationSetterStoresValue) {
  angleofarrival.set_elevationDeg(30.25f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), 30.25f);
  angleofarrival.set_elevationDeg(-45.5f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), -45.5f);
}

// Test elevation setter folds the value over the pole into [-90, 90]
TEST_F(AngleOfArrivalTest, ElevationSetterFoldsOverPole) {
  angleofarrival.set_elevationDeg(100.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), 80.0f);
  angleofarrival.set_elevationDeg(-100.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), -80.0f);
  // The pole itself is valid and is not folded
  angleofarrival.set_elevationDeg(90.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), 90.0f);
  // Values beyond a full turn are wrapped before folding
  angleofarrival.set_elevationDeg(300.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), -60.0f);
}

// Test elevation setter turns the azimuth 180 degrees only when it folds over the pole
TEST_F(AngleOfArrivalTest, ElevationSetterTurnsAzimuthWhenFolding) {
  // North pole
  angleofarrival.set_azimuthDeg(10.0f);
  angleofarrival.set_elevationDeg(100.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 190.0f);
  // South pole
  angleofarrival.set_azimuthDeg(0.0f);
  angleofarrival.set_elevationDeg(-100.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 180.0f);
  // The pole itself is not folded, so the azimuth does not change
  angleofarrival.set_azimuthDeg(10.0f);
  angleofarrival.set_elevationDeg(90.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 10.0f);
  // Wrapping beyond a full turn without folding does not change the azimuth
  angleofarrival.set_azimuthDeg(0.0f);
  angleofarrival.set_elevationDeg(300.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 0.0f);
}

// Test azimuth getter returns the stored value
TEST_F(AngleOfArrivalTest, AzimuthGetterReturnsStoredValue) {
  const AngleOfArrival aoa{45.5f, 30.25f};
  EXPECT_FLOAT_EQ(aoa.get_azimuthDeg(), 45.5f);
}

// Test elevation getter returns the stored value
TEST_F(AngleOfArrivalTest, ElevationGetterReturnsStoredValue) {
  const AngleOfArrival aoa{45.5f, 30.25f};
  EXPECT_FLOAT_EQ(aoa.get_elevationDeg(), 30.25f);
}

// Test default constructor initializes to 0
TEST_F(AngleOfArrivalTest, DefaultConstructorInitializesToZero) {
  EXPECT_FLOAT_EQ(angleofarrival.get_azimuthDeg(), 0.0f);
  EXPECT_FLOAT_EQ(angleofarrival.get_elevationDeg(), 0.0f);
}

// Test constructor with azimuth and elevation stores in-range values unchanged
TEST_F(AngleOfArrivalTest, ParameterConstructorStoresValues) {
  const AngleOfArrival aoa{45.5f, 30.25f};
  EXPECT_FLOAT_EQ(aoa.get_azimuthDeg(), 45.5f);
  EXPECT_FLOAT_EQ(aoa.get_elevationDeg(), 30.25f);
}

// Test constructor with azimuth and elevation wraps the azimuth into [0, 360)
TEST_F(AngleOfArrivalTest, ParameterConstructorWrapsAzimuth) {
  EXPECT_FLOAT_EQ((AngleOfArrival{370.0f, 0.0f}).get_azimuthDeg(), 10.0f);
  EXPECT_FLOAT_EQ((AngleOfArrival{-10.0f, 0.0f}).get_azimuthDeg(), 350.0f);
  EXPECT_FLOAT_EQ((AngleOfArrival{360.0f, 0.0f}).get_azimuthDeg(), 0.0f);
  // Rounding must not leave the azimuth at exactly 360
  EXPECT_FLOAT_EQ((AngleOfArrival{-0.0000001f, 0.0f}).get_azimuthDeg(), 0.0f);
}

// Test constructor with azimuth and elevation folds the elevation over the pole into [-90, 90]
TEST_F(AngleOfArrivalTest, ParameterConstructorFoldsElevation) {
  // North pole: the azimuth turns 180 degrees
  const AngleOfArrival north{10.0f, 100.0f};
  EXPECT_FLOAT_EQ(north.get_azimuthDeg(), 190.0f);
  EXPECT_FLOAT_EQ(north.get_elevationDeg(), 80.0f);
  // South pole: the azimuth turns 180 degrees
  const AngleOfArrival south{0.0f, -100.0f};
  EXPECT_FLOAT_EQ(south.get_azimuthDeg(), 180.0f);
  EXPECT_FLOAT_EQ(south.get_elevationDeg(), -80.0f);
  // The pole itself is valid and is not folded
  const AngleOfArrival pole{10.0f, 90.0f};
  EXPECT_FLOAT_EQ(pole.get_azimuthDeg(), 10.0f);
  EXPECT_FLOAT_EQ(pole.get_elevationDeg(), 90.0f);
  // Folding can push the azimuth past 360, so it must be wrapped afterwards
  const AngleOfArrival wrapped{350.0f, 100.0f};
  EXPECT_FLOAT_EQ(wrapped.get_azimuthDeg(), 170.0f);
  EXPECT_FLOAT_EQ(wrapped.get_elevationDeg(), 80.0f);
}

// Test equality operator
TEST_F(AngleOfArrivalTest, EqualityOperator) {
  EXPECT_TRUE((AngleOfArrival{45.5f, 30.25f}) == (AngleOfArrival{45.5f, 30.25f}));
  // Only the azimuth differs
  EXPECT_FALSE((AngleOfArrival{45.5f, 30.25f}) == (AngleOfArrival{10.0f, 30.25f}));
  // Only the elevation differs
  EXPECT_FALSE((AngleOfArrival{45.5f, 30.25f}) == (AngleOfArrival{45.5f, -10.0f}));
}

// Test ostream operator<<
TEST_F(AngleOfArrivalTest, OstreamOperatorProducesString) {
  const AngleOfArrival aoa{45.5f, -30.25f};
  std::ostringstream oss{};
  oss << aoa;
  EXPECT_EQ(oss.str(), "[Azimuth: 45.5, Elevation: -30.25]");
}

} // namespace sigint
