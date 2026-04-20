output "runner_ip" {
  value = var.runner_ip
}

output "runner_name" {
  value = var.runner_name
}

output "runner_url" {
  value = "https://github.com/${var.github_repo}/settings/actions/runners"
}
