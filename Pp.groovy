pipeline {
    agent any
    stages {
        stage('Creating ELB & Asigning rule to Clusters SG') {
                steps {
                    echo 'Getting SG of Cluster'
                    script {
                        sh "aws ecs list-container-instances --cluster $Cluster_Name | jq .containerInstanceArns[0] | xargs -I {} aws ecs describe-container-instances --cluster $Cluster_Name --container-instances {} | jq .containerInstances[].ec2InstanceId | xargs -I {} aws ec2 describe-instances --instance-id {} | jq .Reservations[].Instances[].SecurityGroups[].GroupId > tmpsg"
                        def SG=readFile('tmpsg')
                        echo "Security group of Cluster: ${SG}"
                        echo 'Creating ELB & Asigning rule to Cluster SG'
                        sh "terraform apply -target aws_elb.elb -target aws_security_group_rule.rule_oncluster -var app=$Application_Name -var env=$Envi_ronment -var port=$Instance_Port -var clustersg=${SG}"
                    }
                }
        }
        stage('Creating Task Definition') {
            steps {
                script {
                    def userInput = input( id: 'userInput', message: 'Task Definition Name',
                    parameters: [
                        [$class: 'TextParameterDefinition', description: 'Type Task Definition Name', name: 'TaskDefName'],
                        [$class: 'TextParameterDefinition', description: 'Type Container Name', name: 'ContainerName'],
                        [$class: 'TextParameterDefinition', description: 'Type Image URL', name: 'ImageUrl'],
                        [$class: 'TextParameterDefinition', description: 'Type # of CPU Units', name: 'CpuUnits'],
                        [$class: 'TextParameterDefinition', description: 'Type # of Memory Units', name: 'MemUnits'],
                        [$class: 'TextParameterDefinition', description: 'Type Log Group', name: 'LogGroup'],
                        [$class: 'TextParameterDefinition', description: 'Type Log Stream', name: 'LogStream']
                        ])
                        ansiblePlaybook([
                            colorized: true,
                            playbook: 'taskdef.yml',
                            extras: "-e 'containername=${userInput['ContainerName']} -e taskdefname=${userInput['TaskDefName']} -e imageurl=${userInput['ImageUrl']} -e ucpu=${userInput['CpuUnits']} -e umem=${userInput['MemUnits']} -e cport=$Container_Port -e hport=$Instance_Port -e lgroup=${userInput['LogGroup']} -e lstream=${userInput['LogStream']}'"
                            ])
                        def SG=readFile('tmpsg')
                        sh "terraform apply -target aws_ecs_task_definition.taskdef -var app=$Application_Name -var env=$Envi_ronment -var port=$Instance_Port -var clustersg=${SG}"
                }
            }
        }
    }
}