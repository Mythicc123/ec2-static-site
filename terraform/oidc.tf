data "aws_caller_identity" "current" {}

resource "aws_iam_role" "github_actions" {
  name = "ec2-static-site-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Mythicc123/ec2-static-site:*"
          }
        }
      }
    ]
  })

  tags = { Project = var.project_name }
}

resource "aws_iam_policy" "github_actions" {
  name        = "ec2-static-site-github-actions-policy"
  description = "Allow GH Actions to provision/destroy ec2-static-site resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::blue-green-tfstate-255445075474",
          "arn:aws:s3:::blue-green-tfstate-255445075474/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

output "github_actions_role_arn" {
  description = "ARN of the GitHub Actions IAM role — paste into repo secret AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
