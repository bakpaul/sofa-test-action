# AGENTS.md - Guidelines for Agentic Coding in sofa-test-action

This document provides guidelines for AI agents and developers working on the sofa-test-action repository.

## Repository Overview

This is a GitHub Action for setting up and running tests for SOFA framework plugins. The action:
- Sets up the SOFA environment
- Runs unit tests, scene tests, and regression tests
- Handles test reporting and artifact publishing

### Github command

The work developped must be pushed on bakpaul remote using

```bash
git push bakpaul wip_first_attempt
```

## Build/Lint/Test Commands

### Running Tests

The repository uses shell scripts from the CI repository to run tests:

```bash
# Run unit tests
/bin/bash "$CI_DIR/scripts/unit-tests.sh" run unit "$BUILD_DIR" "$SRC_DIR" "$OUTPUT_DIR" $NB_THREADS

# Run scene tests
/bin/bash "$CI_DIR/scripts/scene-tests.sh" run "$SOFA_ROOT" "$SRC_DIR" "$OUTPUT_DIR" $NB_THREADS

# Run regression tests
/bin/bash "$CI_DIR/scripts/unit-tests.sh" run regression "$REGRESSION_BINARY_DIR" "$SRC_DIR" "$OUTPUT_DIR" $NB_THREADS
```

### Running a Single Test

To run a single test, you would typically:

1. Navigate to the appropriate test directory
2. Use the test runner script with specific parameters to target one test file

Example (conceptual - exact syntax depends on test framework):
```bash
# For unit tests - would need to modify the unit-tests.sh script call
# to target a specific test binary or file

# For scene tests - would need to specify a single scene file
SCENE_FILE="path/to/specific/scene.scn"
/bin/bash "$CI_DIR/scripts/scene-tests.sh" run "$SOFA_ROOT" "$(dirname $SCENE_FILE)" "$OUTPUT_DIR" 1
```

### Test Results Analysis

```bash
# Get test summaries
/bin/bash "$CI_DIR/scripts/unit-tests.sh" print-summary unit "$BUILD_DIR" "$SRC_DIR" "$OUTPUT_DIR" $NB_THREADS

# Count test results
TEST_SUITES=$(/bin/bash "$CI_DIR/scripts/unit-tests.sh" count-test-suites unit "$BUILD_DIR" "$SRC_DIR" "$OUTPUT_DIR")
TEST_TOTAL=$(/bin/bash "$CI_DIR/scripts/unit-tests.sh" count-tests unit "$BUILD_DIR" "$SRC_DIR" "$OUTPUT_DIR")

# Extract errors from XML reports
python3 "$CI_DIR/scripts/exctractErrorFromXML.py" "$OUTPUT_DIR/reports" "$OUTPUT_DIR"
```

## Code Style Guidelines

### General Principles

1. **Shell Scripting**: This is primarily a shell script/bash-based repository
2. **GitHub Actions**: Follow GitHub Actions composite action patterns
3. **Cross-platform**: Code must work on Linux, macOS, and Windows

### Shell Script Style

1. **Shebang**: Always use `#!/bin/bash` for bash scripts
2. **Quoting**: Always quote variables: `"$VARIABLE"`
3. **Indentation**: Use 2 or 4 spaces (consistent with existing code)
4. **Error Handling**: Use `set -e` at the beginning of scripts
5. **Variable Naming**: 
   - UPPER_CASE for environment variables
   - lower_case_with_underscores for local variables
   - Descriptive names

### YAML Style (GitHub Actions)

1. **Indentation**: 2 spaces (standard YAML)
2. **String Quoting**: Use quotes for values with special characters
3. **Multi-line Strings**: Use `|` for multi-line bash commands
4. **Comments**: Use `#` for comments

### Python Scripts

The repository includes some Python scripts for test analysis:

1. **Imports**: Group imports (standard library, third-party, local)
2. **Type Hints**: Use type hints where appropriate
3. **Error Handling**: Use try/except blocks for file operations
4. **Shebang**: Use `#!/usr/bin/env python3`

### Error Handling

1. **Shell Scripts**: Check command success with `if [ $? -ne 0 ]` or `||`
2. **File Operations**: Check if files exist before operating on them
3. **Cross-platform**: Handle different OS behaviors (Windows vs Unix)
4. **Graceful Failure**: Provide meaningful error messages

### Naming Conventions

1. **Files**: kebab-case for filenames (e.g., `unit-tests.sh`)
2. **Variables**: 
   - Shell: `UPPER_SNAKE_CASE` for env vars, `lower_snake_case` for locals
   - YAML: `camelCase` for GitHub Actions inputs/outputs
3. **Functions**: Not typically used in this codebase (simple scripts)
4. **Directories**: kebab-case (e.g., `test-results`)

### Formatting

1. **Line Length**: Keep lines under 100-120 characters where reasonable
2. **Spacing**: Use blank lines to separate logical sections
3. **Consistency**: Follow existing patterns in the codebase

### Documentation

1. **Comments**: Use comments to explain complex logic
2. **Action Documentation**: Document inputs/outputs in action.yml
3. **README**: Keep usage examples updated

## Repository Structure

```
/
├── action.yml              # Main GitHub Action definition
├── README.md              # Usage documentation
├── .github/
│   └── workflows/
│       └── test.yml       # Test workflow
└── AGENTS.md              # This file
```

## Development Workflow

1. **Testing**: Test changes by running the action in a test workflow
2. **Validation**: Ensure the action works across all supported platforms
3. **Documentation**: Update README.md with any new features

## Platform-Specific Considerations

### Windows
- Use `cmd //c` for complex commands
- Handle PATH environment variable differently
- Use different library paths

### Linux/macOS
- Use standard shell syntax
- Handle DYLD_LIBRARY_PATH (macOS) and LD_LIBRARY_PATH (Linux)

## Best Practices

1. **Idempotency**: Ensure the action can be run multiple times safely
2. **Error Recovery**: Handle failures gracefully and provide useful output
3. **Logging**: Provide detailed logs for debugging
4. **Performance**: Optimize for reasonable execution time
5. **Security**: Avoid exposing sensitive information in logs

## Testing Strategy

1. **Unit Tests**: Test individual components and scripts
2. **Integration Tests**: Test the full action workflow
3. **Cross-platform Testing**: Test on all supported platforms
4. **Regression Testing**: Ensure changes don't break existing functionality

## CI/CD Pipeline

The repository uses GitHub Actions for CI/CD:
- Tests run on push and pull request events
- Tests run on multiple platforms (Ubuntu, macOS, Windows)
- Uses the action itself to test the action

## Agent-Specific Notes

1. **Environment Setup**: Agents should understand the SOFA framework environment
2. **Test Analysis**: Focus on test result parsing and reporting
3. **Cross-platform**: Be aware of platform differences in shell scripting
4. **GitHub Actions**: Understand composite action structure and limitations

## Resources

- GitHub Actions Documentation: https://docs.github.com/en/actions
- SOFA Framework: https://www.sofa-framework.org/
- Shell Script Best Practices: https://google.github.io/styleguide/shellguide.html

## Future Improvements

1. Add more detailed single test execution documentation
2. Document specific test frameworks used by SOFA
3. Add examples of common debugging scenarios
4. Document artifact analysis patterns
5. Add performance optimization guidelines

This document provides a foundation for agents working on the sofa-test-action repository. As the repository evolves, this document should be updated to reflect new patterns and best practices.