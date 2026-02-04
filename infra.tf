module "dev_vpc_1" {
  source             = "../modules/network"
  vpc_cidr           = "10.0.0.0/16"
  vpc_name           = "dev-vpc"
  environment        = "development"
  public_cidr_block  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_cidr_block = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
  Nat-GateWay_id     = module.dev_natgw_1.Nat-GateWay_id
}

module "dev_sg_1" {
  source        = "../modules/sg"
  vpc_id        = module.dev_vpc_1.vpc_id
  service_ports = ["80", "443", "8080", "8443", "22", "1443", "3306", "1900"]
  environment   = module.dev_vpc_1.environment
  vpc_name      = module.dev_vpc_1.vpc_name

}

module "dev_natgw_1" {
  source             = "../modules/nat"
  public_subnet_id_1 = module.dev_vpc_1.public_subnet_id_1
  vpc_name           = module.dev_vpc_1.vpc_name

}

module "dev_instance_1" {
  source = "../modules/compute"
  amis = {
    us-east-1 = "ami-0b6c6ebed2801a5cb"
    us-east-2 = "ami-06e3c045d79fd65d9"
  }
  aws_region           = var.aws_region
  environment          = module.dev_vpc_1.environment
  key_name             = "Linux_secfile"
  vpc_name             = module.dev_vpc_1.vpc_name
  public_subnet_id     = module.dev_vpc_1.public_subnet_id
  sg_id                = module.dev_sg_1.sg_id
  private_subnet_id    = module.dev_vpc_1.private_subnet_id
  iam_instance_profile = module.dev_iam_1.iam_instance_profile
  elb_listener_public  = module.dev_elb_1.elb_listener_public

}

data "aws_acm_certificate" "cert" {
  domain      = "*.cloudrayeez.xyz"
  types       = ["AMAZON_ISSUED"]
  statuses    = ["ISSUED"]
  most_recent = true
}

module "dev_elb_1" {
  source           = "../modules/elb"
  nlbname          = "aws-test-nlb"
  public_subnet_id = module.dev_vpc_1.public_subnet_id
  environment      = module.dev_vpc_1.environment
  tgname           = "${module.dev_vpc_1.vpc_name}-tg"
  vpc_id           = module.dev_vpc_1.vpc_id
  private-instance = module.dev_instance_1.private-instance
  public-instance  = module.dev_instance_1.public-instance
  certificate_arn  = data.aws_acm_certificate.cert.arn
  sg_id            = [module.dev_sg_1.sg_id]
}

module "dev_iam_1" {
  source              = "../modules/iam"
  instanceprofilename = "${module.dev_vpc_1.vpc_name}-inst-profile"
  environment         = module.dev_vpc_1.environment
  rolename            = "${module.dev_vpc_1.vpc_name}-role"
}

data "aws_route53_zone" "main" {
  name = "cloudrayeez.xyz"
}

resource "aws_route53_record" "dev" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "dev.cloudrayeez.xyz"
  type    = "A"

  alias {
    name                   = module.dev_elb_1.elb_dns_name
    zone_id                = module.dev_elb_1.elb_zone_id
    evaluate_target_health = true
  }
}
