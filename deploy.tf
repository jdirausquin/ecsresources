provider "aws" {}

resource "aws_ecs_task_definition" "taskdef" {
    family                = "taskdefname"
    container_definitions = "${file("containerdefinition.json")}"
}