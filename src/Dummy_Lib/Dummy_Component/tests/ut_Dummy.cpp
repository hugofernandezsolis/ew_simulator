/**
 * @file Dummy.cpp
 * @author Hugo Fernández Solís (hugofernandezsolis@gmail.com)
 * @date
 *
 * @brief
 *
 * @copyright Copyright (c) 2025
 */


// C includes
// C++ includes
// External includes
#include <gtest/gtest.h>
// Project includes
#include <Dummy.h>


// Interprocess Communication System
namespace ics {

/**
 * @class DummyTest
 *
 * @brief
 */
class DummyTest : public ::testing::Test {
protected:
  Dummy* dummy;

  void SetUp(void) override {
    dummy = new Dummy();
  }

  void TearDown(void) override {
    delete dummy;
  }

  static void SetUpTestSuite(void) {}

  static void TearDownTestSuite(void) {}
};

// Test default constructor initializes to false
TEST_F(DummyTest, DefaultConstructorInitializesToFalse) {
  EXPECT_FALSE(dummy->get_dummy());
}

// Test setter by const bool&
TEST_F(DummyTest, SetterByValue) {
  dummy->set_dummy(true);
  EXPECT_TRUE(dummy->get_dummy());
  dummy->set_dummy(false);
  EXPECT_FALSE(dummy->get_dummy());
}

// Test setter returns reference
TEST_F(DummyTest, SetterReturnsReference) {
  bool& ref = dummy->set_dummy();
  ref = true;
  EXPECT_TRUE(dummy->get_dummy());
  ref = false;
  EXPECT_FALSE(dummy->get_dummy());
}

// Test to_string returns "0" or "1"
TEST_F(DummyTest, ToStringReturns0Or1) {
  dummy->set_dummy(false);
  EXPECT_EQ(dummy->to_string(), "0");
  dummy->set_dummy(true);
  EXPECT_EQ(dummy->to_string(), "1");
}

// Test copy constructor
TEST_F(DummyTest, CopyConstructorCopiesValue) {
  dummy->set_dummy(true);
  Dummy copy(*dummy);
  EXPECT_TRUE(copy.get_dummy());
  // Changing original should not affect copy
  dummy->set_dummy(false);
  EXPECT_TRUE(copy.get_dummy());
}

// Test move constructor
TEST_F(DummyTest, MoveConstructorMovesValue) {
  dummy->set_dummy(true);
  Dummy moved(std::move(*dummy));
  EXPECT_TRUE(moved.get_dummy());
  EXPECT_FALSE(dummy->get_dummy());
}

// Test copy assignment operator
TEST_F(DummyTest, CopyAssignmentCopiesValue) {
  dummy->set_dummy(true);
  Dummy other;
  other = *dummy;
  EXPECT_TRUE(other.get_dummy());
  // Changing original should not affect assigned
  dummy->set_dummy(false);
  EXPECT_TRUE(other.get_dummy());
}

// Test move assignment operator
TEST_F(DummyTest, MoveAssignmentMovesValue) {
  dummy->set_dummy(true);
  Dummy target;
  target = std::move(*dummy);
  EXPECT_TRUE(target.get_dummy());
  EXPECT_FALSE(dummy->get_dummy());
}

// Test equality and inequality operators
TEST_F(DummyTest, EqualityAndInequalityOperators) {
  Dummy a;
  Dummy b;
  EXPECT_TRUE(a == b);
  a.set_dummy(true);
  EXPECT_FALSE(a == b);
  EXPECT_TRUE(a != b);
}

// Test ostream operator<<
TEST_F(DummyTest, OstreamOperatorProducesString) {
  dummy->set_dummy(true);
  std::ostringstream oss;
  oss << *dummy;
  EXPECT_EQ(oss.str(), "1");
}

} // namespace ics
