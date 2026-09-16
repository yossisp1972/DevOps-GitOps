# DevOps GitOps Lab

A hands-on end-to-end CI/CD and GitOps project built on AWS.

The project demonstrates how infrastructure provisioning, container CI, Kubernetes packaging, and GitOps-based continuous deployment can be combined using:

- **AWS**
- **Terraform**
- **GitHub Actions**
- **GitHub OIDC**
- **Docker**
- **Amazon ECR**
- **K3s**
- **Helm**
- **Argo CD**
- **AWS Systems Manager**

The project intentionally uses **K3s on EC2 instead of Amazon EKS** to keep the lab inexpensive while still demonstrating Kubernetes, Helm, GitOps, IAM, container registry, and CI/CD concepts.

---

# Architecture

```text
                         ┌──────────────────┐
                         │      GitHub      │
                         │  DevOps-GitOps   │
                         └────────┬─────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │                           │
                    ▼                           ▼
             Infrastructure CI             Application CI
                    │                           │
             GitHub Actions                GitHub Actions
                    │                           │
                    ▼                           ▼
               Terraform                  Docker Build
                    │                           │
                    ▼                           ▼
                   AWS                     Amazon ECR
                    │                           │
          ┌─────────┴─────────┐                 │
          │                   │                 │
         VPC                 EC2                │
                               │                │
                               ▼                │
                              K3s ◄──────────────┘
                               │
                               ▼
                            Argo CD
                               │
                    watches Git repository
                               │
                               ▼
                              Helm
                               │
                               ▼
                         Kubernetes
                               │
                               ▼
                           demo-app
```

The deployment model separates CI from CD.

```text
CI

Application Code
      │
      ▼
GitHub Actions
      │
      ▼
Docker Build
      │
      ▼
Amazon ECR


CD / GitOps

Git Repository
      │
      ▼
Argo CD
      │
      ▼
Helm
      │
      ▼
K3s
      │
      ▼
Application
```

GitHub Actions does **not** deploy the application directly to Kubernetes.

Instead, Argo CD continuously reconciles the Kubernetes cluster with the desired state stored in Git.

---

# Technologies

| Technology | Purpose |
|---|---|
| AWS | Cloud infrastructure |
| Terraform | Infrastructure as Code |
| GitHub Actions | CI and infrastructure automation |
| GitHub OIDC | Passwordless GitHub → AWS authentication |
| Amazon S3 | Remote Terraform state |
| Amazon EC2 | Kubernetes host |
| K3s | Lightweight Kubernetes distribution |
| Docker | Application containerization |
| Amazon ECR | Private container registry |
| Helm | Kubernetes application packaging |
| Argo CD | GitOps continuous delivery |
| AWS IAM | AWS authorization |
| AWS Systems Manager | EC2 administration without SSH |

---

# Repository Structure

```text
DevOps-GitOps/
│
├── .github/
│   └── workflows/
│       ├── terraform.yml
│       ├── terraform-destroy.yml
│       └── app-ci.yml
│
├── terraform/
│   ├── backend.tf
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── user-data.sh
│
├── app/
│   └── demo-app/
│       ├── Dockerfile
│       └── index.html
│
├── helm/
│   └── demo-app/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           └── service.yaml
│
└── gitops/
    └── demo-app/
        └── application.yaml
```

---

# 1. Infrastructure as Code

AWS infrastructure is provisioned with Terraform.

Terraform creates the infrastructure required to run the Kubernetes lab, including:

```text
AWS
│
├── VPC
├── Public Subnet
├── Internet Gateway
├── Route Table
├── Security Group
├── EC2 Instance
├── IAM Role
├── IAM Instance Profile
└── Amazon ECR Repository
```

The EC2 instance runs K3s.

---

# 2. Remote Terraform State

Terraform state is not stored on the GitHub Actions runner.

GitHub-hosted runners are ephemeral, so storing state locally would cause Terraform to lose track of existing infrastructure between workflow executions.

Terraform therefore uses an S3 backend.

Example:

```hcl
terraform {
  backend "s3" {
    bucket       = "yossi-devops-gitops-tfstate-163880612827"
    key          = "dev/k3s-lab/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

Architecture:

```text
GitHub Actions
      │
      ▼
terraform init
      │
      ▼
Amazon S3
      │
      ▼
terraform.tfstate
```

The state bucket is intentionally treated as bootstrap/persistent infrastructure and is not destroyed with the lab.

---

# 3. GitHub → AWS Authentication

The project does not store long-lived AWS access keys in GitHub.

GitHub Actions authenticates to AWS using **OpenID Connect (OIDC)**.

```text
GitHub Actions
      │
      │ OIDC token
      ▼
AWS STS
      │
      ▼
IAM Role
      │
      ▼
