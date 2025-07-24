#!/bin/bash

# Simple test to verify basic functionality
echo "Testing change-site.sh basic functionality..."

# Test 1: Help option
echo "Test 1: Help option"
if ./change-site.sh --help >/dev/null 2>&1; then
    echo "✓ Help option works"
else
    echo "✗ Help option failed"
fi

# Test 2: Version option  
echo "Test 2: Version option"
if ./change-site.sh --version >/dev/null 2>&1; then
    echo "✓ Version option works"
else
    echo "✗ Version option failed"
fi

# Test 3: Invalid arguments
echo "Test 3: Invalid arguments"
if ! ./change-site.sh >/dev/null 2>&1; then
    echo "✓ Invalid arguments properly rejected"
else
    echo "✗ Invalid arguments not properly handled"
fi

# Test 4: Syntax check
echo "Test 4: Syntax check"
if bash -n ./change-site.sh; then
    echo "✓ Script syntax is valid"
else
    echo "✗ Script has syntax errors"
fi

echo "Basic tests completed."