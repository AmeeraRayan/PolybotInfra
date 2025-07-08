env           = "dev"
ami_id        = "ami-042b4708b1d05f512"
instance_type = "t3.medium"
key_name      = "polybot-key"
vpc_cidr      = "10.0.0.0/16"
azs           = ["eu-north-1a", "eu-north-1b"]
acm_certificate_arn = "arn:aws:acm:eu-north-1:228281126655:certificate/48408eea-bfec-4443-85e9-fa7a981e08ec"