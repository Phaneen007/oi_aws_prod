locals {
  openwebui_working_dir = ".assets/open-webui"
  mcpo_working_dir      = ".assets/mcpo"
}

# ECR Repository for Open WebUI
resource "aws_ecr_repository" "openwebui_repository" {
  name                 = "openwebui"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# ECR Repository for MCPO (if you're using this module)
resource "aws_ecr_repository" "mcpo_repository" {
  name                 = "mcpo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

# Build and Push Open WebUI Image
resource "null_resource" "build_openwebui_image" {
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(local.openwebui_working_dir, "**") : filesha1("${local.openwebui_working_dir}/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.region} --profile ${var.profile} | docker login --username AWS --password-stdin ${aws_ecr_repository.openwebui_repository.repository_url} \
        && docker build \
        --platform linux/arm64 \
        -t ${aws_ecr_repository.openwebui_repository.repository_url}:latest \
        ${local.openwebui_working_dir} \
        && docker push ${aws_ecr_repository.openwebui_repository.repository_url}:latest
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [aws_ecr_repository.openwebui_repository]
}

# Build and Push MCPO Image (optional)
resource "null_resource" "build_mcpo_image" {
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(local.mcpo_working_dir, "**") : filesha1("${local.mcpo_working_dir}/${f}")]))
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.region} --profile ${var.profile} | docker login --username AWS --password-stdin ${aws_ecr_repository.mcpo_repository.repository_url} \
        && docker build \
        --platform linux/arm64 \
        -t ${aws_ecr_repository.mcpo_repository.repository_url}:latest \
        ${local.mcpo_working_dir} \
        && docker push ${aws_ecr_repository.mcpo_repository.repository_url}:latest
    EOT
    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [aws_ecr_repository.mcpo_repository]
}