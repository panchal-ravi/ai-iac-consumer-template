## PR Review Process

### When PR Review is Requested

1. **Load Constitution**: Read `/.specify/memory/constitution.md` to understand project standards and requirements
2. **Review Scope**: Evaluate the PR changes against:
   - Constitution compliance (MUST/SHOULD/MAY requirements)
   - Security best practices
   - Terraform code quality standards
   - Module usage patterns (private registry first)
   - Variable and output conventions
3. **Generate Review**: Create a structured review report with:
   - Constitution violations (with §X.Y references)
   - Security findings (Critical/High/Medium/Low)
   - Code quality issues (with file:line references)
   - Recommendations with before/after examples
4. **Post Review**: Add review comments to the PR using `gh pr review`

### Review Criteria

- **Constitution Alignment**: All MUST requirements satisfied
- **Security**: No Critical/High vulnerabilities unaddressed
- **Code Quality**: Follows Terraform style guide and best practices
- **Module Usage**: Private registry modules used where available
- **Documentation**: README, variables, and outputs properly documented
- **Testing**: Validation passes, sandbox testing complete

### Review Output Format

```markdown
## PR Review Summary

**Constitution Compliance**: ✅ Pass / ⚠️ Issues / ❌ Fail
**Security Score**: X/10
**Code Quality**: X/10

### Critical Issues
- [Issue description with file:line and constitution §reference]

### Recommendations
- [Actionable improvements with before/after examples]
```
