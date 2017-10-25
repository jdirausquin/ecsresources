provider "aws" {
    region = "us-west-2"
}

variable "vpcid" {
    type = "map"
    default = {
        "Dev"  = "vpc-40025d26"
        "Prod" = "vpc-40025d26"
    }
}

variable "subnet1" {
    type = "map"
    default = {
        "Dev"  = "subnet-a472f2ec"
        "Prod" = "subnet-a472f2ec"
    }
}

variable "subnet2" {
    type = "map"
    default = {
        "Dev"  = "subnet-8d4221eb"
        "Prod" = "subnet-8d4221eb"
    }
}

#variable "certid" {
#    default = "arn:aws:acm:us-east-1:379099483335:certificate/f1976ccc-0b1c-4149-9601-f60c16837626"
#}

variable "env" {}
variable "app" {}
variable "port" {}
variable "clustersg" {}
variable "clustername" {
    default = "ClusterName"
}
variable "clusterarn" {
    default = "ClusterARN"
}

resource "aws_security_group" "sgelb" {
    name                      = "LoadBalancer-${var.app}${var.env}"
    vpc_id                    = "${lookup(var.vpcid, var.env)}"
    tags {
        Name = "LoadBalancer-${var.app}${var.env}"
    }

    ingress {
        from_port             = "443"
        to_port               = "443"
        protocol              = "tcp"
        cidr_blocks           = ["0.0.0.0/0"]
    }

    # outbound internet access
    egress {
        from_port             = 0
        to_port               = 0
        protocol              = "-1"
        cidr_blocks           = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_elb" "elb" {
    name                        = "${var.app}${var.env}"
    subnets                     = "${list("${lookup(var.subnet1, var.env)}","${lookup(var.subnet2, var.env)}")}"
    security_groups             = ["${aws_security_group.sgelb.id}"]
    tags {
        Name = "${var.app}${var.env}"
    }

    listener {
      lb_port                   = 443
      lb_protocol               = "tcp"
 #     ssl_certificate_id        = "${var.certid}"
      instance_port             = "${var.port}"
      instance_protocol         = "tcp"
    }

    health_check {
      healthy_threshold         = 2
      unhealthy_threshold       = 5
      timeout                   = 10
      target                    = "TCP:${var.port}"
      interval                  = 30
    }

    cross_zone_load_balancing   = true
    idle_timeout                = 60
    connection_draining         = true
    connection_draining_timeout = 300
  }

 resource "aws_security_group_rule" "rule_oncluster" {
    type                      = "ingress"
    from_port                 = "${var.port}"
    to_port                   = "${var.port}"
    protocol                  = "tcp"
    source_security_group_id  = "${aws_security_group.sgelb.id}"
    security_group_id         = "${var.clustersg}"
}

resource "aws_ecs_task_definition" "taskdef" {
    family                = "taskdefname"
    container_definitions = "${file("containerdef.json")}"
}

resource "aws_ecs_service" "servicename" {
    name            = "servicename"
    cluster         = "${var.clusterarn}"
    task_definition = "${aws_ecs_task_definition.taskdef.arn}"
    desired_count   = 1
    #iam_role        = "${aws_iam_role.foo.arn}"
    #depends_on      = ["aws_iam_role_policy.foo"]

  placement_strategy {
    type  = "AZ Balanced Spread"
  }

  load_balancer {
    elb_name       = "${aws_elb.elb.name}"
    container_name = "${var.clustername}"
    container_port = "${var.port}"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}