locals {
  aca_01_dockerhub_repository = trimprefix(var.aca_01_image, "docker.io/")
}

data "http" "aca_01_latest_tag" {
  url = "https://hub.docker.com/v2/repositories/${local.aca_01_dockerhub_repository}/tags?page_size=1&ordering=last_updated"
}

locals {
  aca_01_latest_image = "${var.aca_01_image}:${jsondecode(data.http.aca_01_latest_tag.response_body).results[0].name}"
}