Temporary AWS credentials
```

The GitHub repository contains the secret:

```text
AWS_TERRAFORM_ROLE_ARN
```

This contains the ARN of the AWS IAM role that GitHub Actions is permitted to assume.

The IAM trust relationship restricts which GitHub repository/workflows may assume the role.

This avoids storing:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

inside GitHub.

---

# 4. Terraform Pipeline

The infrastructure workflow is located at:

```text
.github/workflows/terraform.yml
```

The basic flow is:

```text
Git Push / Pull Request
        │
        ▼
GitHub Actions
        │
        ▼
AWS OIDC Authentication
        │
        ▼
terraform init
        │
        ▼
terraform fmt
        │
        ▼
terraform validate
        │
        ▼
terraform plan
        │
        ▼
terraform apply
        │
        ▼
AWS Infrastructure
```

Infrastructure changes are therefore version-controlled and reproducible.

---

# 5. Terraform Destroy Pipeline

A separate workflow exists for destroying the lab:

```text
.github/workflows/terraform-destroy.yml
```

It is manually triggered using `workflow_dispatch`.

A confirmation value such as:

```text
DESTROY
```

must be supplied before the destroy job executes.

The workflow runs:

```text
terraform init
      │
      ▼
terraform plan -destroy
      │
      ▼
terraform apply
      │
      ▼
Lab resources removed
```

This is particularly useful for an AWS learning environment because the infrastructure can be destroyed when not being used.

Later, running the normal Terraform workflow recreates the environment from code.

---

# 6. K3s

The Kubernetes cluster uses **K3s**.

K3s was chosen instead of EKS because this project is a learning/lab environment.

It provides the Kubernetes APIs and concepts required for the project while avoiding the cost of an EKS control plane and multiple worker nodes.

K3s runs directly on the EC2 instance.

Useful commands:

```bash
sudo systemctl status k3s
```

```bash
sudo k3s kubectl get nodes
```

```bash
sudo k3s kubectl get pods -A
```

Expected node state:

```text
NAME        STATUS   ROLES
<hostname>  Ready    control-plane,master
```

---

# 7. EC2 Administration

Direct SSH access is intentionally not required.

The EC2 instance is managed using **AWS Systems Manager Session Manager**.

The EC2 IAM role has:

```text
AmazonSSMManagedInstanceCore
```

This provides:

```text
Administrator
     │
     ▼
AWS Systems Manager
     │
     ▼
EC2
```

instead of:

```text
Internet
   │
   ▼
TCP/22
   │
   ▼
EC2
```

As a result, the infrastructure does not require an SSH key pair or a public SSH security-group rule.

---

# 8. Argo CD

Argo CD runs inside the K3s cluster.

Its purpose is to provide **GitOps continuous delivery**.

The Argo CD application definition is stored at:

```text
gitops/demo-app/application.yaml
```

It tells Argo CD to monitor:

```text
GitHub repository
       │
       ▼
main
       │
       ▼
helm/demo-app
```

and deploy it into:

```text
K3s
 │
 ▼
demo-app namespace
```

Example application configuration:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application

metadata:
  name: demo-app
  namespace: argocd

spec:
  project: default

  source:
    repoURL: https://github.com/yossisp1972/DevOps-GitOps.git
    targetRevision: main
    path: helm/demo-app

  destination:
    server: https://kubernetes.default.svc
    namespace: demo-app

  syncPolicy:
    automated:
      prune: true
      selfHeal: true

    syncOptions:
      - CreateNamespace=true
```

---

# 9. GitOps Deployment

The initial Argo CD Application can be bootstrapped with:

```bash
sudo k3s kubectl apply \
  -f https://raw.githubusercontent.com/yossisp1972/DevOps-GitOps/main/gitops/demo-app/application.yaml
```

After that, Argo CD controls the application deployment.

Verify:

```bash
sudo k3s kubectl get applications -n argocd
```

Expected:

```text
NAME       SYNC STATUS   HEALTH STATUS
demo-app   Synced        Healthy
```

---

# 10. Helm

The application Kubernetes resources are packaged as a Helm chart.

```text
helm/demo-app/
│
├── Chart.yaml
├── values.yaml
│
└── templates/
    ├── deployment.yaml
    └── service.yaml
```

`values.yaml` defines configurable properties such as:

```yaml
image:
  repository: 163880612827.dkr.ecr.eu-west-1.amazonaws.com/demo-app
  tag: "c5d7253"
  pullPolicy: IfNotPresent
```

The Deployment template consumes these values:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
```

This allows application versions to be controlled through Git.

---

# 11. Demo Application

The demo application is intentionally simple.

```text
app/demo-app/
├── Dockerfile
└── index.html
```

Nginx is used as the container runtime.

Example Dockerfile:

```dockerfile
FROM nginx:1.29-alpine

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

