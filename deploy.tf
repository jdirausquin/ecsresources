provider "aws" {}

resource "aws_ecs_task_definition" "taskdef" {
    family                = "taskdefname"
    container_definitions = "${file("containerdefinition.json")}"
}

resource "aws_cloudwatch_log_group" "yada" {
  name = "Yada"
}

resource "aws_cloudwatch_log_stream" "foo" {
  name           = "SampleLogStream1234"
  log_group_name = "${aws_cloudwatch_log_group.yada.name}"
}
