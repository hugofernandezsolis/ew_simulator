/**
 * @file ut_Dummy.cpp
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date 24/10/2026
 *
 * @brief Unit tests of Dummy, one test case per function
 *
 * @copyright Copyright (c) 2026
 */


// C includes
// C++ includes
#include <sstream>
#include <type_traits>
// External includes
#include <gtest/gtest.h>
// Project includes
#include <Dummy.h>


// Dummy
namespace dummy {

// Compile-time checks of the struct properties
static_assert(std::is_aggregate_v<Dummy>);
static_assert(std::is_trivially_copyable_v<Dummy>);
static_assert(std::is_nothrow_move_constructible_v<Dummy>);
static_assert(std::is_nothrow_move_assignable_v<Dummy>);

/**
 * @class DummyTest
 *
 * @brief Fixture that provides a default-initialized Dummy to every test
 */
class DummyTest : public ::testing::Test {
protected:
  Dummy dummy{};
};

// Test default initialization is false
TEST_F(DummyTest, DefaultInitializationIsFalse) {
  EXPECT_FALSE(dummy.dummy);
}

// Test to_string returns "[Dummy: dummy]"
TEST_F(DummyTest, ToStringReturnsDummy) {
  EXPECT_EQ(Dummy{.dummy = true}.to_string(), "[Dummy: true]");
  EXPECT_EQ(Dummy{.dummy = false}.to_string(), "[Dummy: false]");
}

// Test equality operator
TEST_F(DummyTest, EqualityOperator) {
  EXPECT_TRUE((Dummy{.dummy = true}) == (Dummy{.dummy = true}));
  EXPECT_TRUE((Dummy{.dummy = false}) == (Dummy{.dummy = false}));
  EXPECT_FALSE((Dummy{.dummy = true}) == (Dummy{.dummy = false}));
}

// Test ostream operator<<
TEST_F(DummyTest, OstreamOperatorProducesString) {
  std::ostringstream oss{};
  oss << Dummy{.dummy = true};
  EXPECT_EQ(oss.str(), "[Dummy: true]");
}

} // namespace dummy