The application itself is intentionally trivial because the focus of the project is the deployment platform rather than application development.

---

# 12. Application CI Pipeline

Application CI is implemented using:

```text
.github/workflows/app-ci.yml
```

When application code changes:

```text
Developer
    │
    ▼
Git Push
    │
    ▼
GitHub Actions
    │
    ├── Authenticate to AWS using OIDC
    │
    ├── Login to ECR
    │
    ├── Build Docker image
    │
    └── Push Docker image
    │
    ▼
Amazon ECR
```

Images use the Git commit SHA as the image tag.

Example:

```text
Git commit:

c5d7253b7e...

        ↓

Docker image:

demo-app:c5d7253
```

This provides traceability between source code and container artifacts.

The project intentionally avoids relying on:

```text
latest
```

for application versioning.

---

# 13. Amazon ECR

Amazon Elastic Container Registry stores the application images.

Repository:

```text
demo-app
```

Example image:

```text
163880612827.dkr.ecr.eu-west-1.amazonaws.com/demo-app:c5d7253
```

ECR image scanning is enabled when images are pushed.

For this disposable lab, Terraform may use:

```hcl
force_delete = true
```

on the ECR repository.

This allows:

```text
terraform destroy
```

to remove the repository even when it contains images.

This setting is appropriate for this disposable lab but would require more careful consideration for a production artifact repository.

---

# 14. Private ECR Authentication

The ECR repository is private.

The EC2 instance uses the IAM role:

```text
k3s-lab-ec2-role
```

The role requires ECR read permissions such as:

```text
AmazonEC2ContainerRegistryReadOnly
```

The Kubernetes Deployment references:

```yaml
imagePullSecrets:
  - name: ecr-secret
```

The pull secret can be created using an ECR authorization token.

Example:

```bash
ECR_PASSWORD=$(aws ecr get-login-password --region eu-west-1)

sudo k3s kubectl create secret docker-registry ecr-secret \
  --namespace demo-app \
  --docker-server=163880612827.dkr.ecr.eu-west-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD"
```

Verify:

```bash
sudo k3s kubectl get secret ecr-secret -n demo-app
```

> **Current limitation:** ECR authorization tokens are temporary. The lab currently uses an image-pull secret, so ECR authentication should ultimately be automated rather than depending on a manually generated token.

---

# 15. Complete CI/CD Flow

The resulting application lifecycle is:

```text
Developer changes application
            │
            ▼
         GitHub
            │
            ▼
     GitHub Actions
            │
            ▼
       Docker Build
            │
            ▼
       Amazon ECR
            │
            │
            │       Git desired state
            │              │
            │              ▼
            │           Argo CD
            │              │
            │              ▼
            │             Helm
            │              │
            │              ▼
            └──────────►   K3s
                           │
                           ▼
                       demo-app
```

The important architectural boundary is:

```text
GitHub Actions = CI

Argo CD = CD
```

GitHub Actions produces the artifact.

Argo CD deploys the desired state.

---

# 16. Verify a Deployment

Check Argo CD:

```bash
sudo k3s kubectl get applications -n argocd
```

Check the application:

```bash
sudo k3s kubectl get pods -n demo-app
```

Expected:

```text
NAME                        READY   STATUS    RESTARTS
demo-app-xxxxxxxxxx-xxxxx   1/1     Running   0
```

Check all application resources:

```bash
sudo k3s kubectl get all -n demo-app
```

Check the deployed image:

```bash
sudo k3s kubectl get deployment demo-app \
  -n demo-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

# 17. Troubleshooting

## ImagePullBackOff

Check:

```bash
sudo k3s kubectl describe pod <pod-name> -n demo-app
```

A message such as:

```text
no basic auth credentials
```

indicates that Kubernetes cannot authenticate to ECR.

Verify the pull secret:

```bash
sudo k3s kubectl get secret ecr-secret -n demo-app
```

Verify the Deployment references it:

```bash
sudo k3s kubectl get deployment demo-app \
  -n demo-app \
  -o jsonpath='{.spec.template.spec.imagePullSecrets}'
```

Expected:

```text
[{"name":"ecr-secret"}]
```

---

## Verify EC2 IAM Identity

From the EC2 instance:

```bash
aws sts get-caller-identity
```

The ARN should contain:

```text
assumed-role/k3s-lab-ec2-role/
```

---

## Check Argo CD

```bash
sudo k3s kubectl get pods -n argocd
```

```bash
sudo k3s kubectl get applications -n argocd
```

```bash
sudo k3s kubectl describe application demo-app -n argocd
```

---

## Check K3s

```bash
sudo systemctl status k3s
```

```bash
sudo k3s kubectl get nodes
```

```bash
sudo k3s kubectl get pods -A
```

---

# 18. Destroying the Lab

The environment is designed to be disposable.

Run the GitHub Actions workflow:

```text
Terraform Destroy
```

Enter:

```text
DESTROY
```

when prompted.

Terraform reads the existing state from S3 and removes the managed infrastructure.

The S3 Terraform state bucket remains available.

---

# 19. Recreating the Lab

To rebuild the environment, run:

```text
GitHub → Actions → Terraform Infrastructure → Run workflow
```

The process becomes:

```text
GitHub Actions
      │
      ▼
