#!/bin/bash
# Pipeline validation test script

echo "=== CI/CD Pipeline Validation Test ==="
echo "This test validates the CI/CD pipeline implementation"
echo

# Test 1: Verify workflow files exist
echo "Test 1: Checking workflow files..."
workflow_files=(
    ".github/workflows/ci.yml"
    ".github/workflows/release.yml"
    ".github/workflows/maintenance.yml"
)

for file in "${workflow_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ Found: $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done

# Test 2: Validate YAML syntax
echo
echo "Test 2: Validating YAML syntax..."
if command -v yamllint >/dev/null 2>&1; then
    for file in "${workflow_files[@]}"; do
        if yamllint "$file" >/dev/null 2>&1; then
            echo "✅ Valid YAML: $file"
        else
            echo "❌ Invalid YAML: $file"
            exit 1
        fi
    done
else
    echo "⚠️  yamllint not available, skipping YAML validation"
fi

# Test 3: Check issue templates
echo
echo "Test 3: Checking issue templates..."
template_files=(
    ".github/ISSUE_TEMPLATE/bug_report.md"
    ".github/ISSUE_TEMPLATE/feature_request.md"
    ".github/ISSUE_TEMPLATE/documentation.md"
    ".github/ISSUE_TEMPLATE/config.yml"
)

for file in "${template_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ Found: $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done

# Test 4: Check documentation files
echo
echo "Test 4: Checking documentation files..."
doc_files=(
    "docs/CICD_PIPELINE.md"
    "docs/PRODUCTION_DEPLOYMENT.md"
    "docs/ROADMAP.md"
    "CONTRIBUTING.md"
    "SECURITY.md"
)

for file in "${doc_files[@]}"; do
    if [[ -f "$file" ]]; then
        echo "✅ Found: $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done

# Test 5: Validate markdown files
echo
echo "Test 5: Validating markdown files..."
if command -v markdownlint >/dev/null 2>&1; then
    if markdownlint "${doc_files[@]}" README.md >/dev/null 2>&1; then
        echo "✅ All markdown files are valid"
    else
        echo "❌ Markdown validation failed"
        markdownlint "${doc_files[@]}" README.md
        exit 1
    fi
else
    echo "⚠️  markdownlint not available, skipping markdown validation"
fi

# Test 6: Check configuration files
echo
echo "Test 6: Checking configuration files..."
config_files=(
    ".markdownlint.json"
)

if command -v jq >/dev/null 2>&1; then
    for file in "${config_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo "✅ Found: $file"
            if output=$(jq empty "$file" 2>&1); then
                echo "✅ Valid JSON: $file"
            else
                echo "❌ Invalid JSON in $file:"
                echo "$output"
                exit 1
            fi
        else
            echo "❌ Missing: $file"
            exit 1
        fi
    done
else
    echo "⚠️  jq not available, skipping JSON validation"
fi

# Test 7: Check script permissions
echo
echo "Test 7: Checking script permissions..."
scripts=(
    "change-site.sh"
    "monitoring-dashboard.sh"
    "debug-config.sh"
)

for script in "${scripts[@]}"; do
    if [[ -x "$script" ]]; then
        echo "✅ Executable: $script"
    else
        echo "❌ Not executable: $script"
        exit 1
    fi
done

echo
echo "🎉 All pipeline validation tests passed!"
echo "The CI/CD pipeline implementation is ready for testing."
