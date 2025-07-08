terraform {
  backend "s3" {
    bucket         = "ameera-k8s-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "eu-north-1"
  }
}

module "k8s_cluster" {
  source        = "./modules/k8s-cluster"
  env           = "dev"
  region        = "eu-north-1"
  ami_id        = "ami-042b4708b1d05f512"
  instance_type = "t3.medium"
  key_name      = "polybot-key"
  vpc_cidr      = "10.0.0.0/16"
  azs           = ["eu-north-1a", "eu-north-1b"]
  acm_certificate_arn = var.acm_certificate_arn
}