AWS OIDC
      │
      ▼
terraform init
      │
      ▼
Read S3 state
      │
      ▼
terraform plan
      │
      ▼
terraform apply
      │
      ▼
AWS Infrastructure
      │
      ▼
EC2
      │
      ▼
K3s
      │
      ▼
Argo CD
```

The objective is for the entire environment to eventually be reproducible without manual configuration.

---

# 20. Current Architecture vs Production Architecture

This project intentionally optimizes for learning and low AWS cost.

Current lab:

```text
EC2
 │
 └── K3s
      ├── Kubernetes control plane
      ├── worker
      ├── Argo CD
      └── demo-app
```

A production AWS implementation could replace this with:

```text
AWS
 │
 └── EKS
      ├── Managed Control Plane
      ├── Managed Node Groups / Karpenter
      ├── Argo CD
      ├── AWS Load Balancer Controller
      ├── External Secrets
      └── Applications
```

The CI/CD and GitOps concepts remain largely the same.

---

# 21. Planned Improvements

The next stages of this project are:

### Automatic GitOps Image Promotion

After CI pushes:

```text
demo-app:<git-sha>
```

the pipeline will automatically update:

```text
helm/demo-app/values.yaml
```

with the new immutable image tag.

Argo CD will then detect the Git change and deploy the new version.

The target flow is:

```text
Code
 │
 ▼
GitHub Actions
 │
 ▼
Docker
 │
 ▼
ECR
 │
 ▼
Update Helm image tag
 │
 ▼
Git commit
 │
 ▼
Argo CD
 │
 ▼
K3s
```

### Automated ECR Authentication

Remove the current manual ECR pull-secret creation and make a destroyed/recreated environment completely self-bootstrapping.

### Argo Rollouts

Replace the standard Kubernetes Deployment with an Argo Rollout.

This will provide progressive delivery such as:

```text
New Release
    │
    ▼
10% traffic
    │
    ▼
25% traffic
    │
    ▼
50% traffic
    │
    ▼
100% traffic
```

### Istio

Add Istio as the Kubernetes service mesh.

Istio will provide traffic routing between stable and canary application versions.

Target architecture:

```text
                 Argo Rollouts
                       │
                       ▼
                     Istio
                  VirtualService
                       │
               ┌───────┴───────┐
               ▼               ▼
            Stable           Canary
              90%              10%
```

Together, Argo Rollouts and Istio will provide controlled canary releases.

---

# 22. Target Final Architecture

```text
                              GitHub
                                 │
                 ┌───────────────┴───────────────┐
                 │                               │
                 ▼                               ▼
          Infrastructure CI                Application CI
                 │                               │
          GitHub Actions                   GitHub Actions
                 │                               │
                 ▼                               ▼
            Terraform                       Docker
                 │                               │
                 ▼                               ▼
                AWS                         Amazon ECR
                 │                               │
                 ▼                               │
             EC2/K3s                            │
                 │                               │
                 ▼                               │
             Argo CD ◄──── Git desired state ───┘
                 │
                 ▼
                Helm
                 │
                 ▼
          Argo Rollouts
                 │
                 ▼
               Istio
                 │
         ┌───────┴────────┐
         ▼                ▼
      Stable            Canary
```

---

# Key Concepts Demonstrated

This project demonstrates:

- Infrastructure as Code
- Remote Terraform state
- Terraform state locking
- CI/CD pipelines
- GitHub Actions
- AWS IAM
- GitHub OIDC federation
- Temporary AWS credentials
- Docker containerization
- Private container registries
- Immutable image tagging
- Kubernetes
- Helm
- GitOps
- Argo CD
- Self-healing deployments
- Infrastructure reproducibility
- Separation of CI and CD
- AWS Systems Manager administration
- Least-exposure infrastructure design
- Disposable development environments

Future stages add:

- Argo Rollouts
- Canary deployments
- Istio
- Weighted traffic management
- Automated promotion
- Fully automated cluster bootstrap

---

# Project Goal

The goal of this repository is not simply to deploy a web page.

It is to demonstrate an end-to-end DevOps architecture in which:

**Infrastructure is defined as code, application artifacts are immutable, cloud authentication does not depend on static AWS credentials, deployments are driven by Git, and Kubernetes continuously converges toward the desired state defined in version control.**