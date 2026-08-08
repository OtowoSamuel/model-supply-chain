provider "aws" {
  region = var.aws_region
  default_tags { tags = local.tags }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Data sources
# ─────────────────────────────────────────────────────────────────────────────
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = local.name
  cidr = local.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway   = true
  single_nat_gateway   = var.environment == "staging" # Save cost in staging
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS load balancer discovery
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# EKS Cluster
# ─────────────────────────────────────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.11"

  cluster_name    = local.name
  cluster_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Public endpoint for kubectl (restrict in production)
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # Restrict in production

  # Enable OIDC for IRSA (IAM Roles for Service Accounts)
  # Required for keyless Cosign signing in pods
  enable_irsa = true

  # Cluster access configuration
  # Use API mode for EKS access entries (modern approach)
  authentication_mode = "API_AND_CONFIG_MAP"

  # Enable cluster creator admin permissions
  enable_cluster_creator_admin_permissions = true

  # Allow root account access
  access_entries = {
    cluster_creator = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Cluster logging
  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  # Cluster addons (managed by AWS)
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # System node group
  eks_managed_node_groups = {
    system = {
      name                     = "${local.name}-system"
      use_name_prefix          = true
      iam_role_name            = "eks-system-${var.environment}"
      iam_role_use_name_prefix = false

      instance_types = [var.system_node_instance_type]

      min_size     = 2
      max_size     = 4
      desired_size = 2

      labels = {
        "node-role" = "system"
      }

      # No taints for system nodes
      taints = {}

      update_config = {
        max_unavailable_percentage = 33
      }
    }

    ml_model = {
      name                     = "${local.name}-ml"
      use_name_prefix          = true
      iam_role_name            = "eks-ml-${var.environment}"
      iam_role_use_name_prefix = false

      instance_types = [var.ml_node_instance_type]

      min_size     = var.ml_node_min
      max_size     = var.ml_node_max
      desired_size = var.ml_node_desired

      labels = {
        "node-role" = "ml-model"
        "workload"  = "ml-inference"
      }

      # Taint ML nodes so only ML workloads schedule here
      taints = {
        ml_only = {
          key    = "workload"
          value  = "ml-model"
          effect = "NO_SCHEDULE" # Must be uppercase for EKS
        }
      }

      update_config = {
        max_unavailable_percentage = 50
      }
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# ECR - Elastic Container Registry
# (Alternative to GHCR, native to AWS)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "model_server" {
  name                 = "${local.name}/model-server"
  image_tag_mutability = "IMMUTABLE" # Prevent overwriting tags

  image_scanning_configuration {
    scan_on_push = true # Auto-scan for CVEs
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ecr_lifecycle_policy" "model_server" {
  repository = aws_ecr_repository.model_server.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["main", "v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Role for GitHub Actions OIDC (keyless AWS auth)
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_actions" {
  name = "${local.name}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:OtowoSamuel/model-supply-chain:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_actions" {
  name = "${local.name}-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::tf-state-model-supply-chain-050083686295",
          "arn:aws:s3:::tf-state-model-supply-chain-050083686295/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/tf-state-lock-model-supply-chain"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ecr:Describe*",
          "ecr:Get*",
          "ecr:List*",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "iam:Get*",
          "iam:List*",
          "logs:Describe*",
          "logs:List*",
          "autoscaling:Describe*",
          "elasticloadbalancing:Describe*",
          "eks:Describe*",
          "eks:List*",
          "kms:Describe*",
          "kms:Get*",
          "kms:List*",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:PutKeyPolicy",
          "kms:TagResource",
          "kms:UntagResource",
          "kms:CreateAlias",
          "kms:DeleteAlias"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/ecr",
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "eks:ListClusters",
          "eks:ListNodeGroups",
          "eks:DescribeNodegroup",
          "eks:CreateNodegroup",
          "eks:UpdateNodegroupConfig",
          "eks:UpdateNodegroupVersion",
          "eks:DeleteNodegroup",
          "eks:ListAccessEntries",
          "eks:DescribeAccessEntry",
          "eks:CreateAccessEntry",
          "eks:DeleteAccessEntry",
          "eks:UpdateAccessEntry",
          "eks:AssociateAccessPolicy",
          "eks:DisassociateAccessPolicy",
          "eks:ListAssociatedAccessPolicies",
          "eks:ListAccessPolicies",
          "eks:TagResource",
          "eks:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Role for Kyverno (IRSA) - ECR read for image verification
# Kyverno's admission controller verifies cosign signatures on ECR images,
# so it needs registry + KMS access via its pod identity.
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "kyverno_ecr" {
  name = "${local.name}-kyverno-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kyverno:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "kyverno_ecr" {
  name = "${local.name}-kyverno-ecr-policy"
  role = aws_iam_role.kyverno_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alias/aws/ecr",
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────────────────
# Kubernetes Namespaces
# ─────────────────────────────────────────────────────────────────────────────
resource "kubernetes_namespace" "kyverno" {
  metadata {
    name = "kyverno"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [module.eks]
}

resource "kubernetes_namespace" "ml_staging" {
  metadata {
    name = "ml-staging"
    labels = {
      "environment"     = "staging"
      "security-policy" = "enforced"
    }
  }

  depends_on = [module.eks]
}

# ─────────────────────────────────────────────────────────────────────────────
# Governance Modules
# ─────────────────────────────────────────────────────────────────────────────
module "governance_approvals" {
  source          = "./modules/governance/approvals"
  helm_release_id = helm_release.kyverno.id
}

module "governance_versioning" {
  source          = "./modules/governance/versioning"
  helm_release_id = helm_release.kyverno.id
}

module "governance_audit" {
  source          = "./modules/governance/audit"
  helm_release_id = helm_release.kyverno.id
}
