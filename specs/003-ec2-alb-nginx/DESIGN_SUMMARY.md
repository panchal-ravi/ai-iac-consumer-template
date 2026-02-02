# Design Summary - EC2 Instance with ALB and Nginx

**GitHub Issue**: [#39](https://github.com/panchal-ravi/ai-iac-consumer-template/issues/39)  
**Branch**: `003-ec2-alb-nginx`  
**Status**: ✅ Design Complete - Awaiting User Approval

---

## 📋 Executive Summary

This design provides a **cost-optimized, development-ready infrastructure** for testing EC2 instances with Application Load Balancer and Nginx using self-signed HTTPS certificates.

**Key Metrics:**
- **Estimated Cost**: ~$40/month (development configuration)
- **Implementation Time**: 5-7 hours (MVP), 8-12 hours (full)
- **Security Rating**: ACCEPTABLE FOR DEVELOPMENT (not production-ready)
- **Code Quality**: Ready for implementation (comprehensive planning completed)

---

## 🏗️ Architecture Overview

### Infrastructure Components

1. **Compute**
   - 2 × EC2 instances (t3.micro) across 2 Availability Zones
   - Nginx web server with static test page
   - Bootstrap via user-data script

2. **Load Balancing**
   - Application Load Balancer (internet-facing)
   - HTTPS listener (port 443) with self-signed certificate
   - HTTP to HTTPS redirect
   - Target Group with health checks

3. **Security**
   - ALB Security Group: Allow 443 from 0.0.0.0/0
   - EC2 Security Group: Allow traffic only from ALB
   - Self-signed TLS certificate for "web.demo.com"
   - Certificate imported to AWS ACM

4. **Network**
   - Uses existing default VPC (data source)
   - Existing default subnets across 2 AZs
   - No new VPC creation (cost optimization)

5. **HCP Terraform**
   - Organization: `ravi-panchal-org`
   - Project: `Default Project`
   - Workspace: `sandbox_workspace`
   - Private registry modules used

---

## 📊 Design Artifacts

### Generated Documentation (Total: 122 KB)

| Artifact | Size | Purpose |
|----------|------|---------|
| `spec.md` | 15 KB | 30 functional requirements, 4 user stories, 10 success criteria |
| `plan.md` | 29 KB | Architecture, module research, testing strategy, cost analysis |
| `research.md` | 23 KB | Private registry module analysis and decisions |
| `data-model.md` | 23 KB | 12 core entities with relationships and validation |
| `contracts/terraform-interface.md` | 21 KB | 9 input variables, 23 output values |
| `contracts/nginx-bootstrap-contract.md` | 9 KB | User data script specification |
| `quickstart.md` | 17 KB | Deployment guide with testing scenarios |
| `tasks.md` | - | 101 dependency-ordered implementation tasks |

---

## 🔒 Security Assessment

### Overall Rating: ✅ ACCEPTABLE FOR DEVELOPMENT

**Risk Distribution:**
- **1 Critical (P0)**: Private key in Terraform state (documented, acceptable for dev)
- **5 High (P1)**: Self-signed certificates, missing CloudTrail, no VPC Flow Logs, no ALB logging, default VPC usage
- **6 Medium (P2)**: No EBS encryption, no WAF, overly permissive ALB SG, no CloudWatch alarms
- **3 Low (P3)**: Tag validation, Nginx hardening, HTTP redirect

### Good Security Practices ✅
- ✅ Network segmentation (separate security groups)
- ✅ HTTPS termination at ALB (AWS best practice)
- ✅ No hardcoded credentials
- ✅ Multi-AZ deployment
- ✅ Principle of least privilege (EC2 only accessible from ALB)

### Development vs Production Security

| Requirement | Development | Production |
|-------------|-------------|------------|
| Certificates | Self-signed (acceptable) | ACM with domain validation |
| VPC | Default VPC (cost savings) | Custom VPC with private subnets |
| Logging | Optional | CloudTrail + VPC Flow + ALB logs |
| Encryption | In-transit only | At-rest + in-transit with KMS |
| WAF | Not included | Required with OWASP rules |
| IAM Roles | Not required | SSM Session Manager required |
| Estimated Cost | ~$40/month | ~$129/month |

---

## 💰 Cost Analysis

### Monthly Cost Breakdown (Development)

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| EC2 Instances | 2 × t3.micro (730 hrs) | $14.60 |
| Application Load Balancer | 1 ALB + LCU charges | $22.00 |
| Data Transfer | Minimal (dev usage) | $2.00 |
| ACM Certificate | Self-signed (free) | $0.00 |
| **Total** | | **~$40/month** |

### Cost with Basic Security Enhancements (+40%)
- Enable CloudTrail: +$2/month
- Enable VPC Flow Logs: +$5/month
- Enable ALB access logs: +$3/month
- CloudWatch alarms: +$6/month
- **Total**: ~$56/month

---

## 📐 Module Architecture

### HCP Terraform Private Registry Modules

All infrastructure uses modules from `ravi-panchal-org` private registry:

1. **Security Group Module** (`app.terraform.io/ravi-panchal-org/security-group/aws`)
   - ALB security group (ingress: 443 from internet)
   - EC2 security group (ingress: 80 from ALB only)

2. **EC2 Instance Module** (`app.terraform.io/ravi-panchal-org/ec2-instance/aws`)
   - 2 instances across 2 AZs
   - User data bootstrap for Nginx
   - Cost-optimized: t3.micro

3. **ALB Module** (`app.terraform.io/ravi-panchal-org/alb/aws`)
   - Internet-facing ALB
   - HTTPS listener with ACM certificate
   - Target group with health checks
   - HTTP to HTTPS redirect

### File Structure

```
/workspace/terraform/
├── versions.tf                    # Provider version constraints
├── backend.tf                     # HCP Terraform Cloud config
├── providers.tf                   # AWS + TLS provider setup
├── variables.tf                   # 9 input variables
├── outputs.tf                     # 23 output values
├── locals.tf                      # Common tags, subnet logic
├── data.tf                        # VPC and subnet data sources
├── main.tf                        # Module instantiations
├── user-data/
│   └── nginx-bootstrap.sh        # EC2 bootstrap script
├── docs/
│   └── README.md                 # Documentation
└── tests/
    ├── default.tftest.hcl        # Basic validation test
    ├── security.tftest.hcl       # Security group isolation test
    └── health.tftest.hcl         # Health check test
```

---

## ✅ Implementation Plan

### Phase 1: Setup (11 tasks, ~30 min)
- Create directory structure
- Initialize Git branch
- Set up pre-commit hooks

### Phase 2: Foundational (9 tasks, ~45 min) - CRITICAL
- Create versions.tf, backend.tf, providers.tf
- Define variables and outputs
- Configure HCP Terraform workspace

### Phase 3: Infrastructure Provisioning (29 tasks, ~3 hours) - MVP
- Implement security groups
- Deploy EC2 instances with Nginx
- Configure ALB with HTTPS
- Create and import TLS certificate

### Phase 4: HTTPS Access Validation (9 tasks, ~45 min) - MVP
- Test ALB DNS resolution
- Verify HTTPS access (self-signed cert warning expected)
- Validate Nginx static page
- Confirm load balancing across instances

### Phase 5: Security Verification (13 tasks, ~1 hour)
- Test security group isolation
- Verify EC2 instances not directly accessible
- Validate ALB-only traffic flow

### Phase 6: Health Monitoring (15 tasks, ~1.5 hours)
- Configure health checks
- Test instance failover
- Verify traffic continues with one instance down

### Phase 7: Polish & Documentation (15 tasks, ~1 hour)
- Generate documentation
- Create architecture diagrams
- Finalize README
- Prepare deployment report

---

## 🎯 Success Criteria

All 10 success criteria from specification mapped to tasks:

1. ✅ Infrastructure deployed and accessible via HTTPS
2. ✅ ALB distributes traffic to 2 EC2 instances
3. ✅ Nginx serves static test page successfully
4. ✅ HTTPS works (browser warning expected with self-signed cert)
5. ✅ All security controls validated
6. ✅ Passes automated testing (terraform validate, plan, Sentinel)
7. ✅ Code quality score > 70%
8. ✅ Security scan: No CRITICAL/HIGH findings unaddressed
9. ✅ Documentation generated (README)
10. ✅ All code committed to feature branch with PR created

---

## 🚦 User Approval Checkpoint

### What Happens Next?

**Upon Approval:**
1. Execute `terraform-consumer-implement` skill
2. Implement all 101 tasks across 7 phases
3. Run automated testing (terraform init/validate/plan)
4. Generate deployment report
5. Create pull request with summary
6. Update GitHub issue #39 with final status

**Implementation Strategy:**
- Use HCP Terraform workspace: `sandbox_workspace`
- Remote execution via HCP Terraform Cloud
- Terraform CLI for plan/apply (NOT MCP create_run)
- Commit after each phase completion
- Continuous issue updates with progress

---

## 📋 Review Checklist

Before approving, please confirm:

- [ ] Architecture meets requirements (EC2, ALB, Nginx, HTTPS)
- [ ] Cost acceptable (~$40/month for development)
- [ ] Security posture understood (acceptable for dev, not production)
- [ ] HCP Terraform configuration correct (org, project, workspace)
- [ ] AWS region correct (ap-southeast-1)
- [ ] Self-signed certificate acceptable for testing
- [ ] Existing default VPC usage acceptable
- [ ] Implementation timeline reasonable (5-12 hours)

---

## 🔗 Quick Links

- **GitHub Issue**: [#39](https://github.com/panchal-ravi/ai-iac-consumer-template/issues/39)
- **Branch**: `003-ec2-alb-nginx`
- **Specification**: `specs/003-ec2-alb-nginx/spec.md`
- **Implementation Plan**: `specs/003-ec2-alb-nginx/plan.md`
- **Tasks**: `specs/003-ec2-alb-nginx/tasks.md`
- **Security Review**: `specs/003-ec2-alb-nginx/evaluations/aws-security-review.md`
- **Quickstart Guide**: `specs/003-ec2-alb-nginx/quickstart.md`

---

## 💬 Questions or Concerns?

If you need any clarifications or modifications to the design, please provide feedback before approval. Common adjustment areas:

- Instance sizing (currently t3.micro for cost)
- Security enhancements (CloudTrail, Flow Logs, WAF)
- Certificate approach (self-signed vs ACM)
- VPC strategy (default vs custom)
- Monitoring/alerting requirements
- Budget adjustments

---

**Ready to proceed?** Reply with your approval to begin Phase 6: Implementation.
