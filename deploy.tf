provider "aws" {
  region = "us-west-2"
}

resource "aws_ecs_task_definition" "taskdef" {
    family                = "taskdefname"
    container_definitions = "${file("containerdef.json")}"
}