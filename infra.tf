module "dev_vpc_1" {
  # source              = "../modules/network"
  source              = "app.terraform.io/rayeez_devsecops/terraform-modules-network/aws"
  version             = "1.0.0"
  vpc_cidr            = "10.0.0.0/16"
  vpc_name            = "dev_vpc_1"
  environment         = "development"
  public_subnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidr = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  az_name             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  nat_gw              = true

}


module "dev_nat" {
  # source                 = "../modules/nat"
  source              = "app.terraform.io/rayeez_devsecops/terraform-modules-nat/aws"
  version             = "1.0.0"
  vpc_cidr            = "10.0.0.0/16"
  vpc_name            = "dev_vpc_1"
  environment         = "development"
  public_subnet_cidr  = ["10.0.1.0/24"]
  private_subnet_cidr = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  az_name             = ["us-east-1a"]
  nat_gw              = true
}

data "aws_acm_certificate" "cert" {
  domain      = "*.cloudrayeez.xyz"
  types       = ["AMAZON_ISSUED"]
  statuses    = ["ISSUED"]
  most_recent = true
}

module "dev_elb" {
  # source          = "../modules/elb"
  source          = "app.terraform.io/rayeez_devsecops/terraform-modules-elb/aws"
  version         = "1.0.0"
  environment     = "development"
  vpc_id          = module.dev_vpc_1.vpc_id
  subnets         = module.dev_vpc_1.public-subnet
  security_groups = [module.dev_sg_1.sg_id]
  instance_ids    = concat(module.dev_ec2_1.public_instance_ids, module.dev_ec2_1.private_instance_ids)
  certificate_arn = data.aws_acm_certificate.cert.arn
}

data "aws_route53_zone" "main" {
  name = "cloudrayeez.xyz"
}

resource "aws_route53_record" "dev" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "dev.cloudrayeez.xyz"
  type    = "A"

  alias {
    name                   = module.dev_elb.alb_dns_name
    zone_id                = module.dev_elb.alb_zone_id
    evaluate_target_health = true
  }
}
